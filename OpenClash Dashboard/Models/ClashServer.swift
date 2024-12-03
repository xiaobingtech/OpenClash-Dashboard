import SwiftUI

struct ClashServer: Identifiable, Codable {
    let id: UUID
    var name: String
    var url: String
    var port: String
    var secret: String
    var status: ServerStatus
    var version: String?
    var useSSL: Bool
    
    init(id: UUID = UUID(), name: String = "", url: String = "", port: String = "", secret: String = "", status: ServerStatus = .unknown, version: String? = nil, useSSL: Bool = false) {
        self.id = id
        self.name = name
        self.url = url
        self.port = port
        self.secret = secret
        self.status = status
        self.version = version
        self.useSSL = useSSL
    }
    
    var displayName: String {
        if name.isEmpty {
            return "\(url):\(port)"
        }
        return name
    }
    
    var baseURL: URL? {
        let cleanURL = url.replacingOccurrences(of: "^https?://", with: "", options: .regularExpression)
        let scheme = useSSL ? "https" : "http"
        return URL(string: "\(scheme)://\(cleanURL):\(port)")
    }
    
    var proxyProvidersURL: URL? {
        baseURL?.appendingPathComponent("providers/proxies")
    }
    
    func makeRequest(url: URL?) throws -> URLRequest {
        guard let url = url else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(secret)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10
        return request
    }
    
    static func handleNetworkError(_ error: Error) -> NetworkError {
        switch error {
        case let urlError as URLError:
            switch urlError.code {
            case .timedOut, .cannotConnectToHost, .networkConnectionLost:
                return .serverUnreachable
            case .secureConnectionFailed, .serverCertificateHasBadDate,
                 .serverCertificateUntrusted, .serverCertificateNotYetValid:
                return .sslError
            case .badServerResponse, .cannotParseResponse:
                return .invalidResponse
            case .userAuthenticationRequired:
                return .unauthorized
            default:
                return .unknownError(error)
            }
        case let networkError as NetworkError:
            return networkError
        default:
            return .unknownError(error)
        }
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
