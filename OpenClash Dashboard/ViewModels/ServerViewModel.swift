import Foundation

@MainActor
class ServerViewModel: ObservableObject {
    @Published var servers: [ClashServer] = []
    @Published var errorMessage: String?
    @Published var errorDetails: String?
    @Published var showError = false
    
    init() {
        self.servers = ServerViewModel.loadServers()
    }
    
    private static func loadServers() -> [ClashServer] {
        guard let data = UserDefaults.standard.data(forKey: "servers"),
              let servers = try? JSONDecoder().decode([ClashServer].self, from: data) else {
            return []
        }
        return servers
    }
    
    private func saveServers() {
        if let encoded = try? JSONEncoder().encode(servers) {
            UserDefaults.standard.set(encoded, forKey: "servers")
        }
    }
    
    func addServer(_ server: ClashServer) {
        servers.append(server)
        Task {
            await checkServerStatus(server)
        }
    }
    
    func updateServer(_ server: ClashServer) {
        if let index = servers.firstIndex(where: { $0.id == server.id }) {
            servers[index] = server
            Task {
                await checkServerStatus(server)
            }
        }
    }
    
    func deleteServer(_ server: ClashServer) {
        servers.removeAll { $0.id == server.id }
    }
    
    func checkServerStatus(_ server: ClashServer) async {
        do {
            guard let versionURL = server.baseURL?.appendingPathComponent("version") else {
                throw NetworkError.invalidURL
            }
            
            let request = try server.makeRequest(url: versionURL)
            let (_, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }
            
            await MainActor.run {
                var updatedServer = server
                switch httpResponse.statusCode {
                case 200:
                    updatedServer.status = .ok
                case 401:
                    updatedServer.status = .unauthorized
                default:
                    updatedServer.status = .error
                }
                if let index = servers.firstIndex(where: { $0.id == server.id }) {
                    servers[index] = updatedServer
                }
            }
        } catch {
            await MainActor.run {
                let networkError = ClashServer.handleNetworkError(error)
                errorMessage = networkError.errorDescription
                errorDetails = networkError.recoverySuggestion
                showError = true
                
                if let index = servers.firstIndex(where: { $0.id == server.id }) {
                    var updatedServer = server
                    updatedServer.status = .error
                    servers[index] = updatedServer
                }
            }
        }
    }
    
    func checkAllServersStatus() async {
        for server in servers {
            await checkServerStatus(server)
        }
    }
} 