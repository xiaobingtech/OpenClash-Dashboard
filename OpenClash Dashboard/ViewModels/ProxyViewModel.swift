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
        print("开始获取代理数据")
        // 取消之前的任务
        currentTask?.cancel()
        
        // 创建新的任务
        currentTask = Task {
            do {
                print("当前代理组状态：", self.groups.map { "\($0.name): \($0.now)" })
                
                // 1. 获取代理数据
                guard let proxiesUrl = URL(string: "http://\(server.url):\(server.port)/proxies") else { return }
                var proxiesRequest = URLRequest(url: proxiesUrl)
                proxiesRequest.setValue("Bearer \(server.secret)", forHTTPHeaderField: "Authorization")
                
                let (proxiesData, _) = try await URLSession.shared.data(for: proxiesRequest)
                print("收到代理数据响应")
                
                if Task.isCancelled { return }
                let proxiesResponse = try JSONDecoder().decode(ProxyResponse.self, from: proxiesData)
                
                // 2. 获取 providers 数据
                guard let providersUrl = URL(string: "http://\(server.url):\(server.port)/providers/proxies") else { return }
                var providersRequest = URLRequest(url: providersUrl)
                providersRequest.setValue("Bearer \(server.secret)", forHTTPHeaderField: "Authorization")
                
                let (providersData, _) = try await URLSession.shared.data(for: providersRequest)
                print("收到providers数据响应")
                
                if Task.isCancelled { return }
                let providersResponse = try JSONDecoder().decode(ProxyProvidersResponse.self, from: providersData)
                
                // 3. 更新数据
                print("开始更新数据模型")
                
                self.groups = proxiesResponse.proxies.values
                    .filter { $0.all != nil }
                    .map { proxy in
                        ProxyGroup(
                            name: proxy.name,
                            type: proxy.type,
                            now: proxy.now ?? "",
                            all: proxy.all ?? [],
                            alive: proxy.alive
                        )
                    }
                    .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
                
                print("更新后的代理组状态：", self.groups.map { "\($0.name): \($0.now)" })
                
                self.nodes = proxiesResponse.proxies.map { name, proxy in
                    ProxyNode(
                        id: proxy.id ?? UUID().uuidString,
                        name: proxy.name,
                        type: proxy.type,
                        alive: proxy.alive,
                        delay: proxy.history.last?.delay ?? 0,
                        history: proxy.history
                    )
                }
                
                // 4. 触发视图更新
                print("触发视图更新")
                objectWillChange.send()
                
            } catch {
                print("获取数据出错：", error)
            }
        }
        
        await currentTask?.value
        print("数据获取完成")
    }
    
    func testGroupDelay(groupName: String, nodes: [ProxyNode]) async {
        print("开始测速：组名 = \(groupName), 节点数 = \(nodes.count)")
        
        // 修正 URL 路径
        let urlString = "http://\(server.url):\(server.port)/group/\(groupName)/delay"
        guard var components = URLComponents(string: urlString) else {
            print("URL 构建失败")
            return
        }
        
        components.queryItems = [
            URLQueryItem(name: "url", value: "https://www.gstatic.com/generate_204"),
            URLQueryItem(name: "timeout", value: "2000")
        ]
        
        guard let url = components.url else { return }
        print("请求 URL: \(url)")
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(server.secret)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // 添加测试状态动画
        await MainActor.run {
            for node in nodes {
                testingNodes.insert(node.id)
            }
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            print("收到响应数据：\(String(data: data, encoding: .utf8) ?? "")")
            
            // 尝试解析错误消息
            if let errorResponse = try? JSONDecoder().decode([String: String].self, from: data) {
                print("API 返回错误：\(errorResponse)")
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
            print("解析延迟数据：\(delays)")
            
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
            print("测速错误：\(error)")
            if let decodingError = error as? DecodingError {
                print("解码错误详情：\(decodingError)")
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
            // 2. 选择成功后，测试新选择的节点延迟
            await testNodeDelay(nodeName: proxyName)
            // 3. 最后刷新数据
            await fetchProxies()
        } catch {
            print("Error selecting proxy: \(error)")
        }
    }
    
    // 添加新方法用于测试单个节点延迟
    private func testNodeDelay(nodeName: String) async {
        guard var components = URLComponents(string: "http://\(server.url):\(server.port)/proxies/\(nodeName)/delay") else { return }
        
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
            if let delay = try? JSONDecoder().decode([String: Int].self, from: data).values.first {
                await MainActor.run {
                    // 更新节点延迟
                    updateNodeDelay(nodeName: nodeName, delay: delay)
                }
            }
        } catch {
            print("Error testing node delay: \(error)")
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
            // 1. 获取代理数据
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