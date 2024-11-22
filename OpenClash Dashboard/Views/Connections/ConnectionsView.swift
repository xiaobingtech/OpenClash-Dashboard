import SwiftUI

struct ConnectionsView: View {
    let server: ClashServer
    @StateObject private var viewModel = ConnectionsViewModel()
    @State private var searchText = ""
    @State private var selectedProtocols: Set<String> = ["TCP", "UDP"]
    @State private var showClosed = true
    
    // 添加定时器状态
    @State private var timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    // 添加连接状态属性
    @State private var isConnecting = false
    
    private var filteredConnections: [ClashConnection] {
        viewModel.connections.filter { connection in
            // 协议过滤
            guard selectedProtocols.contains(connection.metadata.network.uppercased()) else {
                return false
            }
            
            // 已断开连接过滤
            if !showClosed && !connection.isAlive {
                return false
            }
            
            // 搜索过滤
            if !searchText.isEmpty {
                let searchContent = [
                    connection.metadata.host,
                    connection.metadata.destinationIP,
                    connection.metadata.sourceIP,
                    connection.chains.joined(separator: " ")
                ].joined(separator: " ").lowercased()
                
                guard searchContent.contains(searchText.lowercased()) else {
                    return false
                }
            }
            
            return true
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 连接状态栏
            HStack {
                // 状态信息
                Image(systemName: viewModel.connectionState.statusIcon)
                    .foregroundColor(viewModel.connectionState.statusColor)
                    .rotationEffect(viewModel.connectionState.isConnecting ? .degrees(360) : .degrees(0))
                    .animation(viewModel.connectionState.isConnecting ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: viewModel.connectionState)
                
                Text(viewModel.connectionState.message)
                    .font(.footnote)
                
                if viewModel.connectionState.isConnecting {
                    ProgressView()
                        .scaleEffect(0.8)
                }
                
                Spacer()
                
                // 流量统计
                HStack(spacing: 12) {
                    Label(viewModel.formatBytes(viewModel.totalDownload), systemImage: "arrow.down.circle.fill")
                        .foregroundColor(.blue)
                    Label(viewModel.formatBytes(viewModel.totalUpload), systemImage: "arrow.up.circle.fill")
                        .foregroundColor(.green)
                }
                .font(.footnote)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(viewModel.connectionState.statusColor.opacity(0.1))
            
            // 过滤标签栏
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    // TCP 标签
                    FilterTag(
                        title: "TCP",
                        count: viewModel.connections.filter { $0.metadata.network.uppercased() == "TCP" }.count,
                        isSelected: selectedProtocols.contains("TCP")
                    ) {
                        if selectedProtocols.contains("TCP") {
                            selectedProtocols.remove("TCP")
                        } else {
                            selectedProtocols.insert("TCP")
                        }
                    }
                    
                    // UDP 标签
                    FilterTag(
                        title: "UDP",
                        count: viewModel.connections.filter { $0.metadata.network.uppercased() == "UDP" }.count,
                        isSelected: selectedProtocols.contains("UDP")
                    ) {
                        if selectedProtocols.contains("UDP") {
                            selectedProtocols.remove("UDP")
                        } else {
                            selectedProtocols.insert("UDP")
                        }
                    }
                    
                    // 已断开连接标签
                    FilterTag(
                        title: "已断开",
                        count: viewModel.connections.filter { !$0.isAlive }.count,
                        isSelected: showClosed
                    ) {
                        showClosed.toggle()
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
            
            // 连接列表
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(filteredConnections) { connection in
                        ConnectionRow(connection: connection, viewModel: viewModel)
                    }
                }
                .animation(.default, value: filteredConnections)
            }
            .listStyle(.plain)
            .background(Color(.systemGroupedBackground))
            .overlay {
                if filteredConnections.isEmpty && viewModel.connectionState == .connected {
                    ContentUnavailableView(
                        label: {
                            Label("没有连接", systemImage: "network.slash")
                        },
                        description: {
                            if !searchText.isEmpty {
                                Text("没有找到匹配的连接")
                            } else {
                                Text("当前没有活动的连接")
                            }
                        }
                    )
                }
            }
        }
        .searchable(text: $searchText, prompt: "搜索连接")
        .refreshable {
            await viewModel.refresh()
        }
        .onAppear {
            viewModel.startMonitoring(server: server)
        }
        .onDisappear {
            viewModel.stopMonitoring()
            timer.upstream.connect().cancel()
        }
    }
}

// 过滤标签组件
struct FilterTag: View {
    let title: String
    let count: Int
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(title)
                Text("\(count)")
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        isSelected ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.2)
                    )
                    .cornerRadius(8)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                isSelected ? Color.accentColor.opacity(0.1) : Color.clear
            )
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        ConnectionsView(
            server: ClashServer(
                name: "测试服务器",
                url: "10.1.1.2",
                port: "9090",
                secret: "123456"
            )
        )
    }
} 
