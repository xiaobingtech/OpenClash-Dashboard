import Foundation

enum NetworkError: LocalizedError {
    case invalidURL
    case serverUnreachable
    case invalidResponse
    case unauthorized
    case sslError
    case unknownError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "服务器地址无效"
        case .serverUnreachable:
            return "无法连接到服务器，请检查地址和端口是否正确"
        case .invalidResponse:
            return "服务器响应无效"
        case .unauthorized:
            return "认证失败，请检查密钥是否正确"
        case .sslError:
            return "SSL 连接失败，请检查服务器是否支持 HTTPS"
        case .unknownError(let error):
            return "发生错误: \(error.localizedDescription)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .invalidURL:
            return "请检查服务器地址格式是否正确"
        case .serverUnreachable:
            return "1. 检查服务器是否在线\n2. 确认地址和端口正确\n3. 检查网络连接"
        case .invalidResponse:
            return "请确认服务器运行正常"
        case .unauthorized:
            return "请检查密钥是否正确输入"
        case .sslError:
            return "1. 确认服务器支持 HTTPS\n2. 如果服务器仅支持 HTTP，请关闭 SSL 选项"
        case .unknownError:
            return "请稍后重试或联系支持"
        }
    }
} 