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
    
    func queryDNS(server: ClashServer, domain: String, type: String) {
        guard let encodedDomain = domain.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "http://\(server.url):\(server.port)/dns/query?name=\(encodedDomain)&type=\(type)") else {
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(server.secret)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.results = ["查询失败: \(error.localizedDescription)"]
                    return
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