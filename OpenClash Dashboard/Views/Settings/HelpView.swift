import SwiftUI

struct HelpView: View {
    var body: some View {
        List {
            Section("基本使用") {
                VStack(alignment: .leading, spacing: 10) {
                    Text("1. 添加服务器")
                        .font(.headline)
                    Text("点击右上角的+号添加新的服务器配置。需要填写服务器地址、端口和密钥（如果有）。")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("2. 检查服务器状态")
                        .font(.headline)
                    Text("服务器列表会显示每个服务器的连接状态。绿色表示正常，黄色表示未授权，红色表示错误。")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("3. 管理服务器")
                        .font(.headline)
                    Text("长按服务器项目可以进行编辑或删除操作。下拉列表可以刷新所有服务器状态。")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            }
        }
        .navigationTitle("使用帮助")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        HelpView()
    }
} 
