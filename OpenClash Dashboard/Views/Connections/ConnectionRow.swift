import SwiftUI
import Foundation

struct ConnectionRow: View {
    let connection: ClashConnection
    let viewModel: ConnectionsViewModel
    @ObservedObject var tagViewModel: ClientTagViewModel
    
    // 添加格式化速度的辅助方法
    private func formatSpeed(_ bytesPerSecond: Double) -> String {
        let units = ["B/s", "KB/s", "MB/s", "GB/s"]
        var speed = bytesPerSecond
        var unitIndex = 0
        
        while speed >= 1024 && unitIndex < units.count - 1 {
            speed /= 1024
            unitIndex += 1
        }
        
        if speed < 0.1 {
            return "0\(units[unitIndex])"
        }
        
        return String(format: "%.1f%@", speed, units[unitIndex])
    }
    
    // 添加格式化字节的辅助方法
    private func formatBytes(_ bytes: Int) -> String {
        let units = ["B", "K", "M", "G"]
        var size = Double(bytes)
        var unitIndex = 0
        
        while size >= 1024 && unitIndex < units.count - 1 {
            size /= 1024
            unitIndex += 1
        }
        
        if size < 0.1 {
            return "0\(units[unitIndex])"
        }
        
        return String(format: "%.1f%@", size, units[unitIndex])
    }
    
    // 修改获取标签的方法
    private func getClientTag(for ip: String) -> String? {
        return tagViewModel.tags.first { $0.ip == ip }?.name
    }
    
    // 添加一个组合显示流量和速度的视图组件
    private func TrafficView(bytes: Int, speed: Double, icon: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 16, height: 16)
            VStack(alignment: .leading, spacing: 1) {
                Text(formatBytes(bytes))
                    .foregroundColor(color)
                    .font(.footnote)
                Text(formatSpeed(speed))
                    .foregroundColor(color.opacity(0.8))
                    .font(.system(size: 10))
            }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 第一行：时间信息和关闭按钮/状态指示器
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "clock.fill")
                        .foregroundColor(.secondary)
                        .frame(width: 16, height: 16)
                    Text(connection.formattedStartTime)
                        .foregroundColor(.secondary)
                    Text("#\(connection.formattedDuration)")
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(4)
                }
                .font(.footnote)
                
                Spacer()
                
                // 根据连接状态显示不同的按钮/指示器
                if connection.isAlive {
                    // 活跃连接显示关闭按钮
                    Button(action: {
                        viewModel.closeConnection(connection.id)
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .frame(width: 20, height: 20)
                    }
                } else {
                    Text("已断开")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(4)
                    // 已关闭连接显示状态指示器
                    // Image(systemName: "circle.slash")
                    //     .foregroundColor(.secondary)
                    //     .frame(width: 20, height: 20)
                }
            }
            
            // 第二行：主机信息
            HStack(spacing: 6) {
                Image(systemName: "globe.americas.fill")
                    .foregroundColor(.accentColor)
                    .frame(width: 16, height: 16)
                Text("\(connection.metadata.host.isEmpty ? connection.metadata.destinationIP : connection.metadata.host):\(connection.metadata.destinationPort)")
                    .foregroundColor(.primary)
            }
            .font(.system(size: 16, weight: .medium))
            
            // 第三行：规则链
            HStack(spacing: 6) {
                Image(systemName: "arrow.triangle.branch")
                    .foregroundColor(.orange)
                    .frame(width: 16, height: 16)
                Text(connection.formattedChains)
                    .foregroundColor(.secondary)
            }
            .font(.callout)
            
            // 第四行：网络信息和流量
            HStack {
                // 网络类型和源IP信息
                HStack(spacing: 6) {
                    Text(connection.metadata.network.uppercased())
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.1))
                        .foregroundColor(.green)
                        .cornerRadius(4)
                    
                    if let tagName = getClientTag(for: connection.metadata.sourceIP) {
                        Text(tagName)
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .cornerRadius(4)
                    } else {
                        Text("\(connection.metadata.sourceIP):\(connection.metadata.sourcePort)")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
                
                Spacer()
                
                // 使用新的流量显示组件
                HStack(spacing: 12) {
                    TrafficView(
                        bytes: connection.download,
                        speed: connection.downloadSpeed,
                        icon: "arrow.down.circle.fill",
                        color: .blue
                    )
                    
                    TrafficView(
                        bytes: connection.upload,
                        speed: connection.uploadSpeed,
                        icon: "arrow.up.circle.fill",
                        color: .green
                    )
                }
            }
            
            // 添加状态指示器
            // if !connection.isAlive {
            //     Text("已断开")
            //         .font(.caption)
            //         .foregroundColor(.secondary)
            //         .padding(.horizontal, 6)
            //         .padding(.vertical, 2)
            //         .background(Color.secondary.opacity(0.1))
            //         .cornerRadius(4)
            // }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .opacity(connection.isAlive ? 1 : 0.6) // 已断开连接显示为半透明
    }
}

#Preview {
    ConnectionRow(
        connection: .preview(),
        viewModel: ConnectionsViewModel(),
        tagViewModel: ClientTagViewModel()
    )
} 


