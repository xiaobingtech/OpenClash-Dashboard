import SwiftUI

struct ProxyView: View {
    let server: ClashServer
    @StateObject private var viewModel: ProxyViewModel
    @State private var showingJumpMenu = false
    @Namespace private var scrollSpace
    @State private var isRefreshing = false
    
    init(server: ClashServer) {
        self.server = server
        self._viewModel = StateObject(wrappedValue: ProxyViewModel(server: server))
    }
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 16) {
                    if viewModel.groups.isEmpty {
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding(.top, 100)
                    } else {
                        Text("Proxy Groups")
                                .font(.headline)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal)
                        // 代理组列表
                        LazyVStack(spacing: 12) {
                            ForEach(viewModel.groups, id: \.name) { group in
                                ProxyGroupCard(
                                    name: group.name,
                                    type: group.type,
                                    count: group.all.count,
                                    selectedNode: group.now,
                                    nodes: sortNodes(group.all, viewModel.nodes),
                                    viewModel: viewModel
                                )
                                .id(group.name)
                            }
                        }
                        .padding(.horizontal)
                        
                        // 代理提供者列表
                        if !viewModel.providers.filter({ $0.subscriptionInfo != nil }).isEmpty {
                            Text("Proxy Providers")
                                .font(.headline)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal)
                            
                            LazyVStack(spacing: 12) {
                                ForEach(viewModel.providers.filter { $0.subscriptionInfo != nil }) { provider in
                                    if let nodes = viewModel.providerNodes[provider.name] {
                                        ProxyProviderCard(provider: provider, nodes: nodes, viewModel: viewModel)
                                            .id(provider.name)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.bottom, 80)
            }
            .refreshable {
                print("开始下拉刷新")
                // 开始刷新动画
                withAnimation {
                    isRefreshing = true
                }
                
                // 刷新代理数据
                await viewModel.fetchProxies()
                print("下拉刷新完成")
                
                // 结束刷新动画
                withAnimation {
                    isRefreshing = false
                }
            }
            .overlay(alignment: .bottomTrailing) {
                Button {
                    showingJumpMenu = true
                } label: {
                    Image(systemName: "arrow.down.forward.square.fill")
                        .font(.system(size: 25))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.white)
                        .frame(width: 50, height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(.blue.gradient)
                                .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                        )
                }
                .padding(.trailing, 15)
                .padding(.bottom, 15)
                .popover(isPresented: $showingJumpMenu) {
                    NavigationStack {
                        List {
                            Section("Proxy Groups") {
                                ForEach(viewModel.groups, id: \.name) { group in
                                    Button {
                                        showingJumpMenu = false
                                        withAnimation {
                                            proxy.scrollTo(group.name, anchor: .top)
                                        }
                                    } label: {
                                        HStack {
                                            Text(group.name)
                                            Spacer()
                                            Image(systemName: "bookmark.fill")
                                                .foregroundColor(.blue)
                                        }
                                    }
                                }
                            }
                            
                            if !viewModel.providers.filter({ $0.subscriptionInfo != nil }).isEmpty {
                                Section("Proxy Providers") {
                                    ForEach(viewModel.providers.filter { $0.subscriptionInfo != nil }) { provider in
                                        Button {
                                            showingJumpMenu = false
                                            withAnimation {
                                                proxy.scrollTo(provider.name, anchor: .top)
                                            }
                                        } label: {
                                            HStack {
                                                Text(provider.name)
                                                Spacer()
                                                Image(systemName: "link")
                                                    .foregroundColor(.blue)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .navigationTitle("To Section")
                        .navigationBarTitleDisplayMode(.inline)
                    }
                    .presentationDetents([.medium])
                }
            }
        }
        .navigationTitle(server.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    Task {
                        // 开始刷新动画
                        await MainActor.run {
                            withAnimation {
                                isRefreshing = true
                            }
                        }
                        
                        // 只刷新代理数据，不进行延迟测试
                        await viewModel.fetchProxies()
                        
                        // 结束刷新动画
                        await MainActor.run {
                            withAnimation {
                                isRefreshing = false
                            }
                        }
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .rotationEffect(.degrees(isRefreshing ? 360 : 0))
                        .animation(isRefreshing ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: isRefreshing)
                }
                .disabled(isRefreshing)
            }
        }
        .task {
            await viewModel.fetchProxies()
        }
    }
    
    // 添加节点排序方法
    private func sortNodes(_ nodeNames: [String], _ allNodes: [ProxyNode]) -> [ProxyNode] {
        let specialNodes = ["DIRECT", "REJECT", "PROXY"]
        
        // 先找出所有匹配的节点
        let matchedNodes = nodeNames.compactMap { name in
            allNodes.first { $0.name == name }
        }
        
        // 然后按规则排序
        return matchedNodes.sorted { node1, node2 in
            let isSpecial1 = specialNodes.contains(node1.name)
            let isSpecial2 = specialNodes.contains(node2.name)
            
            if isSpecial1 && isSpecial2 {
                // 如果都是特殊节点，按照 specialNodes 数组的顺序排序
                return specialNodes.firstIndex(of: node1.name)! < specialNodes.firstIndex(of: node2.name)!
            } else if isSpecial1 {
                // 特殊节点排在前面
                return true
            } else if isSpecial2 {
                return false
            } else {
                // 普通节点按名称排序（区分大小写）
                return node1.name.localizedStandardCompare(node2.name) == .orderedAscending
            }
        }
    }
}

struct ProxyGroupCard: View {
    let name: String
    let type: String
    let count: Int
    let selectedNode: String
    let nodes: [ProxyNode]
    @ObservedObject var viewModel: ProxyViewModel
    @State private var isExpanded = false
    
    // 网格布局配置
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 15)
    private let dotSize: CGFloat = 12
    
    private func isSpecialNode(_ name: String) -> Bool {
        ["DIRECT", "REJECT", "PROXY"].contains(name)
    }
    
    private func getNodeBackground(_ node: ProxyNode) -> Color {
        if isSpecialNode(node.name) {
            return Color(.systemBackground)
        }
        return Color(.secondarySystemGroupedBackground)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题栏
            HStack {
                Text(name)
                    .font(.headline)
                
                Text(type)
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.secondary.opacity(0.2))
                    .clipShape(Capsule())
                
                Text("\(count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                // 测速按钮
                Button {
                    Task {
                        await viewModel.testGroupDelay(groupName: name, nodes: nodes)
                    }
                } label: {
                    Image(systemName: "bolt")
                }
                .disabled(nodes.contains(where: { viewModel.testingNodes.contains($0.id) }))
                
                Button {
                    withAnimation {
                        isExpanded.toggle()
                    }
                } label: {
                    Image(systemName: "chevron.down")
                        .rotationEffect(isExpanded ? .degrees(180) : .degrees(0))
                }
            }
            
            // 节点状态网格
            if !isExpanded {
                LazyVGrid(columns: columns, spacing: 4) {
                    ForEach(Array(nodes.enumerated()), id: \.element.id) { _, node in
                        let status = getProxyStatus(delay: node.delay)
                        Button {
                            withAnimation {
                                isExpanded = false
                            }
                            Task {
                                await viewModel.selectProxy(groupName: name, proxyName: node.name)
                            }
                        } label: {
                            ZStack {
                                if selectedNode == node.name {
                                    // 选中状态：白色填充 + 彩色边框
                                    Circle()
                                        .stroke(status.color, lineWidth: 2)
                                        .frame(width: dotSize, height: dotSize)
                                    Circle()
                                        .fill(.white)
                                        .frame(width: dotSize - 4, height: dotSize - 4)
                                } else {
                                    // 未选中状态：纯色填充
                                    Circle()
                                        .fill(status.color)
                                        .frame(width: dotSize, height: dotSize)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            
            // 展开后的详细列表
            if isExpanded {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        ForEach(nodes) { node in
                            Button {
                                Task {
                                    await viewModel.selectProxy(groupName: name, proxyName: node.name)
                                }
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 4) {
                                        Text(node.name)
                                            .font(.system(size: 14))
                                            .foregroundStyle(.primary)
                                            .lineLimit(1)
                                        
                                        Spacer()
                                        
                                        if selectedNode == node.name {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 12))
                                                .foregroundStyle(.blue)
                                        }
                                    }
                                    
                                    HStack(spacing: 6) {
                                        if !isSpecialNode(node.name) {
                                            Text(node.type)
                                                .font(.system(size: 12))
                                                .foregroundStyle(.blue.opacity(0.8))
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(.blue.opacity(0.1))
                                                .clipShape(RoundedRectangle(cornerRadius: 4))
                                            
                                            Spacer()
                                            
                                            if node.delay > 0 {
                                                HStack {
                                                    if viewModel.testingNodes.contains(node.id) {
                                                        ProgressView()
                                                            .scaleEffect(0.7)
                                                    } else {
                                                        Text("\(node.delay) ms")
                                                    }
                                                }
                                                .font(.system(size: 12))
                                                .foregroundStyle(getDelayTextColor(delay: node.delay))
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(getDelayTextColor(delay: node.delay).opacity(0.1))
                                                .clipShape(RoundedRectangle(cornerRadius: 4))
                                            } else {
                                                Text("超时")
                                                    .font(.system(size: 12))
                                                    .foregroundStyle(.secondary)
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 2)
                                                    .background(Color.secondary.opacity(0.1))
                                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                                            }
                                        } else {
                                            Color.clear
                                                .frame(height: 24)
                                        }
                                    }
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(getNodeBackground(node))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color.secondary.opacity(0.1), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(maxHeight: 350)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
        .onChange(of: selectedNode) { newValue in
            print("节点选择变化 - 组：\(name), 新节点：\(newValue)")
        }
    }
    
    private func getProxyStatus(delay: Int) -> ProxyStatus {
        if delay == 0 {
            return .timeout
        } else if delay < 200 {
            return .good
        } else if delay < 500 {
            return .medium
        } else {
            return .poor
        }
    }
    
    private func getDelayTextColor(delay: Int) -> Color {
        if delay < 200 {
            return .green
        } else if delay < 400 {
            return .yellow
        } else {
            return .orange
        }
    }
}

enum ProxyStatus {
    case good
    case medium
    case poor
    case timeout
    
    var color: Color {
        switch self {
        case .good:
            return .green
        case .medium:
            return .yellow
        case .poor:
            return .orange
        case .timeout:
            return .gray
        }
    }
}

struct ProxyProviderCard: View {
    let provider: Provider
    let nodes: [ProxyNode]
    @State private var isExpanded = false
    @ObservedObject var viewModel: ProxyViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 标题栏
            HStack {
                Text(provider.name)
                    .font(.headline)
                
                Text(provider.vehicleType)
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.secondary.opacity(0.2))
                    .clipShape(Capsule())
                
                Spacer()
                
                if let info = provider.subscriptionInfo {
                    Text("\(formatBytes(info.upload + info.download)) / \(formatBytes(info.total))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Button {
                    // 更新操作
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                
                Button {
                    // 测速操作
                } label: {
                    Image(systemName: "bolt")
                }
                
                Button {
                    withAnimation {
                        isExpanded.toggle()
                    }
                } label: {
                    Image(systemName: "chevron.down")
                        .rotationEffect(isExpanded ? .degrees(180) : .degrees(0))
                }
            }
            HStack {
                if let info = provider.subscriptionInfo,
                   let expire = formatExpireDate(info.expire) {
                    Text("到期时间: \(expire)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                if let updatedAt = provider.updatedAt {
                    Text("更新时间: \(formatDate(updatedAt))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            if isExpanded {
                Divider()
                
                
                // 显示节点列表
                VStack(alignment: .leading, spacing: 8) {
                    // Text("节点列表")
                    //     .font(.caption)
                    //     .foregroundStyle(.secondary)
                    //     .padding(.top, 4)
                    
                    ForEach(nodes) { node in
                        HStack {
                            Circle()
                                .fill(node.delay > 0 ? .green : .gray)
                                .frame(width: 8, height: 8)
                            
                            Text(node.name)
                                .font(.subheadline)
                            
                            Spacer()
                            
                            if node.delay > 0 {
                                Text("\(node.delay) ms")
                                    .font(.caption)
                                    .foregroundStyle(getDelayTextColor(delay: node.delay))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(getDelayTextColor(delay: node.delay).opacity(0.1))
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                            } else {
                                Text("超时")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.secondary.opacity(0.1))
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        return formatter.string(fromByteCount: bytes)
    }
    
    private func formatExpireDate(_ timestamp: Int64) -> String? {
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    private func formatDate(_ dateString: String) -> String {
        // 将 ISO 8601 格式字符串转换为 Date
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        guard let date = formatter.date(from: dateString) else {
            return "未知时间"
        }
        
        // 计算时间差
        let now = Date()
        let interval = now.timeIntervalSince(date)
        
        // 根据时间差返回不同的格式
        if interval < 60 {
            return "刚刚"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes) 分钟前"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours) 小时前"
        } else if interval < 2592000 {
            let days = Int(interval / 86400)
            return "\(days) 天前"
        } else {
            // 超过30天显示具体日期
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            dateFormatter.timeStyle = .short
            dateFormatter.locale = Locale(identifier: "zh_CN")
            return dateFormatter.string(from: date)
        }
    }
    
    private func getDelayTextColor(delay: Int) -> Color {
        if delay < 200 {
            return .green
        } else if delay < 400 {
            return .yellow
        } else {
            return .orange
        }
    }
}

#Preview {
    NavigationStack {
        ProxyView(server: ClashServer(name: "测试服务器", url: "10.1.1.2", port: "9090", secret: "123456"))
    }
} 
