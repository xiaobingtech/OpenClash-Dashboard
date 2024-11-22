import Foundation

struct ClashConnection: Identifiable, Codable, Equatable {
    let id: String
    let metadata: ConnectionMetadata
    let upload: Int
    let download: Int
    let start: Date
    let chains: [String]
    let rule: String
    let rulePayload: String
    
    // 添加一个标准初始化方法
    init(id: String, metadata: ConnectionMetadata, upload: Int, download: Int, start: Date, chains: [String], rule: String, rulePayload: String) {
        self.id = id
        self.metadata = metadata
        self.upload = upload
        self.download = download
        self.start = start
        self.chains = chains
        self.rule = rule
        self.rulePayload = rulePayload
    }
    
    // 解码器初始化方法
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        metadata = try container.decode(ConnectionMetadata.self, forKey: .metadata)
        upload = try container.decode(Int.self, forKey: .upload)
        download = try container.decode(Int.self, forKey: .download)
        chains = try container.decode([String].self, forKey: .chains)
        rule = try container.decode(String.self, forKey: .rule)
        rulePayload = try container.decode(String.self, forKey: .rulePayload)
        
        let dateString = try container.decode(String.self, forKey: .start)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        if let date = formatter.date(from: dateString) {
            start = date
        } else {
            throw DecodingError.dataCorruptedError(
                forKey: .start,
                in: container,
                debugDescription: "Date string does not match expected format"
            )
        }
    }
    
    // 格式化方法保持不变
    var formattedStartTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd HH:mm:ss"
        return formatter.string(from: start)
    }
    
    var formattedDuration: String {
        let interval = Date().timeIntervalSince(start)
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.allowedUnits = [.day, .hour, .minute]
        formatter.maximumUnitCount = 1
        return formatter.string(from: interval) ?? ""
    }
    
    var formattedChains: String {
        let chainElements = chains.reversed()
        return "\(rule) → \(chainElements.joined(separator: " → "))"
    }
    
    // 预览数据
    static func preview() -> ClashConnection {
        return ClashConnection(
            id: "preview-id",
            metadata: ConnectionMetadata(
                network: "TCP",
                type: "HTTP",
                sourceIP: "192.168.1.1",
                destinationIP: "8.8.8.8",
                sourcePort: "12345",
                destinationPort: "443",
                host: "www.google.com",
                dnsMode: "normal",
                inboundIP: "127.0.0.1",
                inboundPort: "7890",
                inboundName: "mixed",
                remoteDestination: "",
                sourceGeoIP: nil,
                destinationGeoIP: nil,
                sourceIPASN: nil,
                destinationIPASN: nil,
                inboundUser: nil,
                uid: nil,
                process: nil,
                processPath: nil,
                specialProxy: nil,
                specialRules: nil,
                dscp: nil,
                sniffHost: nil
            ),
            upload: 1024,
            download: 8192,
            start: Date().addingTimeInterval(-3600),
            chains: ["DIRECT", "Proxy", "🇯🇵 日本节点"],
            rule: "MATCH",
            rulePayload: ""
        )
    }
}

struct ConnectionMetadata: Codable, Equatable {
    let network: String
    let type: String
    let sourceIP: String
    let destinationIP: String
    let sourcePort: String
    let destinationPort: String
    let host: String
    let dnsMode: String
    let inboundIP: String
    let inboundPort: String
    let inboundName: String
    let remoteDestination: String
    
    // API 响应中的其他可选字段
    let sourceGeoIP: String?
    let destinationGeoIP: [String]?
    let sourceIPASN: String?
    let destinationIPASN: String?
    let inboundUser: String?
    let uid: Int?
    let process: String?
    let processPath: String?
    let specialProxy: String?
    let specialRules: String?
    let dscp: Int?
    let sniffHost: String?
}

// API 响应模型
struct ConnectionsResponse: Codable {
    let downloadTotal: Int
    let uploadTotal: Int
    let connections: [ClashConnection]
    let memory: Int
} 