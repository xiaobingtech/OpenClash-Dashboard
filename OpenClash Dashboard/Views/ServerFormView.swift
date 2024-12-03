import SwiftUI

struct ServerFormView: View {
    @Binding var name: String
    @Binding var url: String
    @Binding var port: String
    @Binding var secret: String
    @Binding var useSSL: Bool
    
    var body: some View {
        Form {
            Section {
                TextField("服务器名称（可选）", text: $name)
                TextField("服务器地址", text: $url)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                TextField("端口", text: $port)
                    .keyboardType(.numberPad)
                SecureField("密钥", text: $secret)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Toggle("使用 SSL (HTTPS)", isOn: $useSSL)
            } footer: {
                Text("如果你的服务器使用 HTTPS，请开启 SSL")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
} 