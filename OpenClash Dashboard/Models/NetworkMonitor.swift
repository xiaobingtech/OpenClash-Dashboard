import Foundation
import SwiftUI

class NetworkMonitor: ObservableObject {
    @Published var uploadSpeed: String = "0 B/s"
    @Published var downloadSpeed: String = "0 B/s"
    @Published var totalUpload = "0 MB"
    @Published var totalDownload = "0 MB"
    @Published var activeConnections = 0
    @Published var memoryUsage = "0 MB"
    @Published var speedHistory: [SpeedRecord] = []
    @Published var memoryHistory: [MemoryRecord] = []
    
    private var trafficTask: URLSessionWebSocketTask?
    private var memoryTask: URLSessionWebSocketTask?
    private var connectionsTask: URLSessionWebSocketTask?
    private let session = URLSession(configuration: .default)
    
    func startMonitoring(server: ClashServer) {
        connectToTraffic(server: server)
        connectToMemory(server: server)
        connectToConnections(server: server)
    }
    
    func stopMonitoring() {
        print("停止所有 WebSocket 连接")
        trafficTask?.cancel()
        memoryTask?.cancel()
        connectionsTask?.cancel()
    }
    
    private func connectToTraffic(server: ClashServer) {
        guard let url = URL(string: "ws://\(server.url):\(server.port)/traffic") else { return }
        print("正在连接 Traffic WebSocket: \(url.absoluteString)")
        
        var request = URLRequest(url: url)
        if !server.secret.isEmpty {
            request.setValue("Bearer \(server.secret)", forHTTPHeaderField: "Authorization")
        }
        
        trafficTask = session.webSocketTask(with: request)
        trafficTask?.resume()
        receiveTrafficData()
    }
    
    private func connectToMemory(server: ClashServer) {
        guard let url = URL(string: "ws://\(server.url):\(server.port)/memory") else { return }
        print("正在连接 Memory WebSocket: \(url.absoluteString)")
        
        var request = URLRequest(url: url)
        if !server.secret.isEmpty {
            request.setValue("Bearer \(server.secret)", forHTTPHeaderField: "Authorization")
        }
        
        memoryTask = session.webSocketTask(with: request)
        memoryTask?.resume()
        receiveMemoryData()
    }
    
    private func connectToConnections(server: ClashServer) {
        guard let url = URL(string: "ws://\(server.url):\(server.port)/connections") else { return }
        print("正在连接 Connections WebSocket: \(url.absoluteString)")
        
        var request = URLRequest(url: url)
        if !server.secret.isEmpty {
            request.setValue("Bearer \(server.secret)", forHTTPHeaderField: "Authorization")
        }
        
        connectionsTask = session.webSocketTask(with: request)
        connectionsTask?.resume()
        receiveConnectionsData()
    }
    
    private func receiveTrafficData() {
        trafficTask?.receive { [weak self] result in
            switch result {
            case .success(let message):
                print("Traffic WebSocket 已连接并接收数据")
                switch message {
                case .string(let text):
                    self?.handleTrafficData(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        self?.handleTrafficData(text)
                    }
                @unknown default:
                    break
                }
                self?.receiveTrafficData() // 继续接收数据
            case .failure(let error):
                print("Traffic WebSocket 错误: \(error)")
            }
        }
    }
    
    private func receiveMemoryData() {
        memoryTask?.receive { [weak self] result in
            switch result {
            case .success(let message):
                print("Memory WebSocket 已连接并接收数据")
                switch message {
                case .string(let text):
                    self?.handleMemoryData(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        self?.handleMemoryData(text)
                    }
                @unknown default:
                    break
                }
                self?.receiveMemoryData() // 继续接收数据
            case .failure(let error):
                print("Memory WebSocket 错误: \(error)")
            }
        }
    }
    
    private func receiveConnectionsData() {
        connectionsTask?.receive { [weak self] result in
            switch result {
            case .success(let message):
                print("Connections WebSocket 已连接并接收数据")
                switch message {
                case .string(let text):
                    self?.handleConnectionsData(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        self?.handleConnectionsData(text)
                    }
                @unknown default:
                    break
                }
                self?.receiveConnectionsData() // 继续接收数据
            case .failure(let error):
                print("Connections WebSocket 错误: \(error)")
            }
        }
    }
    
    private func handleTrafficData(_ text: String) {
        guard let data = text.data(using: .utf8),
              let traffic = try? JSONDecoder().decode(TrafficData.self, from: data) else { return }
        
        DispatchQueue.main.async { [weak self] in
            self?.updateTraffic(traffic)
        }
    }
    
    private func updateTraffic(_ traffic: TrafficData) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // 更新速度显示
            self.uploadSpeed = formatSpeed(traffic.up)
            self.downloadSpeed = formatSpeed(traffic.down)
            
            // 创建新记录
            let record = SpeedRecord(
                timestamp: Date(),
                upload: Double(traffic.up),
                download: Double(traffic.down)
            )
            
            // 确保历史记录不会无限增长
            if self.speedHistory.count > 30 {
                self.speedHistory.removeFirst()
            }
            
            // 添加新记录
            self.speedHistory.append(record)
            
            // 对数据进行平滑处理
            if self.speedHistory.count > 1 {
                let lastIndex = self.speedHistory.count - 1
                let previousRecord = self.speedHistory[lastIndex - 1]
                
                // 如果当前值为0且前一个值不为0，添加一个渐变到0的点
                if record.upload == 0 && previousRecord.upload > 0 {
                    let intermediateRecord = SpeedRecord(
                        timestamp: record.timestamp.addingTimeInterval(-0.1),
                        upload: previousRecord.upload * 0.1,
                        download: previousRecord.download * 0.1
                    )
                    self.speedHistory.insert(intermediateRecord, at: lastIndex)
                }
            }
        }
    }
    
    private func handleMemoryData(_ text: String) {
        guard let data = text.data(using: .utf8),
              let memory = try? JSONDecoder().decode(MemoryData.self, from: data) else { return }
        
        DispatchQueue.main.async { [weak self] in
            self?.memoryUsage = self?.formatBytes(memory.inuse) ?? "0 MB"
            
            let newMemoryRecord = MemoryRecord(
                timestamp: Date(),
                usage: Double(memory.inuse) / 1024 / 1024 // 转换为 MB
            )
            self?.memoryHistory.append(newMemoryRecord)
            if self?.memoryHistory.count ?? 0 > 60 {
                self?.memoryHistory.removeFirst()
            }
        }
    }
    
    private func handleConnectionsData(_ text: String) {
        guard let data = text.data(using: .utf8),
              let connections = try? JSONDecoder().decode(ConnectionsData.self, from: data) else { return }
        
        DispatchQueue.main.async { [weak self] in
            self?.activeConnections = connections.connections.count
            self?.totalUpload = self?.formatBytes(connections.uploadTotal) ?? "0 MB"
            self?.totalDownload = self?.formatBytes(connections.downloadTotal) ?? "0 MB"
        }
    }
    
    private func formatSpeed(_ bytes: Int) -> String {
        let kb = Double(bytes) / 1024
        if kb < 1024 {
            return String(format: "%.1f KB/s", kb)
        }
        let mb = kb / 1024
        return String(format: "%.1f MB/s", mb)
    }
    
    private func formatBytes(_ bytes: Int) -> String {
        let mb = Double(bytes) / 1024 / 1024
        if mb < 1024 {
            return String(format: "%.1f MB", mb)
        }
        let gb = mb / 1024
        return String(format: "%.2f GB", gb)
    }
}

// 数据模型
struct TrafficData: Codable {
    let up: Int
    let down: Int
}

struct MemoryData: Codable {
    let inuse: Int
    let oslimit: Int
}

struct ConnectionsData: Codable {
    let downloadTotal: Int
    let uploadTotal: Int
    let connections: [Connection]
    let memory: Int
}

struct Connection: Codable {
    let id: String
    let upload: Int
    let download: Int
    let start: String
    // 其他字段可以根据需要添加
}

struct SpeedRecord: Identifiable {
    let id = UUID()
    let timestamp: Date
    let upload: Double
    let download: Double
}

struct MemoryRecord: Identifiable {
    let id = UUID()
    let timestamp: Date
    let usage: Double
} 