import SwiftUI

struct EditServerView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: ServerViewModel
    let server: ClashServer
    
    @State private var name: String
    @State private var url: String
    @State private var port: String
    @State private var secret: String
    @State private var useSSL: Bool
    
    init(viewModel: ServerViewModel, server: ClashServer) {
        self.viewModel = viewModel
        self.server = server
        self._name = State(initialValue: server.name)
        self._url = State(initialValue: server.url)
        self._port = State(initialValue: server.port)
        self._secret = State(initialValue: server.secret)
        self._useSSL = State(initialValue: server.useSSL)
    }
    
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
            .navigationTitle("编辑服务器")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        let updatedServer = ClashServer(
                            id: server.id,
                            name: name,
                            url: url,
                            port: port,
                            secret: secret,
                            status: server.status,
                            version: server.version,
                            useSSL: useSSL
                        )
                        viewModel.updateServer(updatedServer)
                        dismiss()
                    }
                    .disabled(url.isEmpty || port.isEmpty || secret.isEmpty)
                }
            }
        }
    }
} 