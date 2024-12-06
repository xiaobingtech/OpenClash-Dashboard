struct ClashConfig: Codable {
    let port: Int
    let socksPort: Int
    let redirPort: Int
    let mixedPort: Int
    let tproxyPort: Int
    let mode: String
    let logLevel: String
    let allowLan: Bool
    let sniffing: Bool?
    let interfaceName: String?
    let tun: TunConfig?
    let tuicServer: TuicServer?
    
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
    
    struct TuicServer: Codable {
        let enable: Bool
    }
    
    enum CodingKeys: String, CodingKey {
        case port
        case socksPort = "socks-port"
        case redirPort = "redir-port"
        case mixedPort = "mixed-port"
        case tproxyPort = "tproxy-port"
        case mode
        case logLevel = "log-level"
        case allowLan = "allow-lan"
        case sniffing
        case interfaceName = "interface-name"
        case tun
        case tuicServer = "tuic-server"
    }
    
    var isMetaServer: Bool {
        return tuicServer != nil
    }
} 