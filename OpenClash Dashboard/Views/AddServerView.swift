import SwiftUI

struct AddServerView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: ServerViewModel
    
    @State private var name = ""
    @State private var url = ""
    @State private var port = ""
    @State private var secret = ""
    @State private var useSSL = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("名称（可选）", text: $name)
                    TextField("服务器地址", text: $url)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                    TextField("端口", text: $port)
                        .keyboardType(.numberPad)
                    TextField("密钥", text: $secret)
                        .textInputAutocapitalization(.never)
                    
                    Toggle(isOn: $useSSL) {
                        Label {
                            Text("使用 HTTPS")
                        } icon: {
                            Image(systemName: "lock.fill")
                                .foregroundColor(useSSL ? .green : .secondary)
                        }
                    }
                } header: {
                    Text("服务器信息")
                } footer: {
                    Text("如果服务器启用了 HTTPS，请打开 HTTPS 开关")
                }
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
                            secret: secret,
                            useSSL: useSSL
                        )
                        viewModel.addServer(server)
                        dismiss()
                    }
                    .disabled(url.isEmpty || port.isEmpty || secret.isEmpty)
                }
            }
        }
    }
} 