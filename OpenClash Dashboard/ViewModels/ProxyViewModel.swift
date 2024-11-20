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
    private let server: ClashServer
    
    // 添加测速状态追踪
    @Published var testingNodes: Set<String> = []
    
    // 添加一个属性来追踪当前的数据获取任务
    private var currentTask: Task<Void, Never>?
    
    init(server: ClashServer) {
        self.server = server
        // 初始化时获取一次数据
        Task {
            await fetchProxies()
        }
    }
    
    @MainActor
    func fetchProxies() async {
        await currentTask?.value
        
        currentTask = Task {
            do {
                // 1. 获取 providers 数据
                guard let providersUrl = URL(string: "http://\(server.url):\(server.port)/providers/proxies") else { return }
                var providersRequest = URLRequest(url: providersUrl)
                providersRequest.setValue("Bearer \(server.secret)", forHTTPHeaderField: "Authorization")
                
                let (providersData, _) = try await URLSession.shared.data(for: providersRequest)
                if Task.isCancelled { return }
                
                print("收到providers数据响应")
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
                guard let proxiesUrl = URL(string: "http://\(server.url):\(server.port)/proxies") else { return }
                var proxiesRequest = URLRequest(url: proxiesUrl)
                proxiesRequest.setValue("Bearer \(server.secret)", forHTTPHeaderField: "Authorization")
                
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
                
                print("数据更新完成:")
                print("- Provider 数量:", self.providers.count)
                print("- Provider 名称:", self.providers.map { $0.name })
                print("- 代理组数量:", self.groups.count)
                print("- 节点数量:", self.nodes.count)
                
            } catch {
                if let urlError = error as? URLError, urlError.code == .cancelled {
                    print("任务被取消，这是正常的")
                } else {
                    print("获取数据出错：", error)
                    if let decodingError = error as? DecodingError {
                        print("解码错误详情：", decodingError)
                    }
                }
            }
        }
        
        await currentTask?.value
    }
    
    func testGroupDelay(groupName: String, nodes: [ProxyNode]) async {
        for node in nodes {
            if node.name == "REJECT" {
                continue
            }
            
            if node.name == "DIRECT" {
                await testNodeDelay(nodeName: "DIRECT")
                continue
            }
            
            let urlString = "http://\(server.url):\(server.port)/group/\(groupName)/delay"
            guard var components = URLComponents(string: urlString) else { return }
            
            components.queryItems = [
                URLQueryItem(name: "url", value: "https://www.gstatic.com/generate_204"),
                URLQueryItem(name: "timeout", value: "2000")
            ]
            
            guard let url = components.url else { return }
            
            var request = URLRequest(url: url)
            request.setValue("Bearer \(server.secret)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            // 添加测试状态动画
            await MainActor.run {
                testingNodes.insert(node.id)
            }
            
            do {
                let (data, _) = try await URLSession.shared.data(for: request)
                // print("收到响应数据：\(String(data: data, encoding: .utf8) ?? "")")
                
                // 尝试解析错误消息
                if let errorResponse = try? JSONDecoder().decode([String: String].self, from: data) {
                    // print("API 返回错误：\(errorResponse)")
                    await MainActor.run {
                        // 发生错误时移除所有测试状态
                        for node in nodes {
                            testingNodes.remove(node.id)
                        }
                    }
                    return
                }
                
                // 解析延迟数据
                let delays = try JSONDecoder().decode([String: Int].self, from: data)
                // print("解析延迟数据：\(delays)")
                
                await MainActor.run {
                    // 更新所有节点的延迟
                    for (nodeName, delay) in delays {
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
                    
                    // 从测试集合中移除所有节点
                    for node in nodes {
                        testingNodes.remove(node.id)
                    }
                }
            } catch {
                // print("测速错误：\(error)")
                if let decodingError = error as? DecodingError {
                    // print("解码错误详情：\(decodingError)")
                }
            }
        }
    }
    
    func selectProxy(groupName: String, proxyName: String) async {
        // 1. 选择代理节点
        guard let url = URL(string: "http://\(server.url):\(server.port)/proxies/\(groupName)") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(server.secret)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["name": proxyName]
        request.httpBody = try? JSONEncoder().encode(body)
        
        do {
            let (_, _) = try await URLSession.shared.data(for: request)
            
            // 2. 选择成功后，根据节点类型决定是否测试延迟
            if proxyName != "REJECT" {  // 不为 REJECT 节点时才测试延迟
                await testNodeDelay(nodeName: proxyName)
            }
            
            // 3. 最后刷新数据
            await fetchProxies()
        } catch {
            print("Error selecting proxy: \(error)")
        }
    }
    
    // 添加新方法用于测试单个节点延迟
    private func testNodeDelay(nodeName: String) async {
        let urlString = "http://\(server.url):\(server.port)/proxies/\(nodeName)/delay"
        let nodeId = nodes.first(where: { $0.name == nodeName })?.id
        
        guard var components = URLComponents(string: urlString) else { return }
        
        components.queryItems = [
            URLQueryItem(name: "url", value: "https://www.gstatic.com/generate_204"),
            URLQueryItem(name: "timeout", value: "2000")
        ]
        
        guard let url = components.url else { return }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(server.secret)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // 添加测试状态
        if let nodeId = nodeId {
            await MainActor.run {
                testingNodes.insert(nodeId)
            }
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            if let delay = try? JSONDecoder().decode([String: Int].self, from: data).values.first {
                await MainActor.run {
                    updateNodeDelay(nodeName: nodeName, delay: delay)
                    if let nodeId = nodeId {
                        testingNodes.remove(nodeId)
                    }
                }
            }
        } catch {
            if let nodeId = nodeId {
                await MainActor.run {
                    testingNodes.remove(nodeId)
                }
            }
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
        let urlString = "http://\(server.url):\(server.port)/group/\(groupName)/delay"
        guard var components = URLComponents(string: urlString) else { return }
        
        components.queryItems = [
            URLQueryItem(name: "url", value: "https://www.gstatic.com/generate_204"),
            URLQueryItem(name: "timeout", value: "2000")
        ]
        
        guard let url = components.url else { return }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(server.secret)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            if let delays = try? JSONDecoder().decode([String: Int].self, from: data) {
                // 更新所有节点的延迟
                for (nodeName, delay) in delays {
                    updateNodeDelay(nodeName: nodeName, delay: delay)
                }
            }
        } catch {
            print("Error testing group speed: \(error)")
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