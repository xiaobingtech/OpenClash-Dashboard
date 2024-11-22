import Foundation
import Combine

class ConnectionsViewModel: ObservableObject {
    @Published var connections: [ClashConnection] = []
    @Published var totalUpload: Int = 0
    @Published var totalDownload: Int = 0
    @Published var isConnected: Bool = false
    
    private var connectionsTask: URLSessionWebSocketTask?
    private let session = URLSession(configuration: .default)
    private var server: ClashServer?
    
    func startMonitoring(server: ClashServer) {
        self.server = server
        connectToConnections(server: server)
    }
    
    func stopMonitoring() {
        connectionsTask?.cancel()
        connectionsTask = nil
        isConnected = false
    }
    
    private func connectToConnections(server: ClashServer) {
        guard let url = URL(string: "ws://\(server.url):\(server.port)/connections") else {
            print("❌ URL 构建失败")
            return 
        }
        print("🔄 正在连接 WebSocket: \(url.absoluteString)")
        
        var request = URLRequest(url: url)
        if !server.secret.isEmpty {
            request.setValue("Bearer \(server.secret)", forHTTPHeaderField: "Authorization")
            print("🔑 使用认证令牌: Bearer \(server.secret)")
        }
        
        print("📝 请求头: \(request.allHTTPHeaderFields ?? [:])")
        
        connectionsTask = session.webSocketTask(with: request)
        connectionsTask?.resume()
        print("▶️ WebSocket 任务已启动")
        
        DispatchQueue.main.async { [weak self] in
            self?.isConnected = true
        }
        
        receiveConnectionsData()
    }
    
    private func receiveConnectionsData() {
        print("👂 开始监听 WebSocket 消息")
        connectionsTask?.receive { [weak self] result in
            switch result {
            case .success(let message):
                print("✅ 收到 WebSocket 消息")
                switch message {
                case .string(let text):
                    print("📨 收到文本消息，长度: \(text.count)")
                    self?.handleConnectionsData(text)
                case .data(let data):
                    print("📨 收到二进制消息，长度: \(data.count)")
                    if let text = String(data: data, encoding: .utf8) {
                        self?.handleConnectionsData(text)
                    }
                @unknown default:
                    print("❓ 收到未知类型的消息")
                    break
                }
                self?.receiveConnectionsData() // 继续接收数据
                
            case .failure(let error):
                print("❌ WebSocket 错误: \(error)")
                print("❌ 错误描述: \(error.localizedDescription)")
                if let nsError = error as? NSError {
                    print("❌ 错误域: \(nsError.domain)")
                    print("❌ 错误代码: \(nsError.code)")
                    print("❌ 错误信息: \(nsError.userInfo)")
                }
                
                DispatchQueue.main.async {
                    self?.isConnected = false
                    // 尝试重新连接
                    if let server = self?.server {
                        print("🔄 尝试重新连接...")
                        self?.connectToConnections(server: server)
                    }
                }
            }
        }
    }
    
    private func handleConnectionsData(_ text: String) {
        guard let data = text.data(using: .utf8) else {
            print("❌ 无法将文本转换为数据")
            return
        }
        
        do {
            let response = try JSONDecoder().decode(ConnectionsResponse.self, from: data)
            print("✅ 成功解码数据: \(response.connections.count) 个连接")
            
            // 在主线程上更新所有 UI 相关的状态
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                let oldCount = self.connections.count
                // 创建新的连接数组以确保触发更新
                self.connections = response.connections.sorted { $0.start > $1.start }
                self.totalUpload = response.uploadTotal
                self.totalDownload = response.downloadTotal
                self.isConnected = true
                
                print("📊 UI 更新前连接数: \(oldCount)")
                print("📊 UI 更新后连接数: \(self.connections.count)")
                print("📊 数据已更新到 UI")
            }
        } catch {
            print("❌ 解码错误: \(error)")
            if let jsonString = String(data: data, encoding: .utf8) {
                print("📝 原始 JSON: \(jsonString)")
            }
        }
    }
    
    func refresh() async {
        stopMonitoring()
        if let server = server {
            connectToConnections(server: server)
        }
    }
    
    func closeConnection(_ id: String) {
        guard let server = server else { return }
        
        let urlString = "http://\(server.url):\(server.port)/connections/\(id)"
        guard let url = URL(string: urlString) else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(server.secret)", forHTTPHeaderField: "Authorization")
        
        Task {
            do {
                let (_, response) = try await URLSession.shared.data(for: request)
                if let httpResponse = response as? HTTPURLResponse,
                   httpResponse.statusCode == 204 {
                    await refresh()
                }
            } catch {
                print("Error closing connection: \(error)")
            }
        }
    }
    
    func formatBytes(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        return formatter.string(fromByteCount: Int64(bytes))
    }
} 