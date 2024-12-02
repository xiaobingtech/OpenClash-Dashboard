import SwiftUI

struct LogView: View {
    let server: ClashServer
    @StateObject private var viewModel = LogViewModel()
    @State private var selectedLevel: LogLevel = .info
    
    var body: some View {
        VStack(spacing: 0) {
            // 日志级别选择器
            VStack(spacing: 0) {
                NavigationLink {
                    LogLevelSelectionView(
                        selectedLevel: $selectedLevel,
                        onLevelSelected: { level in
                            viewModel.setLogLevel(level.wsLevel)
                        }
                    )
                } label: {
                    HStack {
                        Label {
                            Text("日志级别")
                                .foregroundColor(.primary)
                        } icon: {
                            Image(systemName: "list.bullet.circle.fill")
                                .foregroundColor(selectedLevel.color)
                        }
                        Spacer()
                        Text(selectedLevel.rawValue)
                            .foregroundColor(.secondary)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(12)
                }
            }
            .padding()
            .background(Color(.systemGroupedBackground))
            
            // 日志列表
            ZStack {
                Color(.systemGroupedBackground)
                    .edgesIgnoringSafeArea(.bottom)
                
                if viewModel.logs.isEmpty && viewModel.isConnected {
                    EmptyStateView(
                        title: "暂无日志",
                        systemImage: "doc.text",
                        description: "正在等待日志..."
                    )
                    .transition(.opacity)
                } else if !viewModel.isConnected {
                    EmptyStateView(
                        title: "连接断开",
                        systemImage: "wifi.slash",
                        description: "正在尝试重新连接..."
                    )
                    .transition(.opacity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(viewModel.logs.reversed()) { log in
                                LogRow(log: log)
                            }
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal)
                    }
                }
            }
            .frame(maxHeight: .infinity)
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
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 头部信息
            HStack(spacing: 8) {
                // 日志类型标签
                HStack(spacing: 4) {
                    Circle()
                        .fill(log.type.color)
                        .frame(width: 8, height: 8)
                    
                    Text(log.type.displayText)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(log.type.color)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(log.type.color.opacity(0.1))
                .cornerRadius(8)
                
                // 时间戳
                Text(Self.timeFormatter.string(from: log.timestamp))
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            
            // 日志内容
            Text(log.payload)
                .font(.system(size: 14, design: .monospaced))
                .foregroundColor(.primary)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.03), radius: 3, x: 0, y: 1)
    }
}

#Preview {
    NavigationView {
        LogView(server: ClashServer(name: "测试服务器", url: "10.1.1.2", port: "9090", secret: "123456"))
    }
} 