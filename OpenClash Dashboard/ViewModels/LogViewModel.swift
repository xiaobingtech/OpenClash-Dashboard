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
    
    func connect(to server: ClashServer) {
        guard !isReconnecting else { return }
        
        if connectionRetryCount >= maxRetryCount {
            print("⚠️ 达到最大重试次数，停止重连")
            connectionRetryCount = 0
            return
        }
        
        connectionRetryCount += 1
        
        currentServer = server
        
        var components = URLComponents()
        components.scheme = "ws"
        components.host = server.url
        components.port = Int(server.port)
        components.path = "/logs"
        components.queryItems = [
            URLQueryItem(name: "token", value: server.secret),
            URLQueryItem(name: "level", value: logLevel)
        ]
        
        guard let url = components.url else { return }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 5
        request.setValue("websocket", forHTTPHeaderField: "Upgrade")
        request.setValue("Upgrade", forHTTPHeaderField: "Connection")
        request.setValue("13", forHTTPHeaderField: "Sec-WebSocket-Version")
        request.setValue("permessage-deflate; client_max_window_bits", forHTTPHeaderField: "Sec-WebSocket-Extensions")
        
        if !server.secret.isEmpty {
            request.setValue("Bearer \(server.secret)", forHTTPHeaderField: "Authorization")
        }
        
        webSocketTask?.cancel()
        webSocketTask = session.webSocketTask(with: request)
        
        // 添加一个 ping 任务来确认连接状态
        schedulePing()
        
        webSocketTask?.resume()
        
        // 连接建立时就更新状态
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
    
    private func receiveLog() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let message):
                // 成功接收消息时更新连接状态
                DispatchQueue.main.async {
                    self.isConnected = true
                    self.connectionRetryCount = 0  // 重置重试计数
                }
                
                switch message {
                case .string(let text):
                    // 忽略 ping 消息
                    if text == "ping" {
                        // 继续接收下一条消息
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
                // 继续接收下一条消息
                self.receiveLog()
                
            case .failure(let error):
                // 只在非取消错误时打印
                if (error as NSError).code != NSURLErrorCancelled {
                    print("❌ WebSocket 错误: \(error.localizedDescription)")
                }
                
                DispatchQueue.main.async {
                    // 只在确实断开连接时更新状态
                    if self.webSocketTask != nil {
                        self.isConnected = false
                        // 3秒后重连，但要考虑重试次数
                        if self.connectionRetryCount < self.maxRetryCount {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                                guard let self = self else { return }
                                if let server = self.currentServer {
                                    self.connect(to: server)
                                }
                            }
                        }
                    }
                }
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