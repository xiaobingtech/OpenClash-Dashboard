import SwiftUI

struct ThemeSettingsView: View {
    @AppStorage("appTheme") private var appTheme: String = "system"
    
    var body: some View {
        Form {
            Section {
                Picker("主题", selection: $appTheme) {
                    Text("跟随系统").tag("system")
                    Text("浅色").tag("light")
                    Text("深色").tag("dark")
                }
            } header: {
                Text("外观设置")
            }
        }
        .navigationTitle("外观")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        ThemeSettingsView()
    }
} 