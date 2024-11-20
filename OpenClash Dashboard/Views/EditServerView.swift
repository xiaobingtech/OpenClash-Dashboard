import SwiftUI

struct EditServerView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: ServerViewModel
    let server: ClashServer
    
    @State private var name: String
    @State private var url: String
    @State private var port: String
    @State private var secret: String
    
    init(viewModel: ServerViewModel, server: ClashServer) {
        self.viewModel = viewModel
        self.server = server
        self._name = State(initialValue: server.name)
        self._url = State(initialValue: server.url)
        self._port = State(initialValue: server.port)
        self._secret = State(initialValue: server.secret)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                TextField("服务器名称（可选）", text: $name)
                TextField("服务器地址", text: $url)
                TextField("端口", text: $port)
                    .keyboardType(.numberPad)
                TextField("密钥", text: $secret)
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
                            secret: secret
                        )
                        viewModel.updateServer(updatedServer)
                        dismiss()
                    }
                }
            }
        }
    }
} 