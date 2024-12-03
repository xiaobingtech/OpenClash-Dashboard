import Foundation

struct DNSAnswer: Codable {
    let TTL: Int
    let data: String
}

struct DNSResponse: Codable {
    let Answer: [DNSAnswer]?
    let Status: Int
}

class DNSQueryViewModel: ObservableObject {
    @Published var results: [String] = []
    
    private func makeRequest(server: ClashServer, domain: String, type: String) -> URLRequest? {
        guard let encodedDomain = domain.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return nil
        }
        
        let scheme = server.useSSL ? "https" : "http"
        guard let url = URL(string: "\(scheme)://\(server.url):\(server.port)/dns/query?name=\(encodedDomain)&type=\(type)") else {
            return nil
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(server.secret)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return request
    }
    
    private func makeSession(server: ClashServer) -> URLSession {
        let config = URLSessionConfiguration.default
        if server.useSSL {
            config.urlCache = nil
            config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
            config.tlsMinimumSupportedProtocolVersion = .TLSv12
            config.tlsMaximumSupportedProtocolVersion = .TLSv13
        }
        return URLSession(configuration: config)
    }
    
    func queryDNS(server: ClashServer, domain: String, type: String) {
        guard let request = makeRequest(server: server, domain: domain, type: type) else {
            DispatchQueue.main.async { [weak self] in
                self?.results = ["无效的请求参数"]
            }
            return
        }
        
        let session = makeSession(server: server)
        
        session.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    if let urlError = error as? URLError {
                        switch urlError.code {
                        case .secureConnectionFailed:
                            self?.results = ["SSL/TLS 连接失败，请检查证书配置"]
                        case .serverCertificateUntrusted:
                            self?.results = ["服务器证书不受信任"]
                        case .clientCertificateRejected:
                            self?.results = ["客户端证书被拒绝"]
                        default:
                            self?.results = ["查询失败: \(error.localizedDescription)"]
                        }
                    } else {
                        self?.results = ["查询失败: \(error.localizedDescription)"]
                    }
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    if httpResponse.statusCode == 401 {
                        self?.results = ["认证失败，请检查 Secret"]
                        return
                    }
                }
                
                guard let data = data else {
                    self?.results = ["无响应数据"]
                    return
                }
                
                do {
                    let response = try JSONDecoder().decode(DNSResponse.self, from: data)
                    
                    if response.Status != 0 {
                        self?.results = ["查询失败: 状态码 \(response.Status)"]
                        return
                    }
                    
                    if let answers = response.Answer {
                        self?.results = answers.map { answer in
                            "TTL: \(answer.TTL)  数据: \(answer.data)"
                        }
                    } else {
                        self?.results = ["未找到记录"]
                    }
                } catch {
                    self?.results = ["解析失败: \(error.localizedDescription)"]
                }
            }
        }.resume()
    }
} 