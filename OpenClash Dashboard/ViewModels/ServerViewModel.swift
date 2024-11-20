import Foundation

@MainActor
class ServerViewModel: ObservableObject {
    @Published var servers: [ClashServer] {
        didSet {
            saveServers()
        }
    }
    
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
        guard let serverIndex = servers.firstIndex(where: { $0.id == server.id }) else { return }
        
        guard let url = URL(string: "http://\(server.url):\(server.port)/version") else {
            servers[serverIndex].status = .error
            return
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 5
        if !server.secret.isEmpty {
            request.setValue("Bearer \(server.secret)", forHTTPHeaderField: "Authorization")
        }
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                servers[serverIndex].status = .error
                return
            }
            
            switch httpResponse.statusCode {
            case 200:
                servers[serverIndex].status = .ok
            case 401:
                servers[serverIndex].status = .unauthorized
            default:
                servers[serverIndex].status = .error
            }
        } catch {
            servers[serverIndex].status = .error
        }
    }
    
    func checkAllServersStatus() async {
        for server in servers {
            await checkServerStatus(server)
        }
    }
} 