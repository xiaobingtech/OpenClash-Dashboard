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
    
    private var reconnectTask: Task<Void, Never>?
    private var isReconnecting = false
    
    // 添加错误追踪
    private struct ErrorTracker {
        var count: Int = 0
        var firstErrorTime: Date?
        
        mutating func recordError() -> Bool {
            let now = Date()
            
            // 如果是第一个错误或者距离第一个错误超过5秒，重置计数
            if firstErrorTime == nil || now.timeIntervalSince(firstErrorTime!) > 5 {
                count = 1
                firstErrorTime = now
                return false
            }
            
            count += 1
            return count >= 3 // 返回是否达到阈值
        }
        
        mutating func reset() {
            count = 0
            firstErrorTime = nil
        }
    }
    
    private var errorTracker = ErrorTracker()
    
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
        reconnectTask?.cancel()
        reconnectTask = nil
        connectionsTask?.cancel()
        connectionsTask = nil
        errorTracker.reset() // 重置错误计数
        
        DispatchQueue.main.async { [weak self] in
            self?.connectionState = .disconnected
        }
    }
    
    private func connectToConnections(server: ClashServer) {
        guard isMonitoring else { return }
        
        // 取消之前的重连任务
        reconnectTask?.cancel()
        reconnectTask = nil
        
        guard let url = URL(string: "ws://\(server.url):\(server.port)/connections") else {
            log("❌ URL 构建失败")
            DispatchQueue.main.async { [weak self] in
                self?.connectionState = .error("URL 构建失败")
            }
            return 
        }
        
        // 先测试 HTTP 连接
        var testRequest = URLRequest(url: URL(string: "http://\(server.url):\(server.port)")!)
        if !server.secret.isEmpty {
            testRequest.setValue("Bearer \(server.secret)", forHTTPHeaderField: "Authorization")
        }
        
        Task {
            do {
                let (_, response) = try await URLSession.shared.data(for: testRequest)
                if let httpResponse = response as? HTTPURLResponse {
                    log("✅ HTTP 连接测试状态码: \(httpResponse.statusCode)")
                    
                    if httpResponse.statusCode == 401 {
                        DispatchQueue.main.async { [weak self] in
                            self?.connectionState = .error("认证失败，请检查 Secret")
                        }
                        return
                    }
                }
                
                // 创建 WebSocket 请求
                var request = URLRequest(url: url)
                request.timeoutInterval = 5
                
                if !server.secret.isEmpty {
                    request.setValue("Bearer \(server.secret)", forHTTPHeaderField: "Authorization")
                }
                
                // 取消现有连接
                connectionsTask?.cancel()
                connectionsTask = nil
                
                // 创建新连接
                let task = session.webSocketTask(with: request)
                connectionsTask = task
                
                // 设置消息处理
                task.resume()
                receiveConnectionsData()
                
            } catch {
                log("❌ HTTP 连接测试失败: \(error.localizedDescription)")
                handleConnectionError(error)
            }
        }
    }
    
    private func handleConnectionError(_ error: Error) {
        log("❌ 连接错误: \(error)")
        
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
        
        // 使用 Task 进行重连，避免多个重连任务
        guard !isReconnecting else { return }
        isReconnecting = true
        
        reconnectTask = Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000) // 3秒
            guard !Task.isCancelled else { return }
            
            if let server = self.server {
                log("🔄 正在重新连接...")
                connectToConnections(server: server)
            }
            isReconnecting = false
        }
    }
    
    private func receiveConnectionsData() {
        guard let task = connectionsTask, isMonitoring else { return }
        
        task.receive { [weak self] result in
            guard let self = self, self.isMonitoring else { return }
            
            switch result {
            case .success(let message):
                // 成功接收消息时重置错误计数
                self.errorTracker.reset()
                
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
                
                // 记录错误并检查是否需要显示断开警告
                let shouldShowError = self.errorTracker.recordError()
                
                // 详细的错误诊断
                if let nsError = error as? NSError {
                    self.log("错误域: \(nsError.domain)")
                    self.log("错误代码: \(nsError.code)")
                    self.log("错误描述: \(nsError.localizedDescription)")
                    if let failingURL = nsError.userInfo["NSErrorFailingURLKey"] as? URL {
                        self.log("失败的 URL: \(failingURL)")
                    }
                    
                    if nsError.domain == NSPOSIXErrorDomain && nsError.code == 57 {
                        self.log("🔍 诊断: Socket 未连接错误，可能原因：")
                        self.log("1. 服务器未运行或不可达")
                        self.log("2. WebSocket 端口未开放")
                        self.log("3. 网络连接问题")
                        self.log("4. 防火墙阻止")
                    }
                }
                
                // 只有在达到错误阈值时才更新UI状态
                if shouldShowError {
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        self.connectionState = .disconnected
                    }
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
    
    private let maxHistoryCount = 200
    private var connectionHistory: [String: ClashConnection] = [:] // 用于存储历史记录
    
    private func handleConnectionsMessage(_ data: Data) {
        do {
            let response = try JSONDecoder().decode(ConnectionsResponse.self, from: data)
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                // 更新状态和流量数据
                if self.connectionState != .connected {
                    log("✅ WebSocket 已连接")
                }
                self.connectionState = .connected
                self.totalUpload = response.uploadTotal
                self.totalDownload = response.downloadTotal
                
                var hasChanges = false
                let currentIds = Set(response.connections.map { $0.id })
                
                // 更新现有连接状态
                for connection in response.connections {
                    let previousConnection = self.previousConnections[connection.id]
                    
                    // 计算速度
                    let uploadSpeed = previousConnection.map { 
                        Double(connection.upload - $0.upload) / 1.0
                    } ?? 0
                    let downloadSpeed = previousConnection.map { 
                        Double(connection.download - $0.download) / 1.0
                    } ?? 0
                    
                    // 创建更新后的连接对象
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
                        uploadSpeed: max(0, uploadSpeed),
                        isAlive: true  // 活跃连接
                    )
                    
                    // 检查是否已存在且需要更新
                    if let existingConnection = self.connectionHistory[connection.id] {
                        if existingConnection != updatedConnection {
                            hasChanges = true
                            self.connectionHistory[connection.id] = updatedConnection
                        }
                    } else {
                        // 新连接
                        hasChanges = true
                        self.connectionHistory[connection.id] = updatedConnection
                    }
                }
                
                // 更新已断开连接的状态
                for (id, connection) in self.connectionHistory {
                    if !currentIds.contains(id) && connection.isAlive {
                        // 创建已断开的连接副本
                        let closedConnection = ClashConnection(
                            id: connection.id,
                            metadata: connection.metadata,
                            upload: connection.upload,
                            download: connection.download,
                            start: connection.start,
                            chains: connection.chains,
                            rule: connection.rule,
                            rulePayload: connection.rulePayload,
                            downloadSpeed: 0,
                            uploadSpeed: 0,
                            isAlive: false  // 标记为已断开
                        )
                        hasChanges = true
                        self.connectionHistory[id] = closedConnection
                    }
                }
                
                // 只在有变化时更新 UI
                if hasChanges {
                    // 转换为数组并按开始时间倒序排序
                    var sortedConnections = Array(self.connectionHistory.values)
                    sortedConnections.sort { conn1, conn2 in
                        // 只按时间排序，不考虑连接状态
                        return conn1.start > conn2.start
                    }
                    
                    // 只有当超过最大记录数时才清理
                    if sortedConnections.count > self.maxHistoryCount {
                        // 保留所有活跃连接
                        let activeConnections = sortedConnections.filter { $0.isAlive }
                        
                        // 计算可以保留的已关闭连接数量
                        let remainingSlots = self.maxHistoryCount - activeConnections.count
                        
                        // 从已关闭的连接中选择最新的
                        let inactiveConnections = sortedConnections
                            .filter { !$0.isAlive }
                            .prefix(remainingSlots)
                        
                        // 合并并重新排序
                        sortedConnections = (activeConnections + Array(inactiveConnections))
                            .sorted { $0.start > $1.start }
                        
                        // 更新历史记录字典
                        self.connectionHistory = Dictionary(
                            uniqueKeysWithValues: sortedConnections.map { ($0.id, $0) }
                        )
                    }
                    
                    self.connections = sortedConnections
                }
                
                // 更新上一次的连接数据
                self.previousConnections = Dictionary(
                    uniqueKeysWithValues: response.connections.map { ($0.id, $0) }
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
