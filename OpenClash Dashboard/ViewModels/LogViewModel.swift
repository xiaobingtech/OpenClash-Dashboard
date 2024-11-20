import Foundation

class LogViewModel: ObservableObject {
    @Published var logLevel = "INFO"
    @Published var logs: [(type: String, message: String)] = [
        ("INFO", "系统启动"),
        ("WARNING", "配置文件未找到"),
        ("ERROR", "连接失败"),
        ("DEBUG", "正在解析域名"),
        ("INFO", "代理切换成功")
    ]
    
    func clearLogs() {
        logs.removeAll()
    }
    
    func addLog(_ type: String, _ message: String) {
        logs.insert((type, message), at: 0)
        if logs.count > 100 {
            logs.removeLast()
        }
    }
} 