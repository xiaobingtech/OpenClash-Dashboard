import Foundation

// 将 VersionResponse 移到类外面
struct VersionResponse: Codable {
    let meta: Bool?
    let premium: Bool?
    let version: String
}

@MainActor
class ServerViewModel: NSObject, ObservableObject, URLSessionDelegate {
    @Published var servers: [ClashServer] = []
    @Published var showError = false
    @Published var errorMessage: String?
    @Published var errorDetails: String?
    
    private static let saveKey = "SavedClashServers"
    private var activeSessions: [URLSession] = []  // 保持 URLSession 的引用
    
    override init() {
        super.init()
        loadServers()
    }

    private func determineServerType(from response: VersionResponse) -> ClashServer.ServerType {
        if response.premium == true {
            return .premium
        } else if response.meta == true {
            return .meta
        }
        return .unknown
    }
    
    private func makeURLSession(for server: ClashServer) -> URLSession {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 30
        
        if server.useSSL {
            config.urlCache = nil
            config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
            if #available(iOS 15.0, *) {
                config.tlsMinimumSupportedProtocolVersion = .TLSv12
            } else {
                config.tlsMinimumSupportedProtocolVersion = .TLSv12
            }
            config.tlsMaximumSupportedProtocolVersion = .TLSv13
        }
        
        let session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        activeSessions.append(session)  // 保存 session 引用
        return session
    }
    
    private func makeRequest(for server: ClashServer, path: String) -> URLRequest? {
        let scheme = server.useSSL ? "https" : "http"
        var urlComponents = URLComponents()
        
        urlComponents.scheme = scheme
        urlComponents.host = server.url
        urlComponents.port = Int(server.port)
        urlComponents.path = path
        
        guard let url = urlComponents.url else { return nil }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        
        if !server.secret.isEmpty {
            request.setValue("Bearer \(server.secret)", forHTTPHeaderField: "Authorization")
        }
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        return request
    }
    
    nonisolated func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        // print("🔐 收到证书验证请求")
        // print("认证方法: \(challenge.protectionSpace.authenticationMethod)")
        // print("主机: \(challenge.protectionSpace.host)")
        // print("端口: \(challenge.protectionSpace.port)")
        // print("协议: \(challenge.protectionSpace.protocol ?? "unknown")")
        
        // 始终接受所有证书
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust {
            // print("✅ 无条件接受服务器证书")
            if let serverTrust = challenge.protectionSpace.serverTrust {
                let credential = URLCredential(trust: serverTrust)
                completionHandler(.useCredential, credential)
            } else {
                // print("⚠️ 无法获取服务器证书")
                completionHandler(.performDefaultHandling, nil)
            }
        } else {
            // print("❌ 默认处理证书验证")
            completionHandler(.performDefaultHandling, nil)
        }
    }
    
    @MainActor
    func checkAllServersStatus() async {
        for server in servers {
            await checkServerStatus(server)
        }
    }
    
    @MainActor
    private func checkServerStatus(_ server: ClashServer) async {
        //  print("📡 开始检查服务器状态: \(server.displayName)")
        // print("🔐 SSL状态: \(server.useSSL ? "启用" : "禁用")")
        
        guard let request = makeRequest(for: server, path: "/version") else {
            //  print("❌ 创建请求失败")
            updateServerStatus(server, status: .error, message: "无效的请求")
            return
        }
        
        print("🌐 请求URL: \(request.url?.absoluteString ?? "unknown")")
        // print("📤 请求头: \(request.allHTTPHeaderFields ?? [:])")
        //  print("🔒 证书验证策略: 接受所有证书")
        
        do {
            let session = makeURLSession(for: server)
            // print("⏳ 开始网络请求...")
            
            let (data, response) = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<(Data, URLResponse), Error>) in
                let task = session.dataTask(with: request) { data, response, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else if let data = data, let response = response {
                        continuation.resume(returning: (data, response))
                    } else {
                        continuation.resume(throwing: URLError(.unknown))
                    }
                }
                task.resume()
            }
            
            // print("📥 收到响应")
            
            guard let httpResponse = response as? HTTPURLResponse else {
                //  print("❌ 无效的响应类型")
                updateServerStatus(server, status: .error, message: "无效的响应")
                return
            }
            
            // print("📊 HTTP状态码: \(httpResponse.statusCode)")
            // print("📨 响应头: \(httpResponse.allHeaderFields)")
            
            if let responseString = String(data: data, encoding: .utf8) {
                // print("📝 响应内容: \(responseString)")
            }
            
            switch httpResponse.statusCode {
            case 200:
                do {
                let versionResponse = try JSONDecoder().decode(VersionResponse.self, from: data)
                var updatedServer = server
                updatedServer.status = .ok
                updatedServer.version = versionResponse.version
                updatedServer.serverType = determineServerType(from: versionResponse)
                updatedServer.errorMessage = nil
                updateServer(updatedServer)
            } catch {
                    if let versionDict = try? JSONDecoder().decode([String: String].self, from: data),
                       let version = versionDict["version"] {
                        // print("✅ 成功获取版本(旧格式): \(version)")
                        var updatedServer = server
                        updatedServer.status = .ok
                        updatedServer.version = version
                        updatedServer.errorMessage = nil
                        updateServer(updatedServer)
                    } else {
                        // print("❌ 解析版本信息失败: \(error)")
                        updateServerStatus(server, status: .error, message: "无效的响应格式")
                    }
                }
            case 401:
                // print("🔒 认证失败")
                updateServerStatus(server, status: .unauthorized, message: "认证失败，请检查密钥")
            case 404:
                // print("🔍 API路径不存在")
                updateServerStatus(server, status: .error, message: "API 路径不存在")
            case 500...599:
                // print("⚠️ 服务器错误: \(httpResponse.statusCode)")
                updateServerStatus(server, status: .error, message: "服务器错误: \(httpResponse.statusCode)")
            default:
                // print("❓ 未知响应: \(httpResponse.statusCode)")
                updateServerStatus(server, status: .error, message: "未知响应: \(httpResponse.statusCode)")
            }
        } catch let error as URLError {
            print("🚫 URLError: \(error.localizedDescription)")
            // print("错误代码: \(error.code.rawValue)")
            // print("错误域: \(error.errorCode)")
            
            switch error.code {
            case .cancelled:
                // print("🚫 请求被取消")
                updateServerStatus(server, status: .error, message: "请求被取消")
            case .secureConnectionFailed:
                // print("🔒 SSL/TLS连接失败")
                updateServerStatus(server, status: .error, message: "SSL/TLS 连接失败")
            case .serverCertificateUntrusted:
                // print("🔒 证书不受信任")
                updateServerStatus(server, status: .error, message: "证书不受信任")
            case .timedOut:
                // print("⏰ 连接超时")
                updateServerStatus(server, status: .error, message: "连接超时")
            case .cannotConnectToHost:
                // print("🚫 无法连接到服务器")
                updateServerStatus(server, status: .error, message: "无法连接到服务器")
            case .notConnectedToInternet:
                // print("📡 网络未连接")
                updateServerStatus(server, status: .error, message: "网络未连接")
            default:
                // print("❌ 其他网络错误: \(error)")
                updateServerStatus(server, status: .error, message: "网络错误")
            }
        } catch {
            print("❌ 未知错误: \(error)")
            // print("错误类型: \(type(of: error))")
            // print("错误描述: \(error.localizedDescription)")
            updateServerStatus(server, status: .error, message: "未知错误")
        }
    }
    
    private func updateServerStatus(_ server: ClashServer, status: ServerStatus, message: String? = nil) {
        if let index = servers.firstIndex(where: { $0.id == server.id }) {
            var updatedServer = server
            updatedServer.status = status
            updatedServer.errorMessage = message
            servers[index] = updatedServer
            saveServers()
        }
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
            // Task {
            //     await checkServerStatus(server)
            // }
        }
    }
    
    func deleteServer(_ server: ClashServer) {
        servers.removeAll { $0.id == server.id }
        saveServers()
    }
} 