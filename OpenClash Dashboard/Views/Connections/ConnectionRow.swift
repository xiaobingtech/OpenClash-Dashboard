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
        
        while speed >= 1000 && unitIndex < units.count - 1 {
            speed /= 1024
            unitIndex += 1
        }
        
        if speed < 0.1 {
            return "0\(units[unitIndex])"
        }
        
        if speed >= 100 {
            return String(format: "%.0f%@", min(speed, 999), units[unitIndex])
        } else if speed >= 10 {
            return String(format: "%.1f%@", speed, units[unitIndex])
        } else {
            return String(format: "%.2f%@", speed, units[unitIndex])
        }
    }
    
    // 添加格式化字节的辅助方法
    private func formatBytes(_ bytes: Int) -> String {
        let units = ["B", "K", "M", "G"]
        var size = Double(bytes)
        var unitIndex = 0
        
        while size >= 1000 && unitIndex < units.count - 1 {
            size /= 1024
            unitIndex += 1
        }
        
        if size < 0.1 {
            return "0\(units[unitIndex])"
        }
        
        if size >= 100 {
            return String(format: "%.0f%@", min(size, 999), units[unitIndex])
        } else if size >= 10 {
            return String(format: "%.1f%@", size, units[unitIndex])
        } else {
            return String(format: "%.2f%@", size, units[unitIndex])
        }
    }
    
    // 修改获取标签的方法
    private func getClientTag(for ip: String) -> String? {
        return tagViewModel.tags.first { $0.ip == ip }?.name
    }
    
    // 修改流量显示组件
    private func TrafficView(bytes: Int, icon: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(color)
                .frame(width: 16)
            Text(formatBytes(bytes))
                .frame(width: 58, alignment: .leading)
                .foregroundColor(color)
                .font(.system(.footnote, design: .monospaced))
                .monospacedDigit()
        }
        .frame(width: 78)
    }
    
    // 优化速度显示组件
    private func SpeedView(download: Double, upload: Double) -> some View {
        HStack(spacing: 12) {
            // 下载速度
            HStack(spacing: 2) {
                Image(systemName: "arrow.down")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.blue)
                    .frame(width: 12)
                Text(formatSpeed(download))
                    .frame(width: 66, alignment: .leading)
                    .monospacedDigit()
            }
            .frame(width: 70)
            
            // 上传速度
            HStack(spacing: 2) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.green)
                    .frame(width: 12)
                Text(formatSpeed(upload))
                    .frame(width: 66, alignment: .leading)
                    .monospacedDigit()
            }
            .frame(width: 70)
        }
        .font(.system(.footnote, design: .monospaced))
        .foregroundColor(.secondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 第一行：时间信息和关闭按钮
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "clock.fill")
                        .foregroundColor(.secondary)
                        .frame(width: 16, height: 16)
                    Text(connection.formattedStartTime)
                        .foregroundColor(.secondary)
                    
                    // 根据连接状态显示不同的信息
                    if connection.isAlive {
                        SpeedView(download: connection.downloadSpeed, upload: connection.uploadSpeed)
                    } else {
                        Text(connection.formattedDuration)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color(.systemGray6))
                            )
                    }
                }
                .font(.footnote)
                
                Spacer()
                
                // 只在连接活跃时显示关闭按钮
                if connection.isAlive {
                    Button(action: {
                        viewModel.closeConnection(connection.id)
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary.opacity(0.5))
                            .frame(width: 20, height: 20)
                    }
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
                
                // 使用修改后的流量显示组件
                HStack(spacing: 16) {
                    TrafficView(
                        bytes: connection.download,
                        icon: "arrow.down.circle.fill",
                        color: .blue
                    )
                    TrafficView(
                        bytes: connection.upload,
                        icon: "arrow.up.circle.fill",
                        color: .green
                    )
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .opacity(connection.isAlive ? 1 : 0.6)
        // 使用字符串作为动画的值，包含所有需要监视的状态
        .animation(
            .smooth(duration: 0.2),
            value: "\(connection.isAlive)_\(connection.download)_\(connection.upload)_\(connection.downloadSpeed)_\(connection.uploadSpeed)"
        )
    }
}

#Preview {
    ConnectionRow(
        connection: .preview(),
        viewModel: ConnectionsViewModel(),
        tagViewModel: ClientTagViewModel()
    )
} 


