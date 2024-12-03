import SwiftUI

struct SettingsView: View {
    let server: ClashServer
    @StateObject private var viewModel = SettingsViewModel()
    @State private var showingUpgradeAlert = false
    @State private var showingRestartAlert = false
    
    var body: some View {
        Form {
            // 端口设置
            Section("端口设置") {
                HStack {
                    Text("HTTP 端口")
                    Spacer()
                    TextField("", text: .constant("\(viewModel.config?.port ?? 0)"))
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 100)
                }
                
                HStack {
                    Text("Socks5 端口")
                    Spacer()
                    TextField("", text: .constant("\(viewModel.config?.socksPort ?? 0)"))
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 100)
                }
                
                HStack {
                    Text("混合端口")
                    Spacer()
                    TextField("", text: .constant("\(viewModel.config?.mixedPort ?? 0)"))
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 100)
                }
                
                HStack {
                    Text("重定向端口")
                    Spacer()
                    TextField("", text: .constant("\(viewModel.config?.redirPort ?? 0)"))
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 100)
                }
                
                HStack {
                    Text("TProxy 端口")
                    Spacer()
                    TextField("", text: .constant("\(viewModel.config?.tproxyPort ?? 0)"))
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 100)
                }
            }
            
            // 常规设置
            Section("常规设置") {
                Toggle("允许局域网连接", isOn: $viewModel.allowLan)
                    .onChange(of: viewModel.allowLan) { newValue in
                        viewModel.updateConfig("allow-lan", value: newValue, server: server)
                    }
                
                Picker("运行模式", selection: $viewModel.mode) {
                    Text("规则模式").tag("rule")
                    Text("全局模式").tag("global")
                    Text("直连模式").tag("direct")
                    Text("脚本模式").tag("script")
                }
                .onChange(of: viewModel.mode) { newValue in
                    viewModel.updateConfig("mode", value: newValue, server: server)
                }
                
                Picker("日志等级", selection: $viewModel.logLevel) {
                    Text("调试").tag("debug")
                    Text("信息").tag("info")
                    Text("警告").tag("warning")
                    Text("错误").tag("error")
                    Text("静默").tag("silent")
                }
                .onChange(of: viewModel.logLevel) { newValue in
                    viewModel.updateConfig("log-level", value: newValue, server: server)
                }
            }
            
            // TUN 设置
            Section("TUN 设置") {
                Toggle("启用 TUN 模式", isOn: $viewModel.tunEnable)
                    .onChange(of: viewModel.tunEnable) { newValue in
                        viewModel.updateConfig("tun.enable", value: newValue, server: server)
                    }
                
                HStack {
                    Text("TUN 协议栈")
                    Spacer()
                    Picker("", selection: $viewModel.tunStack) {
                        Text("gVisor").tag("gVisor")
                        Text("Mixed").tag("mixed")
                        Text("System").tag("system")
                    }
                    .pickerStyle(.menu)
                    .onChange(of: viewModel.tunStack) { newValue in
                        viewModel.updateConfig("tun.stack", value: newValue, server: server)
                    }
                }
                
                HStack {
                    Text("设备名称")
                    Spacer()
                    TextField("utun", text: $viewModel.tunDevice)
                        .multilineTextAlignment(.trailing)
                        .onChange(of: viewModel.tunDevice) { newValue in
                            viewModel.updateConfig("tun.device", value: newValue, server: server)
                        }
                }
                
                HStack {
                    Text("网卡名称")
                    Spacer()
                    TextField("", text: $viewModel.interfaceName)
                        .multilineTextAlignment(.trailing)
                        .onChange(of: viewModel.interfaceName) { newValue in
                            viewModel.updateConfig("interface-name", value: newValue, server: server)
                        }
                }
            }
            
            // 系统维护
            Section("系统维护") {
                Button(action: { viewModel.reloadConfig(server: server) }) {
                    HStack {
                        Text("重载配置文件")
                        Spacer()
                        Image(systemName: "arrow.clockwise")
                    }
                }
                
                Button(action: { viewModel.updateGeoDatabase(server: server) }) {
                    HStack {
                        Text("更新 GEO 数据库")
                        Spacer()
                        Image(systemName: "globe.asia.australia")
                    }
                }
                
                Button(action: { viewModel.clearFakeIP(server: server) }) {
                    HStack {
                        Text("清空 FakeIP 数据库")
                        Spacer()
                        Image(systemName: "trash")
                    }
                }
                
                Button(action: { 
                    // 显示重启确认对话框
                    showingRestartAlert = true 
                }) {
                    HStack {
                        Text("重启核心")
                        Spacer()
                        Image(systemName: "power")
                    }
                }
                
                Button(action: { 
                    // 显示更新确认对话框
                    showingUpgradeAlert = true 
                }) {
                    HStack {
                        Text("更新核心")
                            .foregroundColor(.red)
                        Spacer()
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(.red)
                    }
                }
            }
            .alert("重启核心", isPresented: $showingRestartAlert) {
                Button("取消", role: .cancel) { }
                Button("确认重启", role: .destructive) {
                    viewModel.restartCore(server: server)
                }
            } message: {
                Text("重启核心会导致服务暂时中断，确定要继续吗？")
            }
            .alert("更新核心", isPresented: $showingUpgradeAlert) {
                Button("取消", role: .cancel) { }
                Button("确认更新", role: .destructive) {
                    viewModel.upgradeCore(server: server)
                }
            } message: {
                Text("更新核心是一个高风险操作，可能会导致服务不可用。除非您明确知道自己在做什么，否则不建议执行此操作。\n\n确定要继续吗？")
            }
        }
        .navigationTitle("配置")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.fetchConfig(server: server)
        }
    }
} 
