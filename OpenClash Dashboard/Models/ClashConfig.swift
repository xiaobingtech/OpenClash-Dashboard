struct ClashConfig: Codable {
    let port: Int
    let socksPort: Int
    let redirPort: Int
    let mixedPort: Int
    let mode: String
    let logLevel: String
    let allowLan: Bool
    let sniffing: Bool
    let interfaceName: String
    let tun: TunConfig
    
    struct TunConfig: Codable {
        let enable: Bool
        let device: String
        let stack: String
        let autoRoute: Bool
        let autoDetectInterface: Bool
        let dnsHijack: [String]
        let inet4Address: [String]
        
        enum CodingKeys: String, CodingKey {
            case enable
            case device
            case stack
            case autoRoute = "auto-route"
            case autoDetectInterface = "auto-detect-interface"
            case dnsHijack = "dns-hijack"
            case inet4Address = "inet4-address"
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case port
        case socksPort = "socks-port"
        case redirPort = "redir-port"
        case mixedPort = "mixed-port"
        case mode
        case logLevel = "log-level"
        case allowLan = "allow-lan"
        case sniffing
        case interfaceName = "interface-name"
        case tun
    }
} 