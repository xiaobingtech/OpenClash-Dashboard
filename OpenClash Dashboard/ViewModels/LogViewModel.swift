import Foundation
import SwiftUI

class LogViewModel: ObservableObject {
    @Published var logs: [LogMessage] = []
    @Published var isConnected = false
    private var logLevel: String = "info"
    
    private var webSocketTask: URLSessionWebSocketTask?
    private let session = URLSession(configuration: .default)
    private var currentServer: ClashServer?
    private var pingTask: Task<Void, Never>?
    private var receiveTask: Task<Void, Never>?
    private var isReconnecting = false
    private var connectionRetryCount = 0
    private let maxRetryCount = 5
    
    // 添加设置日志级别的方法
    func setLogLevel(_ level: String) {
        guard self.logLevel != level else { return }
        self.logLevel = level
        print("📝 切换日志级别到: \(level)")
        
        Task { @MainActor in
            // 先断开现有连接
            disconnect(clearLogs: false)
            // 等待短暂延迟确保连接完全关闭
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5秒
            // 重新连接
            if let server = self.currentServer {
                connect(to: server)
            }
        }
    }
    
    private func makeWebSocketRequest(server: ClashServer) -> URLRequest? {
        var components = URLComponents()
        components.scheme = server.useSSL ? "wss" : "ws"
        components.host = server.url
        components.port = Int(server.port)
        components.path = "/logs"
        components.queryItems = [
            URLQueryItem(name: "token", value: server.secret),
            URLQueryItem(name: "level", value: logLevel)
        ]
        
        guard let url = components.url else { return nil }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 5
        
        // WebSocket 必需的请求头
        request.setValue("websocket", forHTTPHeaderField: "Upgrade")
        request.setValue("Upgrade", forHTTPHeaderField: "Connection")
        request.setValue("13", forHTTPHeaderField: "Sec-WebSocket-Version")
        request.setValue("permessage-deflate; client_max_window_bits", forHTTPHeaderField: "Sec-WebSocket-Extensions")
        
        if !server.secret.isEmpty {
            request.setValue("Bearer \(server.secret)", forHTTPHeaderField: "Authorization")
        }
        
        return request
    }
    
    private func makeSession(server: ClashServer) -> URLSession {
        let config = URLSessionConfiguration.default
        if server.useSSL {
            config.urlCache = nil
            config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
            config.tlsMinimumSupportedProtocolVersion = .TLSv12
            config.tlsMaximumSupportedProtocolVersion = .TLSv13
        }
        return URLSession(configuration: config)
    }
    
    func connect(to server: ClashServer) {
        guard !isReconnecting else { return }
        
        if connectionRetryCount >= maxRetryCount {
            print("⚠️ 达到最大重试次数，停止重连")
            connectionRetryCount = 0
            return
        }
        
        connectionRetryCount += 1
        currentServer = server
        
        guard let request = makeWebSocketRequest(server: server) else {
            print("❌ 无法创建 WebSocket 请求")
            return
        }
        
        // 使用支持 SSL 的会话
        let session = makeSession(server: server)
        webSocketTask?.cancel()
        webSocketTask = session.webSocketTask(with: request)
        
        schedulePing()
        webSocketTask?.resume()
        
        DispatchQueue.main.async {
            self.isConnected = true
        }
        
        receiveLog()
    }
    
    // 修改 ping 方法来使用消息发送代替 ping
    private func schedulePing() {
        guard let webSocketTask = webSocketTask else { return }
        
        let task = Task {
            var failureCount = 0
            while !Task.isCancelled {
                do {
                    try await Task.sleep(nanoseconds: 5_000_000_000) // 5秒
                    try await webSocketTask.send(.string("ping"))
                    
                    await MainActor.run {
                        self.isConnected = true
                        failureCount = 0 // 重置失败计数
                    }
                } catch {
                    // 忽略取消错误的日志输出
                    if !error.isCancellationError {
                        failureCount += 1
                        print("❌ Ping 失败 (\(failureCount)): \(error.localizedDescription)")
                        
                        await MainActor.run {
                            self.isConnected = false
                        }
                        
                        // 只有在连续失败多次后才重连
                        if failureCount >= 3 {
                            await MainActor.run {
                                reconnect()
                            }
                            break
                        }
                    }
                }
            }
        }
        
        pingTask = task
    }
    
    private func handleWebSocketError(_ error: Error) {
        // 只在非取消错误时处理
        guard !error.isCancellationError else { return }
        
        print("❌ WebSocket 错误: \(error.localizedDescription)")
        
        if let urlError = error as? URLError {
            switch urlError.code {
            case .secureConnectionFailed:
                print("❌ SSL/TLS 连接失败")
                DispatchQueue.main.async { [weak self] in
                    self?.isConnected = false
                    // 不要在 SSL 错误时自动重连
                    self?.connectionRetryCount = self?.maxRetryCount ?? 5
                }
            case .serverCertificateUntrusted:
                print("❌ 服务器证书不受信任")
                DispatchQueue.main.async { [weak self] in
                    self?.isConnected = false
                    self?.connectionRetryCount = self?.maxRetryCount ?? 5
                }
            default:
                DispatchQueue.main.async { [weak self] in
                    self?.isConnected = false
                    // 其他错误允许重试
                    if let self = self, self.connectionRetryCount < self.maxRetryCount {
                        self.reconnect()
                    }
                }
            }
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.isConnected = false
                if let self = self, self.connectionRetryCount < self.maxRetryCount {
                    self.reconnect()
                }
            }
        }
    }
    
    private func receiveLog() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let message):
                DispatchQueue.main.async {
                    self.isConnected = true
                    self.connectionRetryCount = 0
                }
                
                switch message {
                case .string(let text):
                    if text == "ping" {
                        self.receiveLog()
                        return
                    }
                    self.handleLog(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        self.handleLog(text)
                    }
                @unknown default:
                    break
                }
                self.receiveLog()
                
            case .failure(let error):
                self.handleWebSocketError(error)
            }
        }
    }
    
    private func handleLog(_ text: String) {
        guard let data = text.data(using: .utf8),
              let logMessage = try? JSONDecoder().decode(LogMessage.self, from: data) else {
            return
        }
        
        DispatchQueue.main.async {
            // 只保留最新的 1000 条日志
            if self.logs.count > 1000 {
                self.logs.removeFirst(self.logs.count - 1000)
            }
            self.logs.append(logMessage)
            self.isConnected = true
        }
    }
    
    func disconnect(clearLogs: Bool = true) {
        pingTask?.cancel()
        pingTask = nil
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        
        DispatchQueue.main.async {
            self.isConnected = false
            if clearLogs {
                self.logs.removeAll()
            }
        }
    }
    
    private func reconnect() {
        guard !isReconnecting else { return }
        isReconnecting = true
        
        Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000) // 3秒重连延迟
            await MainActor.run {
                if let server = self.currentServer {
                    connect(to: server)
                }
                isReconnecting = false
            }
        }
    }
}

// 添加扩展来判断错误类型
extension Error {
    var isCancellationError: Bool {
        let nsError = self as NSError
        return nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled
            || self is CancellationError
    }
} 