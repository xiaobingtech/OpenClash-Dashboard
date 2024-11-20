import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = ServerViewModel()
    @State private var showingAddSheet = false
    @State private var editingServer: ClashServer?
    
    var body: some View {
        NavigationStack {
            List {
                Section("服务器") {
                    ForEach(viewModel.servers) { server in
                        NavigationLink(destination: ServerDetailView(server: server)) {
                            ServerRowView(server: server)
                        }
                        .swipeActions(edge: .trailing) {
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
                            .tint(.blue)
                        }
                    }
                }
                
                Section("设置") {
                    NavigationLink(destination: ThemeSettingsView()) {
                        Label("外观", systemImage: "paintbrush.fill")
                    }
                    
                    NavigationLink(destination: HelpView()) {
                        Label("如何使用", systemImage: "questionmark.circle.fill")
                    }
                    
                    NavigationLink(destination: RateAppView()) {
                        Label("给APP评分", systemImage: "star.fill")
                    }
                }
                
                Section {
                    Text("Ver: 1.0.0")
                        .foregroundColor(.secondary)
                        .font(.footnote)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .navigationTitle("Sheer")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddSheet = true
                    } label: {
                        Image(systemName: "plus")
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
        HStack {
            Circle()
                .fill(server.status.color)
                .frame(width: 8, height: 8)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(server.displayName)
                    .font(.system(.body))
                
                Text(server.status.text)
                    .font(.system(.caption))
                    .foregroundColor(server.status.color)
            }
            
            Spacer()
            
            // Image(systemName: "chevron.right")
            //     .foregroundColor(.gray)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ContentView()
}
