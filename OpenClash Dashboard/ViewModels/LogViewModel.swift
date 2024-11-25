import Foundation
import SwiftUI

class LogViewModel: ObservableObject {
    @Published var logs: [LogMessage] = []
    @Published var isConnected = false
    
    private var webSocketTask: URLSessionWebSocketTask?
    private let session = URLSession(configuration: .default)
    private var currentServer: ClashServer?
    
    func connect(to server: ClashServer) {
        currentServer = server
        
        var components = URLComponents()
        components.scheme = "ws"
        components.host = server.url
        components.port = Int(server.port)
        components.path = "/logs"
        components.queryItems = [
            URLQueryItem(name: "token", value: server.secret)
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
        webSocketTask?.resume()
        receiveLog()
    }
    
    private func receiveLog() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
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
                DispatchQueue.main.async { [weak self] in
                    self?.isConnected = false
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
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        DispatchQueue.main.async {
            self.isConnected = false
            self.logs.removeAll()
        }
    }
} 