import Foundation

class SettingsViewModel: ObservableObject {
    @Published var allowLAN = true
    @Published var ipv6 = false
    @Published var dnsEnabled = true
    @Published var dnsIPv6 = false
    @Published var systemDNS = true
    @Published var tunEnabled = false
    @Published var autoRoute = true
    @Published var dnsFallback = true
    @Published var tcpConcurrent = false
    @Published var udpConcurrent = false
} 