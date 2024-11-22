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
    let downloadSpeed: Double
    let uploadSpeed: Double
    let isAlive: Bool
    
    // 添加一个标准初始化方法
    init(id: String, metadata: ConnectionMetadata, upload: Int, download: Int, start: Date, chains: [String], rule: String, rulePayload: String, downloadSpeed: Double, uploadSpeed: Double, isAlive: Bool) {
        self.id = id
        self.metadata = metadata
        self.upload = upload
        self.download = download
        self.start = start
        self.chains = chains
        self.rule = rule
        self.rulePayload = rulePayload
        self.downloadSpeed = downloadSpeed
        self.uploadSpeed = uploadSpeed
        self.isAlive = isAlive
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
        
        // 将速度字段设为可选，默认为 0
        downloadSpeed = try container.decodeIfPresent(Double.self, forKey: .downloadSpeed) ?? 0
        uploadSpeed = try container.decodeIfPresent(Double.self, forKey: .uploadSpeed) ?? 0
        
        // 设置 isAlive 默认为 true，因为从服务器接收的连接都是活跃的
        isAlive = try container.decodeIfPresent(Bool.self, forKey: .isAlive) ?? true
        
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
                network: "tcp",
                type: "HTTPS",
                sourceIP: "192.168.1.1",
                destinationIP: "142.250.188.14",
                sourcePort: "48078",
                destinationPort: "443",
                host: "www.youtube.com",
                dnsMode: "normal",
                inboundIP: "127.0.0.1",
                inboundPort: "7890",
                inboundName: "DEFAULT-HTTP",
                remoteDestination: "14.29.122.199",
                sourceGeoIP: nil,
                destinationGeoIP: nil,
                sourceIPASN: "",
                destinationIPASN: "",
                inboundUser: "",
                uid: 0,
                process: "",
                processPath: "",
                specialProxy: "",
                specialRules: "",
                dscp: 0,
                sniffHost: ""
            ),
            upload: 304,
            download: 363946,
            start: Date().addingTimeInterval(-3600),
            chains: ["🇭🇰 香港 IEPL [01] [Air]", "Auto - UrlTest", "Proxy", "YouTube"],
            rule: "RuleSet",
            rulePayload: "YouTube",
            downloadSpeed: 1024.0,
            uploadSpeed: 512.0,
            isAlive: true
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
    let sourceGeoIP: String?
    let destinationGeoIP: [String]?
    let sourceIPASN: String
    let destinationIPASN: String
    let inboundUser: String
    let uid: Int
    let process: String
    let processPath: String
    let specialProxy: String
    let specialRules: String
    let dscp: Int
    let sniffHost: String
}

// API 响应模型
struct ConnectionsResponse: Codable {
    let downloadTotal: Int
    let uploadTotal: Int
    let connections: [ClashConnection]
    let memory: Int
}

// 添加编码键
private enum CodingKeys: String, CodingKey {
    case id, metadata, upload, download, start, chains, rule, rulePayload
    case downloadSpeed, uploadSpeed, isAlive
} 