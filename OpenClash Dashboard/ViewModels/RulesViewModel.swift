import Foundation

class RulesViewModel: ObservableObject {
    @Published var searchText = ""
    @Published var isLoading = true
    @Published var rules: [(type: String, domain: String, proxy: String)] = [
        ("DOMAIN-SUFFIX", "example1.com", "Proxy"),
        ("DOMAIN-SUFFIX", "example2.com", "Direct"),
        ("DOMAIN-KEYWORD", "example3", "Auto"),
        ("IP-CIDR", "192.168.1.0/24", "Direct"),
        ("GEOIP", "CN", "Direct")
    ]
} 