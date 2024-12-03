import Foundation

struct ProxyNode: Identifiable {
    let id: String
    let name: String
    let type: String
    let alive: Bool
    let delay: Int
    let history: [ProxyHistory]
}

struct ProxyHistory: Codable {
    let time: String
    let delay: Int
}

struct ProxyGroup: Identifiable {
    let id = UUID()
    let name: String
    let type: String
    let now: String
    let all: [String]
    let alive: Bool
    
    init(name: String, type: String, now: String, all: [String], alive: Bool = true) {
        self.name = name
        self.type = type
        self.now = now
        self.all = all
        self.alive = alive
    }
}

// 添加新的数据模型
struct ProxyProvider: Codable {
    let name: String
    let type: String
    let vehicleType: String
    let proxies: [ProxyDetail]
    let testUrl: String
    let subscriptionInfo: SubscriptionInfo?
    let updatedAt: String?
}

struct ProxyProvidersResponse: Codable {
    let providers: [String: ProxyProvider]
}

// 添加 Provider 模型
struct Provider: Identifiable {
    let id = UUID()
    let name: String
    let type: String
    let vehicleType: String
    let nodeCount: Int
    let testUrl: String
    let subscriptionInfo: SubscriptionInfo?
    let updatedAt: String?
}

struct SubscriptionInfo: Codable {
    let upload: Int64
    let download: Int64
    let total: Int64
    let expire: Int64
    
    enum CodingKeys: String, CodingKey {
        case upload = "Upload"
        case download = "Download"
        case total = "Total"
        case expire = "Expire"
    }
}

class ProxyViewModel: ObservableObject {
    @Published var providers: [Provider] = []
    @Published var groups: [ProxyGroup] = []
    @Published var nodes: [ProxyNode] = []
    @Published var providerNodes: [String: [ProxyNode]] = [:]
    @Published var testingNodes: Set<String> = []
    @Published var lastUpdated = Date()
    
    private let server: ClashServer
    private var currentTask: Task<Void, Never>?
    private let settingsViewModel = SettingsViewModel()
    
    init(server: ClashServer) {
        self.server = server
        Task {
            await fetchProxies()
            settingsViewModel.fetchConfig(server: server)
        }
    }
    
    private func makeRequest(path: String) -> URLRequest? {
        let scheme = server.useSSL ? "https" : "http"
        guard let url = URL(string: "\(scheme)://\(server.url):\(server.port)/\(path)") else {
            print("无效的 URL")
            return nil
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(server.secret)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return request
    }
    
    @MainActor
    func fetchProxies() async {
        currentTask?.cancel()
        
        currentTask = Task {
            do {
                // 1. 获取 providers 数据
                guard let providersRequest = makeRequest(path: "providers/proxies") else { return }
                
                let (providersData, response) = try await URLSession.shared.data(for: providersRequest)
                if Task.isCancelled { return }
                
                // 检查 HTTPS 响应
                if server.useSSL,
                   let httpsResponse = response as? HTTPURLResponse,
                   httpsResponse.statusCode == 400 {
                    print("SSL 连接失败，服务器可能不支持 HTTPS")
                    return
                }
                
                let providersResponse = try JSONDecoder().decode(ProxyProvidersResponse.self, from: providersData)
                
                // 2. 更新 providers 数据
                self.providers = providersResponse.providers.compactMap { name, provider in
                    guard provider.subscriptionInfo != nil else { return nil }
                    
                    return Provider(
                        name: name,
                        type: provider.type,
                        vehicleType: provider.vehicleType,
                        nodeCount: provider.proxies.count,
                        testUrl: provider.testUrl,
                        subscriptionInfo: provider.subscriptionInfo,
                        updatedAt: provider.updatedAt
                    )
                }
                
                // 3. 更新 providerNodes
                self.providerNodes = providersResponse.providers.mapValues { provider in
                    provider.proxies.map { proxy in
                        ProxyNode(
                            id: UUID().uuidString,
                            name: proxy.name,
                            type: proxy.type,
                            alive: proxy.alive,
                            delay: proxy.history.last?.delay ?? 0,
                            history: proxy.history
                        )
                    }
                }
                
                // 4. 获取代理数据
                guard let proxiesRequest = makeRequest(path: "proxies") else { return }
                
                let (proxiesData, _) = try await URLSession.shared.data(for: proxiesRequest)
                if Task.isCancelled { return }
                
                let proxiesResponse = try JSONDecoder().decode(ProxyResponse.self, from: proxiesData)
                
                // 5. 更新组和节点数据
                self.groups = proxiesResponse.proxies.compactMap { name, proxy in
                    guard proxy.all != nil else { return nil }
                    return ProxyGroup(
                        name: name,
                        type: proxy.type,
                        now: proxy.now ?? "",
                        all: proxy.all ?? []
                    )
                }
                
                // 6. 更新节点数据
                self.nodes = proxiesResponse.proxies.compactMap { name, proxy in
                    // 检查节点是否在任何组的 all 列表中
                    let isInAnyGroup = proxiesResponse.proxies.values.contains { p in
                        p.all?.contains(name) == true
                    }
                    
                    // 如果节点在任何组的 all 中，或者是普通节点（没有 all 属性），就保留
                    if isInAnyGroup || proxy.all == nil {
                        return ProxyNode(
                            id: proxy.id ?? UUID().uuidString,
                            name: name,
                            type: proxy.type,
                            alive: proxy.alive,
                            delay: proxy.history.last?.delay ?? 0,
                            history: proxy.history
                        )
                    }
                    return nil
                }
                
                // 7. 触发 objectWillChange 通知
                objectWillChange.send()
                
                print("数据更新完成:")
                print("- Provider 数量:", self.providers.count)
                print("- Provider 名称:", self.providers.map { $0.name })
                print("- 代理组数量:", self.groups.count)
                print("- 节点数量:", self.nodes.count)
                
            } catch {
                handleNetworkError(error)
            }
        }
    }
    
    func testGroupDelay(groupName: String, nodes: [ProxyNode]) async {
        for node in nodes {
            if node.name == "REJECT" || node.name == "DIRECT" {
                continue
            }
            
            let encodedGroupName = groupName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? groupName
            let path = "group/\(encodedGroupName)/delay"
            
            guard var request = makeRequest(path: path) else { continue }
            
            var components = URLComponents(url: request.url!, resolvingAgainstBaseURL: true)
            components?.queryItems = [
                URLQueryItem(name: "url", value: settingsViewModel.testUrl),
                URLQueryItem(name: "timeout", value: "2000")
            ]
            
            guard let finalUrl = components?.url else { continue }
            request.url = finalUrl
            
            _ = await MainActor.run {
                testingNodes.insert(node.name)
            }
            
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                
                // 检查 HTTPS 响应
                if server.useSSL,
                   let httpsResponse = response as? HTTPURLResponse,
                   httpsResponse.statusCode == 400 {
                    print("SSL 连接失败，服务器可能不支持 HTTPS")
                    continue
                }
                
                if let delays = try? JSONDecoder().decode([String: Int].self, from: data) {
                    _ = await MainActor.run {
                        for (nodeName, delay) in delays {
                            updateNodeDelay(nodeName: nodeName, delay: delay)
                        }
                        testingNodes.remove(node.name)
                    }
                }
            } catch {
                _ = await MainActor.run {
                    testingNodes.remove(node.name)
                }
                handleNetworkError(error)
            }
        }
    }
    
    private func handleNetworkError(_ error: Error) {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .secureConnectionFailed:
                print("SSL 连接失败：服务器的 SSL 证书无��")
            case .serverCertificateHasBadDate:
                print("SSL 错误：服务器证书已过期")
            case .serverCertificateUntrusted:
                print("SSL 错误：服务器证书不受信任")
            case .serverCertificateNotYetValid:
                print("SSL 错误：服务器证书尚未生效")
            case .cannotConnectToHost:
                print("无法连接到服务器：\(server.useSSL ? "HTTPS" : "HTTP") 连接失败")
            default:
                print("网络错误：\(urlError.localizedDescription)")
            }
        } else {
            print("其他错误：\(error.localizedDescription)")
        }
    }
    
    func selectProxy(groupName: String, proxyName: String) async {
        let encodedGroupName = groupName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? groupName
        guard var request = makeRequest(path: "proxies/\(encodedGroupName)") else { return }
        
        // 设置请求方法和请求体
        request.httpMethod = "PUT"
        let body = ["name": proxyName]
        request.httpBody = try? JSONEncoder().encode(body)
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            
            // 检查 HTTPS 响应
            if server.useSSL,
               let httpsResponse = response as? HTTPURLResponse,
               httpsResponse.statusCode == 400 {
                print("SSL 连接失败，服务器可能不支持 HTTPS")
                return
            }
            
            // 如果不是 REJECT 节点，测试延迟
            if proxyName != "REJECT" {
                await testNodeDelay(nodeName: proxyName)
            }
            
            // 刷新代理数据
            await fetchProxies()
            
        } catch {
            handleNetworkError(error)
        }
    }
    
    // 添加新方法用于测试单个节点延迟
    private func testNodeDelay(nodeName: String) async {
        let encodedNodeName = nodeName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? nodeName
        guard var request = makeRequest(path: "proxies/\(encodedNodeName)/delay") else { return }
        
        var components = URLComponents(url: request.url!, resolvingAgainstBaseURL: true)
        components?.queryItems = [
            URLQueryItem(name: "url", value: settingsViewModel.testUrl),
            URLQueryItem(name: "timeout", value: "2000")
        ]
        
        guard let finalUrl = components?.url else { return }
        request.url = finalUrl
        
        _ = await MainActor.run {
            testingNodes.insert(nodeName)
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            if let delay = try? JSONDecoder().decode([String: Int].self, from: data).values.first {
                _ = await MainActor.run {
                    updateNodeDelay(nodeName: nodeName, delay: delay)
                    testingNodes.remove(nodeName)
                }
            }
        } catch {
            _ = await MainActor.run {
                testingNodes.remove(nodeName)
            }
            handleNetworkError(error)
        }
    }
    
    // 辅助方法：更新节点延迟
    private func updateNodeDelay(nodeName: String, delay: Int) {
        // 更新 providerNodes 中的节点
        for (providerName, providerNodes) in self.providerNodes {
            self.providerNodes[providerName] = providerNodes.map { node in
                if node.name == nodeName {
                    return ProxyNode(
                        id: node.id,
                        name: node.name,
                        type: node.type,
                        alive: node.alive,
                        delay: delay,
                        history: node.history
                    )
                }
                return node
            }
        }
        
        // 更新 nodes 中的节点
        self.nodes = self.nodes.map { node in
            if node.name == nodeName {
                return ProxyNode(
                    id: node.id,
                    name: node.name,
                    type: node.type,
                    alive: node.alive,
                    delay: delay,
                    history: node.history
                )
            }
            return node
        }
    }
    
    @MainActor
    func refreshAllData() async {
        do {
            // 1. 获取理数据
            await fetchProxies()
            
            // 2. 测试所有节点延迟
            for group in groups {
                if let nodes = providerNodes[group.name] {
                    await testGroupDelay(groupName: group.name, nodes: nodes)
                }
            }
        } catch {
            print("Error refreshing all data: \(error)")
        }
    }
    
    // 添加一个公开的组测速方法
    @MainActor
    func testGroupSpeed(groupName: String) async {
        let encodedGroupName = groupName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? groupName
        guard var request = makeRequest(path: "group/\(encodedGroupName)/delay") else { return }
        
        var components = URLComponents(url: request.url!, resolvingAgainstBaseURL: true)
        components?.queryItems = [
            URLQueryItem(name: "url", value: settingsViewModel.testUrl),
            URLQueryItem(name: "timeout", value: "2000")
        ]
        
        guard let finalUrl = components?.url else { return }
        request.url = finalUrl
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            // 检查 HTTPS 响应
            if server.useSSL,
               let httpsResponse = response as? HTTPURLResponse,
               httpsResponse.statusCode == 400 {
                print("SSL 连接失败，服务器可能不支持 HTTPS")
                return
            }
            
            if let decodedData = try? JSONDecoder().decode([String: Int].self, from: data) {
                for (nodeName, delay) in decodedData {
                    updateNodeDelay(nodeName: nodeName, delay: delay)
                }
            }
        } catch {
            handleNetworkError(error)
        }
    }
    
    @MainActor
    func updateProxyProvider(providerName: String) async {
        let encodedProviderName = providerName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? providerName
        guard var request = makeRequest(path: "providers/proxies/\(encodedProviderName)") else { return }
        
        request.httpMethod = "PUT"
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            
            if server.useSSL,
               let httpsResponse = response as? HTTPURLResponse,
               httpsResponse.statusCode == 400 {
                print("SSL 连接失败，服务器可能不支持 HTTPS")
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse,
               (200...299).contains(httpResponse.statusCode) {
                print("代理提供者 \(providerName) 更新成功")
                
                // 更新时间戳触发视图刷新
                self.lastUpdated = Date()
                
                // 获取最新数据
                await fetchProxies()
            } else {
                print("代理提供者 \(providerName) 更新失败")
            }
        } catch {
            handleNetworkError(error)
        }
    }
}

// API 响应模型
struct ProxyResponse: Codable {
    let proxies: [String: ProxyDetail]
}

struct ProxyDetail: Codable {
    let name: String
    let type: String
    let alive: Bool
    let now: String?
    let all: [String]?
    let history: [ProxyHistory]
    let id: String?
}

// 添加 ProviderResponse 结构体
struct ProviderResponse: Codable {
    let type: String
    let vehicleType: String
    let proxies: [ProxyInfo]?
    let testUrl: String?
    let subscriptionInfo: SubscriptionInfo?
    let updatedAt: String?
}

struct ProxyInfo: Codable {
    let name: String
    let type: String
    let alive: Bool
    let history: [ProxyHistory]
} 
