import SwiftUI

struct ClientTagView: View {
    @Environment(\.dismiss) private var dismiss
    let viewModel: ConnectionsViewModel
    @ObservedObject var tagViewModel: ClientTagViewModel
    
    private var uniqueActiveConnections: [ClashConnection] {
        let activeConnections = viewModel.connections.filter { $0.isAlive }
        var uniqueIPs: Set<String> = []
        var uniqueConnections: [ClashConnection] = []
        
        for connection in activeConnections {
            let ip = connection.metadata.sourceIP
            if uniqueIPs.insert(ip).inserted {
                uniqueConnections.append(connection)
            }
        }
        
        return uniqueConnections
    }
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(tagViewModel.tags) { tag in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(tag.name)
                                    .font(.headline)
                                Text(tag.ip)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Button(action: {
                                tagViewModel.removeTag(tag)
                            }) {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                } header: {
                    Text("已保存的标签")
                }
                
                Section {
                    ForEach(uniqueActiveConnections) { connection in
                        let ip = connection.metadata.sourceIP
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(ip)
                                    .font(.headline)
                                if let process = connection.metadata.process, !process.isEmpty {
                                    Text(process)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            Button(action: {
                                tagViewModel.showAddTagSheet(for: ip)
                            }) {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(.accentColor)
                                    .font(.system(size: 22))
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .contentShape(Rectangle())
                        .frame(height: 44)
                    }
                } header: {
                    Text("活跃连接")
                }
            }
            .navigationTitle("客户端标签")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $tagViewModel.showingAddSheet) {
                if let ip = tagViewModel.selectedIP {
                    AddTagSheet(ip: ip, viewModel: tagViewModel)
                }
            }
        }
    }
}

// 添加标签表单
struct AddTagSheet: View {
    let ip: String
    @ObservedObject var viewModel: ClientTagViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var tagName = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("标签名称", text: $tagName)
                    Text(ip)
                        .foregroundColor(.secondary)
                } header: {
                    Text("添加新标签")
                }
            }
            .navigationTitle("新建标签")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        viewModel.addTag(name: tagName, ip: ip)
                        dismiss()
                    }
                    .disabled(tagName.isEmpty)
                }
            }
        }
    }
}

// 标签数据模型
struct ClientTag: Identifiable, Codable {
    let id: UUID
    var name: String
    var ip: String
    
    init(id: UUID = UUID(), name: String, ip: String) {
        self.id = id
        self.name = name
        self.ip = ip
    }
}

// 标签管理 ViewModel
class ClientTagViewModel: ObservableObject {
    @Published var tags: [ClientTag] = []
    @Published var showingAddSheet = false
    @Published var selectedIP: String?
    
    private let saveKey = "ClientTags"
    
    init() {
        loadTags()
    }
    
    func showAddTagSheet(for ip: String) {
        selectedIP = ip
        showingAddSheet = true
    }
    
    func addTag(name: String, ip: String) {
        if let existingIndex = tags.firstIndex(where: { $0.ip == ip }) {
            tags[existingIndex].name = name
        } else {
            let tag = ClientTag(name: name, ip: ip)
            tags.append(tag)
        }
        saveTags()
        objectWillChange.send()
    }
    
    func removeTag(_ tag: ClientTag) {
        tags.removeAll { $0.id == tag.id }
        saveTags()
        objectWillChange.send()
    }
    
    func hasTag(for ip: String) -> Bool {
        tags.contains { $0.ip == ip }
    }
    
    private func saveTags() {
        if let encoded = try? JSONEncoder().encode(tags) {
            UserDefaults.standard.set(encoded, forKey: saveKey)
        }
    }
    
    func loadTags() {
        if let data = UserDefaults.standard.data(forKey: saveKey),
           let decoded = try? JSONDecoder().decode([ClientTag].self, from: data) {
            tags = decoded
        }
    }
}

#Preview {
    ClientTagView(viewModel: ConnectionsViewModel(), tagViewModel: ClientTagViewModel())
} 