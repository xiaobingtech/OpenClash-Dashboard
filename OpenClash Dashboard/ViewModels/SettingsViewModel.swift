import Foundation

class SettingsViewModel: ObservableObject {
    @Published var config: ClashConfig?
    @Published var mode: String = "rule"
    @Published var logLevel: String = "info"
    @Published var allowLan: Bool = true
    @Published var sniffing: Bool = false
    @Published var tunEnable: Bool = false
    @Published var tunDevice: String = ""
    @Published var tunStack: String = "gVisor"
    @Published var interfaceName: String = ""
    @Published var testUrl: String = "https://www.gstatic.com/"
    @Published var language: String = "zh-CN"
    @Published var tunAutoRoute: Bool = true
    @Published var tunAutoDetectInterface: Bool = true
    
    func fetchConfig(server: ClashServer) {
        guard let url = URL(string: "http://\(server.url):\(server.port)/configs") else { return }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(server.secret)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let data = data else { return }
            
            if let config = try? JSONDecoder().decode(ClashConfig.self, from: data) {
                DispatchQueue.main.async {
                    self?.config = config
                    self?.updateUIFromConfig(config)
                }
            }
        }.resume()
    }
    
    private func updateUIFromConfig(_ config: ClashConfig) {
        self.mode = config.mode
        self.logLevel = config.logLevel
        self.allowLan = config.allowLan
        self.sniffing = config.sniffing
        self.tunEnable = config.tun.enable
        self.tunDevice = config.tun.device
        self.tunStack = config.tun.stack
        self.interfaceName = config.interfaceName
        self.tunAutoRoute = config.tun.autoRoute
        self.tunAutoDetectInterface = config.tun.autoDetectInterface
    }
    
    func updateConfig(_ path: String, value: Any, server: ClashServer) {
        guard let url = URL(string: "http://\(server.url):\(server.port)/configs") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("Bearer \(server.secret)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let payload = [path: value]
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)
        
        URLSession.shared.dataTask(with: request) { [weak self] _, response, error in
            if let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode == 200 {
                // 更新成功
                print("设置更新成功：\(path) = \(value)")
            } else {
                // 处理错误
                print("设置更新失败：\(path) = \(value)")
                if let error = error {
                    print("错误：\(error.localizedDescription)")
                }
            }
        }.resume()
    }
    
    // MARK: - Actions
    func reloadConfig() {
        // 实现重载配置文件的逻辑
    }
    
    func updateGeoDatabase() {
        // 实现更新 GEO 数据库的逻辑
    }
    
    func clearFakeIP() {
        // 实现清空 FakeIP 数据库的逻辑
    }
    
    func restartCore() {
        // 实现重启核心的逻辑
    }
    
    func upgradeCore() {
        // 实现更新核心的逻辑
    }
} 