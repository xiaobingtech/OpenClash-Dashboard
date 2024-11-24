import SwiftUI

struct RulesView: View {
    let server: ClashServer
    @StateObject private var viewModel: RulesViewModel
    @State private var selectedTab = RuleTab.rules
    
    init(server: ClashServer) {
        self.server = server
        _viewModel = StateObject(wrappedValue: RulesViewModel(server: server))
    }
    
    enum RuleTab {
        case rules
        case providers
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Picker("规则类型", selection: $selectedTab) {
                Text("规则")
                    .tag(RuleTab.rules)
                Text("规则提供者")
                    .tag(RuleTab.providers)
            }
            .pickerStyle(.segmented)
            .padding()
            
            Group {
                switch selectedTab {
                case .rules:
                    rulesList
                case .providers:
                    providersView
                }
            }
        }
        .searchable(text: $viewModel.searchText)
        .refreshable {
            await viewModel.fetchData()
        }
    }
    
    private var rulesList: some View {
        List {
            ForEach(viewModel.rules) { rule in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(rule.type)
                            .font(.headline)
                        Spacer()
                        Text(rule.proxy)
                            .font(.caption)
                            .foregroundColor(.blue)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(4)
                    }
                    
                    Text(rule.payload)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
        .overlay {
            if viewModel.isLoading {
                ProgressView()
            }
        }
    }
    
    private var providersView: some View {
        List {
            ForEach(viewModel.providers) { provider in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(provider.name)
                            .font(.headline)
                        Spacer()
                        Text("更新于: \(provider.formattedUpdateTime)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Label("\(provider.ruleCount) 条规则", systemImage: "list.bullet")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Button("更新") {
                            // TODO: 实现更新功能
                        }
                        .buttonStyle(.bordered)
                        .tint(.blue)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }
}

#Preview {
    NavigationStack {
        RulesView(server: ClashServer(name: "测试服务器", 
                                    url: "10.1.1.2", 
                                    port: "9090", 
                                    secret: "123456"))
    }
} 
