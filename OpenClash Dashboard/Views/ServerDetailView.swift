import SwiftUI
import Charts


struct ServerDetailView: View {
    let server: ClashServer
    @State private var selectedTab = 0
    
    var body: some View {
        NavigationStack {
            TabView(selection: $selectedTab) {
                // 概览标签页
                OverviewTab(server: server)
                    .tabItem {
                        Label("概览", systemImage: "chart.line.uptrend.xyaxis")
                    }
                    .tag(0)
                
                // 代理标签页
                ProxyView(server: server)
                    .tabItem {
                        Label("代理", systemImage: "globe")
                    }
                    .tag(1)
                
                // 规则标签页
                RulesView(server: server)
                    .tabItem {
                        Label("规则", systemImage: "ruler")
                    }
                    .tag(2)
                
                // 连接标签页
                ConnectionsView(server: server)
                    .tabItem {
                        Label("连接", systemImage: "link")
                    }
                    .tag(3)
                
                // 配置标签页
                SettingsView(server: server)
                    .tabItem {
                        Label("配置", systemImage: "gearshape")
                    }
                    .tag(4)
                
                // 日志标签页
                LogView(server: server)
                    .tabItem {
                        Label("日志", systemImage: "doc.text")
                    }
                    .tag(5)
            }
            .navigationTitle(server.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // ToolbarItem(placement: .navigationBarLeading) {
                //     Button {
                //         // 返回操作
                //     } label: {
                //         Image(systemName: "chevron.left")
                //     }
                // }
            }
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color(.systemBackground), for: .navigationBar)
        }
    }
}

// 更新速率图表组件
struct SpeedChartView: View {
    let speedHistory: [SpeedRecord]
    
    // 预设的速度刻度值（单位：字节/秒）
    private let presetSpeeds: [Double] = [
        1_000,      // 1 KB/s
        10_000,     // 10 KB/s
        100_000,    // 100 KB/s
        1_000_000,  // 1 MB/s
        10_000_000, // 10 MB/s
    ]
    
    private var maxValue: Double {
        let maxUpload = speedHistory.map { $0.upload }.max() ?? 0
        let maxDownload = speedHistory.map { $0.download }.max() ?? 0
        let currentMax = max(maxUpload, maxDownload)
        
        // 找到合适的预设最大值
        return presetSpeeds.first { $0 >= currentMax } ?? presetSpeeds.last ?? 10_000_000
    }
    
    private func formatSpeed(_ speed: Double) -> String {
        if speed >= 1_000_000 {
            return String(format: "%.1f MB/s", speed / 1_000_000)
        } else if speed >= 1_000 {
            return String(format: "%.1f KB/s", speed / 1_000)
        } else {
            return String(format: "%.0f B/s", speed)
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                Text("速率图表")
                    .font(.headline)
            }
            
            Chart {
                // 添加预设的网格线和标签
                ForEach(Array(stride(from: 0, to: maxValue, by: maxValue/4)), id: \.self) { value in
                    RuleMark(
                        y: .value("Speed", value)
                    )
                    .lineStyle(StrokeStyle(lineWidth: 1))
                    .foregroundStyle(.gray.opacity(0.1))
                }
                
                // 上传数据
                ForEach(speedHistory) { record in
                    LineMark(
                        x: .value("Time", record.timestamp),
                        y: .value("Speed", record.upload),
                        series: .value("Type", "上传")
                    )
                    .foregroundStyle(.green)
                    .interpolationMethod(.monotone)
                }
                
                ForEach(speedHistory) { record in
                    AreaMark(
                        x: .value("Time", record.timestamp),
                        yStart: .value("Speed", 0),
                        yEnd: .value("Speed", record.upload),
                        series: .value("Type", "上传")
                    )
                    .foregroundStyle(.green.opacity(0.1))
                    .interpolationMethod(.monotone)
                }
                
                // 下载数据
                ForEach(speedHistory) { record in
                    LineMark(
                        x: .value("Time", record.timestamp),
                        y: .value("Speed", record.download),
                        series: .value("Type", "下载")
                    )
                    .foregroundStyle(.blue)
                    .interpolationMethod(.monotone)
                }
                
                ForEach(speedHistory) { record in
                    AreaMark(
                        x: .value("Time", record.timestamp),
                        yStart: .value("Speed", 0),
                        yEnd: .value("Speed", record.download),
                        series: .value("Type", "下载")
                    )
                    .foregroundStyle(.blue.opacity(0.1))
                    .interpolationMethod(.monotone)
                }
            }
            .frame(height: 200)
            .chartYAxis {
                AxisMarks(preset: .extended, position: .leading) { value in
                    if let speed = value.as(Double.self) {
                        AxisGridLine()
                        AxisValueLabel(horizontalSpacing: 0) {
                            Text(formatSpeed(speed))
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.leading, 4)
                        }
                    }
                }
            }
            .chartYScale(domain: 0...maxValue)
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 3))
            }
            
            // 图例
            HStack {
                Label("下载", systemImage: "circle.fill")
                    .foregroundColor(.blue)
                Label("上传", systemImage: "circle.fill")
                    .foregroundColor(.green)
            }
            .font(.caption)
        }
    }
}

// 2. 更新 OverviewTab
struct OverviewTab: View {
    let server: ClashServer
    @StateObject private var monitor = NetworkMonitor()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Color.clear
                    .frame(height: 8)
                // 速度卡片
                HStack(spacing: 16) {
                    StatusCard(
                        title: "下载",
                        value: monitor.downloadSpeed,
                        icon: "arrow.down.circle",
                        color: .blue
                    )
                    StatusCard(
                        title: "上传",
                        value: monitor.uploadSpeed,
                        icon: "arrow.up.circle",
                        color: .green
                    )
                }
                
                // 总流量卡片
                HStack(spacing: 16) {
                    StatusCard(
                        title: "下载总量",
                        value: monitor.totalUpload,
                        icon: "arrow.down.circle.fill",
                        color: .blue
                    )
                    StatusCard(
                        title: "上传总量",
                        value: monitor.totalDownload,
                        icon: "arrow.up.circle.fill",
                        color: .green
                    )
                }
                
                // 状态卡片
                HStack(spacing: 16) {
                    StatusCard(
                        title: "活动连接",
                        value: "\(monitor.activeConnections)",
                        icon: "link.circle.fill",
                        color: .orange
                    )
                    StatusCard(
                        title: "内存使用",
                        value: monitor.memoryUsage,
                        icon: "memorychip",
                        color: .purple
                    )
                }
                
                // 速率图表 - 直接使用 SpeedChartView，不用 ChartCard 包装
                SpeedChartView(speedHistory: monitor.speedHistory)
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
                
                // 内存表
                ChartCard(title: "内存使用", icon: "memorychip") {
                    Chart(monitor.memoryHistory) { record in
                        AreaMark(
                            x: .value("Time", record.timestamp),
                            y: .value("Memory", record.usage)
                        )
                        .foregroundStyle(.purple.opacity(0.3))
                        
                        LineMark(
                            x: .value("Time", record.timestamp),
                            y: .value("Memory", record.usage)
                        )
                        .foregroundStyle(.purple)
                    }
                    .frame(height: 200)
                    .chartYAxis {
                        AxisMarks(position: .leading)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .background(Color(.systemGroupedBackground))
        .onAppear { monitor.startMonitoring(server: server) }
        .onDisappear { monitor.stopMonitoring() }
    }
}

// 添加 UIVisualEffectView 包装器
struct VisualEffectView: UIViewRepresentable {
    let effect: UIVisualEffect
    
    func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView(effect: effect)
    }
    
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = effect
    }
}

// 状态卡片组件
struct StatusCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Text(value)
                .font(.title2)
                .bold()
                .minimumScaleFactor(0.5)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}

// 图表卡片组件
struct ChartCard<Content: View>: View {
    let title: String
    let icon: String
    let content: Content
    
    init(
        title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.icon = icon
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                Text(title)
                    .font(.headline)
            }
            
            content
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}


// 其他标签页视图
// struct ProxyView: View {
//     let server: ClashServer
//     @StateObject private var viewModel = ProxyViewModel()
//    
//     var body: some View {
//         List {
//             Section("全局设置") {
//                 HStack {
//                     Text("模式")
//                     Spacer()
//                     Picker("模式", selection: .constant("Rule")) {
//                         Text("规则").tag("Rule")
//                         Text("全局").tag("Global")
//                         Text("直连").tag("Direct")
//                     }
//                     .pickerStyle(.menu)
//                 }
//             }
//            
//             Section("代理组") {
//                 ForEach(0..<3) { _ in
//                     ProxyGroupRow()
//                 }
//             }
//            
//             Section("节点") {
//                 ForEach(0..<5) { index in
//                     HStack {
//                         Text("节点 \(index + 1)")
//                         Spacer()
//                         Text("\(Int.random(in: 100...500))ms")
//                             .foregroundColor(.secondary)
//                     }
//                 }
//             }
//         }
//     }
// }

struct RulesView: View {
    let server: ClashServer
    @StateObject private var viewModel = RulesViewModel()
    
    var body: some View {
        List {
            ForEach(0..<20) { index in
                VStack(alignment: .leading, spacing: 4) {
                    Text("DOMAIN-SUFFIX")
                        .font(.headline)
                    Text("example\(index).com")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("Proxy")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                .padding(.vertical, 4)
            }
        }
        .searchable(text: .constant(""))
        .overlay {
            if true { // 替换为实际的加载状态
                ProgressView()
            }
        }
    }
}

struct SettingsView: View {
    let server: ClashServer
    @StateObject private var viewModel = SettingsViewModel()
    
    var body: some View {
        Form {
            Section("常规") {
                Toggle("允许局域网", isOn: .constant(true))
                Toggle("IPv6", isOn: .constant(false))
            }
            
            Section("DNS") {
                Toggle("启用", isOn: .constant(true))
                Toggle("IPv6", isOn: .constant(false))
                Toggle("使用系统DNS", isOn: .constant(true))
            }
            
            Section("TUN") {
                Toggle("启用", isOn: .constant(false))
                Toggle("自动路由", isOn: .constant(true))
                Toggle("DNS劫持", isOn: .constant(true))
            }
            
            Section("实验性功能") {
                Toggle("TCP并发", isOn: .constant(false))
                Toggle("UDP并发", isOn: .constant(false))
            }
        }
    }
}

struct LogView: View {
    let server: ClashServer
    @StateObject private var viewModel = LogViewModel()
    
    var body: some View {
        VStack {
            Picker("日志级别", selection: .constant("INFO")) {
                Text("DEBUG").tag("DEBUG")
                Text("INFO").tag("INFO")
                Text("WARNING").tag("WARNING")
                Text("ERROR").tag("ERROR")
            }
            .pickerStyle(.segmented)
            .padding()
            
            List {
                ForEach(0..<20) { index in
                    let type = ["INFO", "WARNING", "ERROR", "DEBUG"][index % 4]
                    LogRow(type: type, message: "这是一条示例日志消息 #\(index)")
                }
            }
        }
    }
}

// 辅助视图组件
struct ProxyGroupRow: View {
    @State private var selectedProxy = "Auto"
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("代理组名称")
                .font(.headline)
            
            Picker("选择代理", selection: $selectedProxy) {
                Text("Auto").tag("Auto")
                Text("香港 01").tag("HK01")
                Text("新加坡 01").tag("SG01")
                Text("日本 01").tag("JP01")
            }
            .pickerStyle(.menu)
        }
        .padding(.vertical, 4)
    }
}

struct LogRow: View {
    let type: String
    let message: String
    
    var typeColor: Color {
        switch type {
        case "INFO": return .primary
        case "WARNING": return .orange
        case "ERROR": return .red
        case "DEBUG": return .secondary
        default: return .primary
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(type)
                .font(.caption)
                .foregroundColor(typeColor)
            Text(message)
                .font(.system(.body, design: .monospaced))
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    NavigationStack {
        ServerDetailView(server: ClashServer(name: "测试服务器", url: "10.1.1.2", port: "9090", secret: "123456"))
    }
} 
