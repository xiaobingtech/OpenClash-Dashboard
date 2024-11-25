import SwiftUI

struct DNSQueryView: View {
    let server: ClashServer
    @StateObject private var viewModel = DNSQueryViewModel()
    @State private var domainName = ""
    @State private var selectedType = "A"
    
    let queryTypes = ["A", "AAAA", "MX"]
    
    var body: some View {
        Form {
            Section {
                TextField("输入域名", text: $domainName)
                    .autocapitalization(.none)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                
                Picker("记录类型", selection: $selectedType) {
                    ForEach(queryTypes, id: \.self) { type in
                        Text(type).tag(type)
                    }
                }
                
                Button("查询") {
                    viewModel.queryDNS(server: server, domain: domainName, type: selectedType)
                }
                .disabled(domainName.isEmpty)
            } header: {
                Text("DNS 查询")
            } footer: {
                Text("支持查询 A、AAAA 和 MX 记录")
            }
            
            if !viewModel.results.isEmpty {
                Section("查询结果") {
                    ForEach(viewModel.results, id: \.self) { result in
                        Text(result)
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                    }
                }
            }
        }
        .navigationTitle("域名查询")
        .navigationBarTitleDisplayMode(.inline)
    }
} 