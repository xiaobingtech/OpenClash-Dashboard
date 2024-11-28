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
    
    // 添加设置日志级别的方法
    func setLogLevel(_ level: String) {
        if self.logLevel != level {
            self.logLevel = level
            print("📝 切换日志级别到: \(level)")
            
            Task { @MainActor in
                self.logs.removeAll()
                if let server = self.currentServer {
                    self.connect(to: server)
                }
            }
        }
    }
    
    func connect(to server: ClashServer) {
        guard !isReconnecting else { return }
        
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
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 5_000_000_000) // 5秒
                
                do {
                    // 发送一个空消息作为 ping
                    try await webSocketTask.send(.string("ping"))
                    await MainActor.run {
                        self.isConnected = true
                    }
                } catch {
                    print("❌ Ping 失败: \(error.localizedDescription)")
                    await MainActor.run {
                        self.isConnected = false
                    }
                    // 尝试重新连接
                    if let server = self.currentServer {
                        self.connect(to: server)
                    }
                    break
                }
            }
        }
        
        // 存储 task 以便在需要时取消
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
                }
                
                switch message {
                case .string(let text):
                    // 忽略 ping 消息
                    if text == "ping" {
                        // 继续接收下一条消息
                        self.receiveLog()
                        return
                    }
                    print("📝 收到日志: \(text)")
                    self.handleLog(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        print("📝 收到日志数据: \(text)")
                        self.handleLog(text)
                    }
                @unknown default:
                    break
                }
                // 继续接收下一条消息
                self.receiveLog()
                
            case .failure(let error):
                print("❌ WebSocket 错误: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.isConnected = false
                }
                // 3秒后重连
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                    guard let self = self else { return }
                    if let server = self.currentServer {
                        self.connect(to: server)
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
    
    func disconnect() {
        pingTask?.cancel()
        pingTask = nil
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        DispatchQueue.main.async {
            self.isConnected = false
            self.logs.removeAll()
        }
    }
} 