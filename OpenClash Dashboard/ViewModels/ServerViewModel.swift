import Foundation

@MainActor
class ServerViewModel: ObservableObject {
    @Published var servers: [ClashServer] = []
    @Published var showError = false
    @Published var errorMessage: String?
    @Published var errorDetails: String?
    
    private static let saveKey = "SavedClashServers"
    
    init() {
        loadServers()
    }
    
    private func makeURLSession(for server: ClashServer) -> URLSession {
        let config = URLSessionConfiguration.default
        if server.useSSL {
            config.urlCache = nil
            config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
            config.tlsMinimumSupportedProtocolVersion = .TLSv12
            config.tlsMaximumSupportedProtocolVersion = .TLSv13
        }
        return URLSession(configuration: config)
    }
    
    private func makeRequest(for server: ClashServer, path: String = "") -> URLRequest? {
        let scheme = server.useSSL ? "https" : "http"
        guard let url = URL(string: "\(scheme)://\(server.url):\(server.port)\(path)") else {
            return nil
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        
        if !server.secret.isEmpty {
            request.setValue("Bearer \(server.secret)", forHTTPHeaderField: "Authorization")
        }
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        return request
    }
    
    @MainActor
    func checkAllServersStatus() async {
        for server in servers {
            await checkServerStatus(server)
        }
    }
    
    @MainActor
    private func checkServerStatus(_ server: ClashServer) async {
        guard let request = makeRequest(for: server, path: "/version") else {
            updateServerStatus(server, status: .error)
            return
        }
        
        do {
            let session = makeURLSession(for: server)
            let (data, response) = try await session.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                switch httpResponse.statusCode {
                case 200:
                    if let version = try? JSONDecoder().decode([String: String].self, from: data)["version"] {
                        var updatedServer = server
                        updatedServer.status = .ok
                        updatedServer.version = version
                        updateServer(updatedServer)
                    }
                case 401:
                    updateServerStatus(server, status: .unauthorized)
                default:
                    updateServerStatus(server, status: .error)
                }
            }
        } catch {
            handleNetworkError(error, for: server)
        }
    }
    
    private func handleNetworkError(_ error: Error, for server: ClashServer) {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .secureConnectionFailed:
                showError(message: "SSL/TLS 连接失败", details: "请检查服务器的 HTTPS 配置")
                updateServerStatus(server, status: .error)
            case .serverCertificateUntrusted:
                showError(message: "服务器证书不受信任", details: "请检查服务器的 SSL 证书")
                updateServerStatus(server, status: .error)
            case .timedOut:
                showError(message: "连接超时", details: "请检查服务器地址和端口")
                updateServerStatus(server, status: .error)
            case .cannotConnectToHost:
                showError(message: "无法连接到服务器", details: "请检查服务器是否在线")
                updateServerStatus(server, status: .error)
            default:
                showError(message: "网络错误", details: error.localizedDescription)
                updateServerStatus(server, status: .error)
            }
        } else {
            showError(message: "未知错误", details: error.localizedDescription)
            updateServerStatus(server, status: .error)
        }
    }
    
    private func updateServerStatus(_ server: ClashServer, status: ServerStatus) {
        if let index = servers.firstIndex(where: { $0.id == server.id }) {
            var updatedServer = server
            updatedServer.status = status
            servers[index] = updatedServer
            saveServers()
        }
    }
    
    private func showError(message: String, details: String? = nil) {
        errorMessage = message
        errorDetails = details
        showError = true
    }
    
    private func loadServers() {
        if let data = UserDefaults.standard.data(forKey: Self.saveKey),
           let decoded = try? JSONDecoder().decode([ClashServer].self, from: data) {
            servers = decoded
        }
    }
    
    private func saveServers() {
        if let encoded = try? JSONEncoder().encode(servers) {
            UserDefaults.standard.set(encoded, forKey: Self.saveKey)
        }
    }
    
    func addServer(_ server: ClashServer) {
        servers.append(server)
        saveServers()
        Task {
            await checkServerStatus(server)
        }
    }
    
    func updateServer(_ server: ClashServer) {
        if let index = servers.firstIndex(where: { $0.id == server.id }) {
            servers[index] = server
            saveServers()
            Task {
                await checkServerStatus(server)
            }
        }
    }
    
    func deleteServer(_ server: ClashServer) {
        servers.removeAll { $0.id == server.id }
        saveServers()
    }
} 