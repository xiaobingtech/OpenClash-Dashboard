import Foundation

class RulesViewModel: ObservableObject {
    @Published var searchText = ""
    @Published var isLoading = true
    @Published var rules: [Rule] = []
    @Published var providers: [RuleProvider] = []
    
    let server: ClashServer
    
    struct Rule: Codable, Identifiable, Hashable {
        let type: String
        let payload: String
        let proxy: String
        let size: Int?  // 改为可选类型，适配原版 Clash 内核
        
        var id: String { "\(type)-\(payload)" }
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }
        
        static func == (lhs: Rule, rhs: Rule) -> Bool {
            lhs.id == rhs.id
        }
        
        var sectionKey: String {
            let firstChar = String(payload.prefix(1)).uppercased()
            return firstChar.first?.isLetter == true ? firstChar : "#"
        }
    }
    
    struct RuleProvider: Codable, Identifiable {
        var name: String
        let behavior: String
        let type: String
        let ruleCount: Int
        let updatedAt: String
        let format: String?  // 改为可选类型
        let vehicleType: String
        
        var id: String { name }
        
        enum CodingKeys: String, CodingKey {
            case behavior, type, ruleCount, updatedAt, format, vehicleType
            case name
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.name = ""
            self.behavior = try container.decode(String.self, forKey: .behavior)
            self.type = try container.decode(String.self, forKey: .type)
            self.ruleCount = try container.decode(Int.self, forKey: .ruleCount)
            self.updatedAt = try container.decode(String.self, forKey: .updatedAt)
            self.format = try container.decodeIfPresent(String.self, forKey: .format)  // 使用 decodeIfPresent
            self.vehicleType = try container.decode(String.self, forKey: .vehicleType)
        }
        
        var formattedUpdateTime: String {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSSSS'Z'"
            if let date = formatter.date(from: updatedAt) {
                formatter.dateFormat = "MM-dd HH:mm"
                return formatter.string(from: date)
            }
            return "未知"
        }
    }
    
    init(server: ClashServer) {
        self.server = server
        Task { await fetchData() }
    }
    
    @MainActor
    func fetchData() async {
        isLoading = true
        defer { isLoading = false }
        
        // 获取规则
        if let rulesData = try? await fetchRules() {
            self.rules = rulesData.rules
        }
        
        // 获取规则提供者
        if let providersData = try? await fetchProviders() {
            self.providers = providersData.providers.map { name, provider in
                var provider = provider
                provider.name = name
                return provider
            }
        }
    }
    
    private func fetchRules() async throws -> RulesResponse {
        guard let url = server.baseURL?.appendingPathComponent("rules") else {
            throw URLError(.badURL)
        }
        let request = try server.makeRequest(url: url)
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(RulesResponse.self, from: data)
    }
    
    private func fetchProviders() async throws -> ProvidersResponse {
        guard let url = server.baseURL?.appendingPathComponent("providers/rules") else {
            throw URLError(.badURL)
        }
        let request = try server.makeRequest(url: url)
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(ProvidersResponse.self, from: data)
    }
    
    @MainActor
    func refreshProvider(_ name: String) async {
        do {
            // 构建刷新 URL
            guard let baseURL = server.baseURL else {
                throw URLError(.badURL)
            }
            
            let url = baseURL
                .appendingPathComponent("providers")
                .appendingPathComponent("rules")
                .appendingPathComponent(name)
            
            var request = URLRequest(url: url)
            request.httpMethod = "PUT"
            request.setValue(server.secret, forHTTPHeaderField: "Authorization")
            
            let (_, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode == 204 {
                // 刷新成功后重新获取数据
                await fetchData()
            }
        } catch {
            print("Error refreshing provider: \(error)")
        }
    }
}

// Response models
struct RulesResponse: Codable {
    let rules: [RulesViewModel.Rule]
}

struct ProvidersResponse: Codable {
    let providers: [String: RulesViewModel.RuleProvider]
} 