import SwiftUI
import Foundation

struct ConnectionRow: View {
    let connection: ClashConnection
    let viewModel: ConnectionsViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 第一行：时间信息和关闭按钮
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "clock.fill")
                        .foregroundColor(.secondary)
                        .imageScale(.small)
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
                
                Button(action: {
                    viewModel.closeConnection(connection.id)
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .imageScale(.medium)
                }
            }
            
            // 第二行：主机信息
            HStack(spacing: 6) {
                Image(systemName: "globe.americas.fill")
                    .foregroundColor(.accentColor)
                Text("\(connection.metadata.host.isEmpty ? connection.metadata.destinationIP : connection.metadata.host):\(connection.metadata.destinationPort)")
                    .foregroundColor(.primary)
            }
            .font(.system(size: 16, weight: .medium))
            
            // 第三行：规则链
            HStack(spacing: 6) {
                Image(systemName: "arrow.triangle.branch")
                    .foregroundColor(.orange)
                    .imageScale(.small)
                Text(connection.formattedChains)
                    .foregroundColor(.secondary)
            }
            .font(.callout)
            
            // 第四行：网络信息和流量
            HStack {
                // 网络类型和源IP信息
                HStack(spacing: 6) {
                    Text(connection.metadata.type.uppercased())
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(4)
                    
                    Text(connection.metadata.network.uppercased())
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.1))
                        .foregroundColor(.green)
                        .cornerRadius(4)
                    
                    Text("\(connection.metadata.sourceIP):\(connection.metadata.sourcePort)")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
                
                Spacer()
                
                // 流量信息
                HStack(spacing: 8) {
                    HStack(spacing: 2) {
                        Image(systemName: "arrow.down.circle.fill")
                            .foregroundColor(.blue)
                        Text(viewModel.formatBytes(connection.download))
                            .foregroundColor(.blue)
                    }
                    HStack(spacing: 2) {
                        Image(systemName: "arrow.up.circle.fill")
                            .foregroundColor(.green)
                        Text(viewModel.formatBytes(connection.upload))
                            .foregroundColor(.green)
                    }
                }
                .font(.footnote)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }
}

#Preview {
    ConnectionRow(
        connection: .preview(),
        viewModel: ConnectionsViewModel()
    )
} 


