import SwiftUI

struct AddServerView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: ServerViewModel
    
    @State private var name = ""
    @State private var url = ""
    @State private var port = ""
    @State private var secret = ""
    
    var body: some View {
        NavigationStack {
            Form {
                TextField("服务器名称（可选）", text: $name)
                TextField("服务器地址", text: $url)
                TextField("端口", text: $port)
                    .keyboardType(.numberPad)
                TextField("密钥", text: $secret)
            }
            .navigationTitle("添加服务器")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("添加") {
                        let server = ClashServer(
                            name: name,
                            url: url,
                            port: port,
                            secret: secret
                        )
                        viewModel.addServer(server)
                        dismiss()
                    }
                }
            }
        }
    }
} 