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
                        // 代理组列表
                        LazyVStack(spacing: 12) {
                            ForEach(viewModel.groups.sorted(by: { $0.name < $1.name }), id: \.name) { group in
                                ProxyGroupCard(
                                    name: group.name,
                                    type: group.type,
                                    count: group.all.count,
                                    selectedNode: group.now,
                                    nodes: sortNodes(group.all, viewModel.nodes, groupName: group.name),
                                    viewModel: viewModel
                                )
                                .id(group.name)
                            }
                        }
                        .padding(.horizontal)
                        
                        // 代理提供者列表
                        if !viewModel.providers.isEmpty {
                            Text("Proxy Providers (\(viewModel.providers.count))")
                                .font(.headline)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal)
                            
                            LazyVStack(spacing: 12) {
                                ForEach(viewModel.providers.sorted(by: { $0.name < $1.name })) { provider in
                                    if let nodes = viewModel.providerNodes[provider.name] {
                                        ProxyProviderCard(provider: provider, nodes: nodes, viewModel: viewModel)
                                            .id("\(provider.name)-\(provider.updatedAt ?? "")-\(viewModel.lastUpdated.timeIntervalSince1970)")
                                    }
                                }
                            }
                            .padding(.horizontal)
                        } else {
                            Text("No proxy providers available")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding()
                        }
                    }
                }
                .padding(.top)
                .padding(.bottom, 80)
            }
            .refreshable {
                print("开始下拉刷新")
                withAnimation {
                    isRefreshing = true
                }
                await viewModel.fetchProxies()
                print("下拉刷新完成")
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
                                                proxy.scrollTo("\(provider.name)-\(provider.updatedAt ?? "")-\(viewModel.lastUpdated.timeIntervalSince1970)", anchor: .top)
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
                        await MainActor.run {
                            withAnimation {
                                isRefreshing = true
                            }
                        }
                        await viewModel.fetchProxies()
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
    private func sortNodes(_ nodeNames: [String], _ allNodes: [ProxyNode], groupName: String) -> [ProxyNode] {
        let specialNodes = ["DIRECT", "REJECT"]
        let matchedNodes = nodeNames.compactMap { name in
            if specialNodes.contains(name) {
                // 先尝试从现有节点中查找
                if let existingNode = allNodes.first(where: { $0.name == name }) {
                    return existingNode
                }
                // 如果找不到，再创建新的节点
                return ProxyNode(
                    id: UUID().uuidString,
                    name: name,
                    type: "Special",
                    alive: true,
                    delay: 0,  // 初始延迟为0
                    history: []
                )
            }
            // 确保所有节点都被包含
            return allNodes.first { $0.name == name }
        }
        
        // 自定义排序逻辑
        return matchedNodes.sorted { node1, node2 in
            // 1. DIRECT 永远在最前
            if node1.name == "DIRECT" { return true }
            if node2.name == "DIRECT" { return false }
            
            // 2. REJECT 在 DIRECT 之后，其他节点之前
            if node1.name == "REJECT" { return true }
            if node2.name == "REJECT" { return false }
            
            // 3. 如果节点名称与组名相同，放在 DIRECT/REJECT 之后，其他节点之前
            if node1.name == groupName { return true }
            if node2.name == groupName { return false }
            
            // 4. 其他节点按字母顺序排序
            return node1.name < node2.name
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
    @State private var isGlowing = false
    
    // 网格布局配置
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 15)
    private let dotSize: CGFloat = 12
    
    private func isSpecialNode(_ name: String) -> Bool {
        return false
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
                        // 添加测试状态
                        for node in nodes {
                            viewModel.testingNodes.insert(node.id)
                        }
                        
                        await viewModel.testGroupSpeed(groupName: name)
                        
                        // 清除测试状态
                        for node in nodes {
                            viewModel.testingNodes.remove(node.id)
                        }
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
                                // 确保动画继续运行
                                withAnimation {
                                    isGlowing = true
                                }
                            }
                        } label: {
                            ZStack {
                                if selectedNode == node.name {
                                    // 外圈发光效果
                                    Circle()
                                        .fill(status.color.opacity(0.2))
                                        .frame(width: dotSize + 8, height: dotSize + 8)
                                        .shadow(color: status.color.opacity(0.5), radius: isGlowing ? 6 : 2, x: 0, y: 0)
                                    
                                    // 内圈边框
                                    Circle()
                                        .stroke(status.color, lineWidth: 2)
                                        .frame(width: dotSize, height: dotSize)
                                    
                                    // 内部填充
                                    Circle()
                                        .fill(status.color)
                                        .frame(width: dotSize - 4, height: dotSize - 4)
                                        .scaleEffect(isGlowing ? 0.8 : 1)
                                } else {
                                    Circle()
                                        .fill(status.color)
                                        .frame(width: dotSize, height: dotSize)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                // 将动画移到这里��确保它持续运行
                .onChange(of: selectedNode) { newValue in
                    withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                        isGlowing = true
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
                                        Text(node.type)
                                            .font(.system(size: 12))
                                            .foregroundStyle(.blue.opacity(0.8))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(.blue.opacity(0.1))
                                            .clipShape(RoundedRectangle(cornerRadius: 4))
                                        
                                        Spacer()
                                        
                                        if node.name == "REJECT" {
                                            Text("阻断")
                                                .font(.system(size: 12))
                                                .foregroundStyle(.red)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(.red.opacity(0.1))
                                                .clipShape(RoundedRectangle(cornerRadius: 4))
                                        } else if node.name == "DIRECT" {
                                            if viewModel.testingNodes.contains(node.id) {
                                                ProgressView()
                                                    .scaleEffect(0.6)
                                                    .frame(width: 30)
                                            } else if node.delay > 0 {
                                                Text("\(node.delay) ms")
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
                                        } else if node.delay > 0 {
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
        .onAppear {
            withAnimation {
                isGlowing = true
            }
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
    @State private var isUpdating = false
    @State private var lastUpdatedTime: String = ""
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
                
                // 只在有订阅信息时显示流量信息
                if let info = provider.subscriptionInfo {
                    Text("\(formatBytes(info.upload + info.download)) / \(formatBytes(info.total))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Button {
                    Task {
                        withAnimation {
                            isUpdating = true
                        }
                        await viewModel.updateProxyProvider(providerName: provider.name)
                        withAnimation {
                            isUpdating = false
                        }
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .rotationEffect(.degrees(isUpdating ? 360 : 0))
                        .animation(isUpdating ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: isUpdating)
                }
                .disabled(isUpdating)
                
                Button {
                    Task {
                        await viewModel.healthCheckProvider(providerName: provider.name)
                    }
                } label: {
                    Image(systemName: "bolt")
                }
                .disabled(isUpdating)
                
                Button {
                    withAnimation {
                        isExpanded.toggle()
                    }
                } label: {
                    Image(systemName: "chevron.down")
                        .rotationEffect(isExpanded ? .degrees(180) : .degrees(0))
                }
            }
            
            // 只在有订阅信息时显示到期时间
            if let info = provider.subscriptionInfo,
               let expire = formatExpireDate(info.expire) {
                Text("到期时间: \(expire)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            if isExpanded {
                Divider()
                
                // 显示节点列表
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(nodes) { node in
                        HStack {
                            Circle()
                                .fill(getNodeStatusColor(delay: node.delay))
                                .frame(width: 8, height: 8)
                            
                            Text(node.name)
                                .font(.subheadline)
                            
                            Spacer()
                            
                            Button {
                                Task {
                                    await viewModel.healthCheckProviderProxy(
                                        providerName: provider.name,
                                        proxyName: node.name
                                    )
                                }
                            } label: {
                                Group {
                                    if viewModel.testingNodes.contains(node.name) {
                                        ProgressView()
                                            .scaleEffect(0.7)
                                    } else if node.delay > 0 {
                                        Text("\(node.delay) ms")
                                            .font(.caption)
                                            .foregroundStyle(getDelayTextColor(delay: node.delay))
                                    } else {
                                        Text("超时")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(node.delay > 0 ? getDelayTextColor(delay: node.delay).opacity(0.1) : Color.secondary.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                        .padding(.vertical, 4)
                        .id("\(node.name)-\(node.delay)-\(viewModel.testingNodes.contains(node.name))")
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
        .id("\(provider.name)")
        .onChange(of: provider.updatedAt) { newValue in
            if let updatedAt = newValue {
                lastUpdatedTime = formatDate(updatedAt)
            }
        }
        .onAppear {
            if let updatedAt = provider.updatedAt {
                lastUpdatedTime = formatDate(updatedAt)
            }
        }
    }
    
    private func getNodeStatusColor(delay: Int) -> Color {
        if delay == 0 {
            return .gray
        } else if delay < 200 {
            return .green
        } else if delay < 400 {
            return .yellow
        } else {
            return .orange
        }
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
        // 将 ISO 8601 格式字符串转��为 Date
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
            return "\(minutes) 钟前"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours) 小时前"
        } else if interval < 2592000 {
            let days = Int(interval / 86400)
            return "\(days) 天前"
        } else {
            // 过30天显示具体日期
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