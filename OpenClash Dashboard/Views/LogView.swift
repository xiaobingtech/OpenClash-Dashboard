import SwiftUI

struct LogView: View {
    let server: ClashServer
    @StateObject private var viewModel = LogViewModel()
    
    var body: some View {
        List {
            ForEach(viewModel.logs.reversed()) { log in
                LogRow(log: log)
            }
        }
        .listStyle(.plain)
        .overlay {
            if viewModel.logs.isEmpty && viewModel.isConnected {
                ContentUnavailableView(
                    "暂无日志",
                    systemImage: "doc.text",
                    description: Text("正在等待日志...")
                )
            } else if !viewModel.isConnected {
                ContentUnavailableView(
                    "连接断开",
                    systemImage: "wifi.slash",
                    description: Text("正在尝试重新连接...")
                )
            }
        }
        .navigationTitle("日志")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.connect(to: server)
        }
        .onDisappear {
            viewModel.disconnect()
        }
    }
}

struct LogRow: View {
    let log: LogMessage
    
    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm:ss a"
        return formatter
    }()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(log.type.displayText)
                    .font(.caption)
                    .foregroundColor(log.type.color)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(log.type.color.opacity(0.1))
                    .cornerRadius(4)
                
                Text(Self.timeFormatter.string(from: log.timestamp))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text(log.payload)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    LogView(server: ClashServer(name: "测试服务器", url: "10.1.1.2", port: "9090", secret: "123456"))
} 