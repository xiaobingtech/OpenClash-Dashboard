import SwiftUI
import Foundation

struct ConnectionRow: View {
    let connection: ClashConnection
    let viewModel: ConnectionsViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // 第一行：时间信息和关闭按钮
            HStack {
                // 时间信息
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .foregroundColor(.black)
                    Text(connection.formattedStartTime)
                        .foregroundColor(.black)
                    Text("#\(connection.formattedDuration)")
                        .foregroundColor(.black)
                }
                
                Spacer()
                
                // 关闭按钮
                Text(connection.id.prefix(3))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(4)
            }
            .font(.system(size: 13))
            
            // 第二行：主机信息
            HStack(spacing: 4) {
                Image(systemName: "globe")
                    .foregroundColor(.black)
                Text("\(connection.metadata.host.isEmpty ? connection.metadata.destinationIP : connection.metadata.host):\(connection.metadata.destinationPort)")
            }
            .font(.system(size: 16, weight: .medium))
            .foregroundColor(.black)
            
            // 第三行：规则链
            HStack(spacing: 4) {
                Image(systemName: "arrow.triangle.branch")
                    .foregroundColor(.black)
                Text(connection.formattedChains)
            }
            .font(.system(size: 13))
            .foregroundColor(.black)
            
            // 第四行：网络信息和流量
            HStack {
                // 网络类型和源IP信息
                HStack(spacing: 4) {
                    Text("\(connection.metadata.type.uppercased())")
                                            .foregroundColor(.black)
                    Text("\(connection.metadata.network.uppercased())")
                        .foregroundColor(.black)
                    Text("\(connection.metadata.sourceIP):\(connection.metadata.sourcePort)")
                        .foregroundColor(.black)
                }
                
                Spacer()
                
                // 流量信息
                HStack(spacing: 8) {
                    Text(viewModel.formatBytes(connection.download))
                        .foregroundColor(.blue)
                    Text(viewModel.formatBytes(connection.upload))
                        .foregroundColor(.green)
                }
            }
            .font(.system(size: 13))
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle()) // 确保整个区域可点击
        .onTapGesture {
            viewModel.closeConnection(connection.id)
        }
    }
}

#Preview {
    ConnectionRow(
        connection: .preview(),
        viewModel: ConnectionsViewModel()
    )
} 

} 
