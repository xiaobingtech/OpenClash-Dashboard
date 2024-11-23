import Foundation
import Combine
import SwiftUI  // 添加这行

class ConnectionsViewModel: ObservableObject {
    enum ConnectionState: Equatable {
        case disconnected
        case connecting
        case connected
        case paused
        case error(String)
        
        static func == (lhs: ConnectionState, rhs: ConnectionState) -> Bool {
            switch (lhs, rhs) {
            case (.disconnected, .disconnected):
                return true
            case (.connecting, .connecting):
                return true
            case (.connected, .connected):
                return true
            case (.paused, .paused):
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
            case .paused:
                return "监控已暂停"
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
            case .connecting, .paused:
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
            case .paused:
                return "pause.circle.fill"
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
    @Published var isMonitoring = false
    
    private var connectionsTask: URLSessionWebSocketTask?
    private let session = URLSession(configuration: .default)
    private var server: ClashServer?
    
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
        self.server = server
        isMonitoring = true
        
        connectToConnections(server: server)
    }
    
    func stopMonitoring() {
        isMonitoring = false
        reconnectTask?.cancel()
        reconnectTask = nil
        connectionsTask?.cancel()
        connectionsTask = nil
        errorTracker.reset()
        
        DispatchQueue.main.async { [weak self] in
            self?.connectionState = .paused
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
                log("❌ HTTP 连测试失败: \(error.localizedDescription)")
                handleConnectionError(error)
            }
        }
    }
    
    private func handleConnectionError(_ error: Error) {
        log("❌ 连接错误：\(error.localizedDescription)")
        
        DispatchQueue.main.async { [weak self] in
            self?.connectionState = .error(error.localizedDescription)
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
                self.log("❌ WebSocket 错误：\(error.localizedDescription)")
                
                if errorTracker.recordError() {
                    DispatchQueue.main.async { [weak self] in
                        self?.connectionState = .error("连接失败，请检查网络或服务器状态")
                    }
                    self.stopMonitoring()
                } else {
                    self.reconnect()
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
            log("❌ 解码误：\(error)")
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
        
        // 添加所有必要的请求头
        request.setValue("*/*", forHTTPHeaderField: "Accept")
        request.setValue("en-US,en;q=0.9,zh-CN;q=0.8,zh-TW;q=0.7,zh;q=0.6", forHTTPHeaderField: "Accept-Language")
        request.setValue("Bearer \(server.secret)", forHTTPHeaderField: "Authorization")
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        request.setValue("keep-alive", forHTTPHeaderField: "Connection")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("1", forHTTPHeaderField: "DNT")
        request.setValue("http://\(server.url):\(server.port)", forHTTPHeaderField: "Origin")
        request.setValue("no-cache", forHTTPHeaderField: "Pragma")
        request.setValue("http://\(server.url):\(server.port)/ui/yacd/?hostname=\(server.url)&port=\(server.port)&secret=\(server.secret)", forHTTPHeaderField: "Referer")
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        
        Task {
            do {
                let (_, response) = try await URLSession.shared.data(for: request)
                if let httpResponse = response as? HTTPURLResponse,
                   httpResponse.statusCode == 204 {
                    // 不再调用 refresh()，而是直接在本地更新连接状态
                    await MainActor.run {
                        if let index = connections.firstIndex(where: { $0.id == id }) {
                            var updatedConnection = connections[index]
                            // 创建一个新的连接对象，将 isAlive 设置为 false
                            connections[index] = ClashConnection(
                                id: updatedConnection.id,
                                metadata: updatedConnection.metadata,
                                upload: updatedConnection.upload,
                                download: updatedConnection.download,
                                start: updatedConnection.start,
                                chains: updatedConnection.chains,
                                rule: updatedConnection.rule,
                                rulePayload: updatedConnection.rulePayload,
                                downloadSpeed: 0,
                                uploadSpeed: 0,
                                isAlive: false
                            )
                        }
                    }
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
    
    func toggleMonitoring() {
        if isMonitoring {
            stopMonitoring()
        } else if let server = server {
            startMonitoring(server: server)
        }
    }
    
    private func reconnect() {
        guard !isReconnecting else { return }
        isReconnecting = true
        
        // 取消现有的重连任务
        reconnectTask?.cancel()
        
        // 创建新的重连任务
        reconnectTask = Task {
            // 等待1秒后重试
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            
            guard !Task.isCancelled else { return }
            
            await MainActor.run {
                self.connectionState = .connecting
                self.isReconnecting = false
                
                if let server = self.server {
                    self.connectToConnections(server: server)
                }
            }
        }
    }
    
    private func handleWebSocketError(_ error: Error) {
        log("❌ WebSocket 错误：\(error.localizedDescription)")
        
        if errorTracker.recordError() {
            DispatchQueue.main.async { [weak self] in
                self?.connectionState = .error("连接失败，请检查网络或服务器状态")
            }
            stopMonitoring()
        } else {
            reconnect()
        }
    }
    
    // 简化清理方法，完全移除已关闭的连接
    func clearClosedConnections() {
        print("\n🧹 开始清理已断开连接")
        print("当前连接总数:", connections.count)
        print("历史连接数量:", previousConnections.count)
        
        // 获取要清理的连接ID
        let closedConnectionIds = connections.filter { !$0.isAlive }.map { $0.id }
        
        // 从当前连接列表中移除已断开的连接
        connections.removeAll { !$0.isAlive }
        
        // 从历史记录中也移除这些连接
        for id in closedConnectionIds {
            previousConnections.removeValue(forKey: id)
        }
        
        print("清理后连接数量:", connections.count)
        print("清理后历史连接数量:", previousConnections.count)
        print("✅ 清理完成")
        print("-------------------\n")
    }
    
    private func handleConnectionsUpdate(_ response: ConnectionsResponse) {
        Task { @MainActor in
            totalUpload = response.uploadTotal
            totalDownload = response.downloadTotal
            
            var updatedConnections: [ClashConnection] = []
            
            for connection in response.connections {
                if let previousConnection = previousConnections[connection.id] {
                    // 只有活跃的连接才会被添加到更新列表中
                    if connection.isAlive {
                        let updatedConnection = ClashConnection(
                            id: connection.id,
                            metadata: connection.metadata,
                            upload: connection.upload,
                            download: connection.download,
                            start: connection.start,
                            chains: connection.chains,
                            rule: connection.rule,
                            rulePayload: connection.rulePayload,
                            downloadSpeed: Double(connection.download - previousConnection.download),
                            uploadSpeed: Double(connection.upload - previousConnection.upload),
                            isAlive: connection.isAlive
                        )
                        updatedConnections.append(updatedConnection)
                    }
                } else if connection.isAlive {
                    // 新的活跃连接
                    let newConnection = ClashConnection(
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
                        isAlive: connection.isAlive
                    )
                    updatedConnections.append(newConnection)
                }
                
                // 只保存活跃连接的历史记录
                if connection.isAlive {
                    previousConnections[connection.id] = connection
                }
            }
            
            connections = updatedConnections
        }
    }
    
    func closeAllConnections() {
        guard let server = server else { return }
        
        let urlString = "http://\(server.url):\(server.port)/connections"
        guard let url = URL(string: urlString) else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        
        // 添加必要的请求头
        request.setValue("Bearer \(server.secret)", forHTTPHeaderField: "Authorization")
        request.setValue("http://\(server.url):\(server.port)/ui/yacd/?hostname=\(server.url)&port=\(server.port)&secret=\(server.secret)", forHTTPHeaderField: "Referer")
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        request.setValue("1", forHTTPHeaderField: "DNT")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        Task {
            do {
                let (_, response) = try await URLSession.shared.data(for: request)
                if let httpResponse = response as? HTTPURLResponse,
                   httpResponse.statusCode == 204 {
                    await MainActor.run {
                        // 清空所有连接相关的数据
                        connections.removeAll()
                        previousConnections.removeAll() // 同时清空历史记录
                    }
                }
            } catch {
                print("Error closing all connections: \(error)")
            }
        }
    }
} 
