import SwiftUI

enum LogLevel: String, CaseIterable {
    case debug = "调试"
    case info = "信息"
    case warning = "警告"
    case error = "错误"
    case silent = "静默"
    
    var systemImage: String {
        switch self {
        case .debug: return "ladybug"
        case .info: return "info.circle"
        case .warning: return "exclamationmark.triangle"
        case .error: return "xmark.circle"
        case .silent: return "speaker.slash"
        }
    }
    
    var color: Color {
        switch self {
        case .debug: return .secondary
        case .info: return .blue
        case .warning: return .orange
        case .error: return .red
        case .silent: return .gray
        }
    }
    
    var wsLevel: String {
        switch self {
        case .debug: return "debug"
        case .info: return "info"
        case .warning: return "warning"
        case .error: return "error"
        case .silent: return "silent"
        }
    }
} 