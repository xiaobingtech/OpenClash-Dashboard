import Foundation

class ConnectionsViewModel: ObservableObject {
    @Published var connections: [(host: String, source: String, destination: String, upload: Int, download: Int)] = [
        ("example1.com", "192.168.1.1:8080", "10.0.0.1:443", 100, 1000),
        ("example2.com", "192.168.1.2:8080", "10.0.0.2:443", 200, 2000),
        ("example3.com", "192.168.1.3:8080", "10.0.0.3:443", 300, 3000)
    ]
    
    func refreshConnections() {
        // 模拟刷新连接
        connections.shuffle()
    }
} 