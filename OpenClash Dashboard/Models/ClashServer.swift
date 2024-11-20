import SwiftUI

struct ClashServer: Identifiable, Codable {
    let id: UUID
    var name: String
    var url: String
    var port: String
    var secret: String
    var status: ServerStatus
    
    init(id: UUID = UUID(), name: String = "", url: String = "", port: String = "", secret: String = "", status: ServerStatus = .unknown) {
        self.id = id
        self.name = name
        self.url = url
        self.port = port
        self.secret = secret
        self.status = status
    }
    
    var displayName: String {
        if name.isEmpty {
            return "\(url):\(port)"
        }
        return name
    }
    
    var baseURL: URL? {
        let urlString = url.hasPrefix("http") ? url : "http://\(url)"
        return URL(string: "\(urlString):\(port)")
    }
    
    var proxyProvidersURL: URL? {
        baseURL?.appendingPathComponent("providers/proxies")
    }
    
    func makeRequest(url: URL?) throws -> URLRequest {
        guard let url = url else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(secret)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return request
    }
}

enum ServerStatus: String, Codable {
    case ok
    case unauthorized
    case error
    case unknown
    
    var color: Color {
        switch self {
        case .ok: return .green
        case .unauthorized: return .yellow
        case .error: return .red
        case .unknown: return .gray
        }
    }
    
    var text: String {
        switch self {
        case .ok: return "200 OK"
        case .unauthorized: return "401 Unauthorized"
        case .error: return "Error"
        case .unknown: return "Unknown"
        }
    }
} 
