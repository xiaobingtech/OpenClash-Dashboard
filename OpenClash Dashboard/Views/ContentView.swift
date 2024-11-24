import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = ServerViewModel()
    @State private var showingAddSheet = false
    @State private var editingServer: ClashServer?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                if viewModel.servers.isEmpty {
                    EmptyStateView(
                        showingAddSheet: $showingAddSheet
                    )
                } else {
                    VStack(spacing: 20) {
                        // 服务器卡片列表
                        ForEach(viewModel.servers) { server in
                            NavigationLink(destination: ServerDetailView(server: server)) {
                                ServerRowView(server: server)
                                    .contextMenu {
                                        Button(role: .destructive) {
                                            viewModel.deleteServer(server)
                                        } label: {
                                            Label("删除", systemImage: "trash")
                                        }
                                        
                                        Button {
                                            editingServer = server
                                        } label: {
                                            Label("编辑", systemImage: "pencil")
                                        }
                                    }
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        
                        // 设置卡片
                        VStack(spacing: 16) {
                            SettingsLinkRow(
                                title: "外观",
                                icon: "paintbrush.fill",
                                iconColor: .purple,
                                destination: ThemeSettingsView()
                            )
                            
                            SettingsLinkRow(
                                title: "如何使用",
                                icon: "questionmark.circle.fill",
                                iconColor: .blue,
                                destination: HelpView()
                            )
                            
                            SettingsLinkRow(
                                title: "给APP评分",
                                icon: "star.fill",
                                iconColor: .yellow,
                                destination: RateAppView()
                            )
                        }
                        .padding()
                        .background(Color(.secondarySystemGroupedBackground))
                        .cornerRadius(16)
                        
                        // 版本信息
                        Text("Ver: 1.0.0")
                            .foregroundColor(.secondary)
                            .font(.footnote)
                            .padding(.top, 8)
                    }
                    .padding()
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Sheer")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddSheet = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(.orange)
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AddServerView(viewModel: viewModel)
            }
            .sheet(item: $editingServer) { server in
                EditServerView(viewModel: viewModel, server: server)
            }
            .refreshable {
                await viewModel.checkAllServersStatus()
            }
        }
    }
}

struct ServerRowView: View {
    let server: ClashServer
    
    var body: some View {
        HStack(spacing: 16) {
            // 状态指示器
            ZStack {
                Circle()
                    .fill(server.status.color.opacity(0.2))
                    .frame(width: 40, height: 40)
                
                Circle()
                    .fill(server.status.color)
                    .frame(width: 12, height: 12)
            }
            
            // 服务器信息
            VStack(alignment: .leading, spacing: 6) {
                Text(server.displayName)
                    .font(.headline)
                
                HStack(spacing: 8) {
                    Label(server.status.text, systemImage: "network")
                        .font(.caption)
                        .foregroundColor(server.status.color)
                    
                    if let version = server.version {
                        Text("•")
                            .foregroundColor(.secondary)
                        Label(version, systemImage: "tag")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

struct SettingsLinkRow<Destination: View>: View {
    let title: String
    let icon: String
    let iconColor: Color
    let destination: Destination
    
    var body: some View {
        NavigationLink(destination: destination) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(iconColor)
                    .frame(width: 32)
                
                Text(title)
                    .font(.body)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// 新增空状态视图
struct EmptyStateView: View {
    @Binding var showingAddSheet: Bool
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // 图标
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.1))
                    .frame(width: 100, height: 100)
                
                Image(systemName: "server.rack")
                    .font(.system(size: 40))
                    .foregroundColor(.orange)
            }
            
            // 文字说明
            VStack(spacing: 8) {
                Text("还没有服务器")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("点击右上角的加号添加一个服务器")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // 添加按钮
            Button {
                showingAddSheet = true
            } label: {
                Label("添加服务器", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.orange)
                    .cornerRadius(25)
            }
            
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    ContentView()
}
