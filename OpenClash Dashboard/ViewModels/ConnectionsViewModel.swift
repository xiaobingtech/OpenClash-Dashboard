import Foundation
import Combine
import SwiftUI  // 添加这行

class ConnectionsViewModel: ObservableObject {
    enum ConnectionState: Equatable {
        case disconnected
        case connecting
        case connected
        case error(String)
        
        static func == (lhs: ConnectionState, rhs: ConnectionState) -> Bool {
            switch (lhs, rhs) {
            case (.disconnected, .disconnected):
                return true
            case (.connecting, .connecting):
                return true
            case (.connected, .connected):
                return true
            case (.error(let lhsMessage), .error(let rhsMessage)):
                return lhsMessage == rhsMessage
            default:
                return false
            }
        }
        
        var message: String {
            switch self {
            case .disconnected:
                return "未连接到服务器"
            case .connecting:
                return "正在连接服务器..."
            case .connected:
                return "已连接到服务器"
            case .error(let message):
                return message
            }
        }
        
        var showStatus: Bool {
            return true
        }
        
        var statusColor: Color {
            switch self {
            case .connected:
                return .green
            case .connecting:
                return .blue
            case .disconnected, .error:
                return .red
            }
        }
        
        var statusIcon: String {
            switch self {
            case .connected:
                return "checkmark.circle.fill"
            case .connecting:
                return "arrow.clockwise"
            case .disconnected, .error:
                return "exclamationmark.triangle.fill"
            }
        }
        
        var isConnecting: Bool {
            if case .connecting = self {
                return true
            }
            return false
        }
    }
    
    @Published var connections: [ClashConnection] = []
    @Published var totalUpload: Int = 0
    @Published var totalDownload: Int = 0
    @Published var connectionState: ConnectionState = .disconnected
    
    private var connectionsTask: URLSessionWebSocketTask?
    private let session = URLSession(configuration: .default)
    private var server: ClashServer?
    
    private var isMonitoring = false
    
    private var previousConnections: [String: ClashConnection] = [:]
    
    private func log(_ message: String) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm:ss.SSS"
        let timestamp = dateFormatter.string(from: Date())
        print("[\(timestamp)] \(message)")
    }
    
    func startMonitoring(server: ClashServer) {
        guard !isMonitoring else { return }
        
        self.server = server
        isMonitoring = true
        
        connectToConnections(server: server)
    }
    
    func stopMonitoring() {
        guard isMonitoring else { return }
        
        isMonitoring = false
        connectionsTask?.cancel()
        connectionsTask = nil
        
        DispatchQueue.main.async { [weak self] in
            self?.connectionState = .disconnected
            // 停止监控时也不清空连接列表
            // self?.connections = []
            // self?.totalUpload = 0
            // self?.totalDownload = 0
        }
    }
    
    private func connectToConnections(server: ClashServer) {
        guard isMonitoring else { return }
        
        guard let url = URL(string: "ws://\(server.url):\(server.port)/connections") else {
            log("❌ URL 构建失败")
            DispatchQueue.main.async { [weak self] in
                self?.connectionState = .error("URL 构建失败")
            }
            return 
        }
        log("🔄 正在连接 WebSocket: \(url.absoluteString)")
        
        // 创建请求
        var request = URLRequest(url: url)
        request.timeoutInterval = 5  // 添加超时时间
        
        // 添加认证头
        if !server.secret.isEmpty {
            request.setValue("Bearer \(server.secret)", forHTTPHeaderField: "Authorization")
        }
        
        // 添加其他必要的头部
        request.setValue("websocket", forHTTPHeaderField: "Upgrade")
        request.setValue("Upgrade", forHTTPHeaderField: "Connection")
        request.setValue("13", forHTTPHeaderField: "Sec-WebSocket-Version")
        
        // 先进行 HTTP 连接测试
        let testRequest = URLRequest(url: URL(string: "http://\(server.url):\(server.port)")!)
        URLSession.shared.dataTask(with: testRequest) { [weak self] _, response, error in
            guard let self = self else { return }
            
            if let error = error {
                self.log("❌ HTTP 连接测试失败: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.connectionState = .error("服务器连接失败: \(error.localizedDescription)")
                }
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                self.log("✅ HTTP 连接测试状态码: \(httpResponse.statusCode)")
            }
            
            // 创建 WebSocket 任务
            self.connectionsTask?.cancel()
            self.connectionsTask = nil
            
            let task = self.session.webSocketTask(with: request)
            self.connectionsTask = task
            
            // 设置消息处理
            task.resume()
            self.receiveConnectionsData()
            
        }.resume()
    }
    
    private func receiveConnectionsData() {
        guard let task = connectionsTask, isMonitoring else { return }
        
        task.receive { [weak self] result in
            guard let self = self, self.isMonitoring else { return }
            
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    if let data = text.data(using: .utf8) {
                        self.handleConnectionsMessage(data)
                    }
                case .data(let data):
                    self.handleConnectionsMessage(data)
                @unknown default:
                    break
                }
                
                // 继续接收下一条消息
                self.receiveConnectionsData()
                
            case .failure(let error):
                self.log("❌ WebSocket 错误: \(error)")
                
                // 详细的错误诊断
                if let nsError = error as? NSError {
                    self.log("错误域: \(nsError.domain)")
                    self.log("错误代码: \(nsError.code)")
                    self.log("错误描述: \(nsError.localizedDescription)")
                    if let failingURL = nsError.userInfo["NSErrorFailingURLKey"] as? URL {
                        self.log("失败的 URL: \(failingURL)")
                    }
                    
                    // 添加更多错误信息诊断
                    if nsError.domain == NSPOSIXErrorDomain && nsError.code == 57 {
                        self.log("🔍 诊断: Socket 未连接错误，可能原因：")
                        self.log("1. 服务器未运行或不可达")
                        self.log("2. WebSocket 端口未开放")
                        self.log("3. 网络连接问题")
                        self.log("4. 防火墙阻止")
                    }
                }
                
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.connectionState = .disconnected
                }
                
                // 延迟重试
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                    guard let self = self else { return }
                    self.log("🔄 正在重新连接...")
                    if let server = self.server {
                        self.connectToConnections(server: server)
                    }
                }
            }
        }
    }
    
    private func handleConnectionsMessage(_ data: Data) {
        do {
            let response = try JSONDecoder().decode(ConnectionsResponse.self, from: data)
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                // 如果之前状态不是已连接，打印连接成功日志
                if self.connectionState != .connected {
                    log("✅ WebSocket 已连接")
                }
                
                // 更新连接状态为已连接
                self.connectionState = .connected
                
                // 更新其他数据
                self.totalUpload = response.uploadTotal
                self.totalDownload = response.downloadTotal
                
                var updatedConnections: [ClashConnection] = []
                
                for connection in response.connections {
                    let previousConnection = self.previousConnections[connection.id]
                    
                    // 计算速度（字节/秒）
                    let uploadSpeed = previousConnection.map { 
                        Double(connection.upload - $0.upload) / 1.0 // 1秒间隔
                    } ?? 0
                    let downloadSpeed = previousConnection.map { 
                        Double(connection.download - $0.download) / 1.0 // 1秒间隔
                    } ?? 0
                    
                    // 创建包含速度信息的新连接对象
                    let updatedConnection = ClashConnection(
                        id: connection.id,
                        metadata: connection.metadata,
                        upload: connection.upload,
                        download: connection.download,
                        start: connection.start,
                        chains: connection.chains,
                        rule: connection.rule,
                        rulePayload: connection.rulePayload,
                        downloadSpeed: max(0, downloadSpeed),
                        uploadSpeed: max(0, uploadSpeed)
                    )
                    updatedConnections.append(updatedConnection)
                }
                
                // 按开始时间降序排序
                updatedConnections.sort { $0.start > $1.start }
                
                self.connections = updatedConnections
                self.previousConnections = Dictionary(
                    uniqueKeysWithValues: updatedConnections.map { ($0.id, $0) }
                )
            }
        } catch {
            log("❌ 解码错误：\(error)")
            DispatchQueue.main.async { [weak self] in
                self?.connectionState = .error("数据解析错误: \(error.localizedDescription)")
            }
        }
    }
    
    func refresh() async {
        stopMonitoring()
        if let server = server {
            startMonitoring(server: server)
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
