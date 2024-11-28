import SwiftUI

struct LogView: View {
    let server: ClashServer
    @StateObject private var viewModel = LogViewModel()
    @State private var selectedLevel: LogLevel = .info
    
    private func EmptyStateView(title: String, systemImage: String, description: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: systemImage)
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            
            Text(description)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 日志级别选择器
            Form {
                Section {
                    NavigationLink {
                        LogLevelSelectionView(
                            selectedLevel: $selectedLevel,
                            onLevelSelected: { level in
                                viewModel.setLogLevel(level.wsLevel)
                            }
                        )
                    } label: {
                        HStack {
                            Text("日志级别")
                            Spacer()
                            Text(selectedLevel.rawValue)
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("日志设置")
                }
            }
            .scrollDisabled(true)
            .frame(height: 80)
            
            // 日志列表
            if viewModel.logs.isEmpty && viewModel.isConnected {
                EmptyStateView(
                    title: "暂无日志",
                    systemImage: "doc.text",
                    description: "正在等待日志..."
                )
            } else if !viewModel.isConnected {
                EmptyStateView(
                    title: "连接断开",
                    systemImage: "wifi.slash",
                    description: "正在尝试重新连接..."
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(viewModel.logs.reversed()) { log in
                            LogRow(log: log)
                                .padding(.horizontal)
                        }
                    }
                }
                .background(Color(.systemGroupedBackground))
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
    NavigationView {
        LogView(server: ClashServer(name: "测试服务器", url: "10.1.1.2", port: "9090", secret: "123456"))
    }
} 