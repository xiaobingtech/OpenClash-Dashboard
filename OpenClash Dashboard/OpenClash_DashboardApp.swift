//
//  OpenClash_DashboardApp.swift
//  OpenClash Dashboard
//
//  Created by Mou Yan on 11/19/24.
//

import SwiftUI
import Network

@main
struct OpenClash_DashboardApp: App {
    @StateObject private var networkMonitor = NetworkMonitor()
    
    init() {
        // 请求本地网络访问权限
        let localNetworkAuthorization = LocalNetworkAuthorization()
        Task {
            await localNetworkAuthorization.requestAuthorization()
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(networkMonitor)
        }
    }
}

// 本地网络授权处理类
class LocalNetworkAuthorization {
    func requestAuthorization() async {
        // 创建一个本地网络连接来触发系统权限请求
        let listener = try? NWListener(using: .tcp)
        listener?.stateUpdateHandler = { state in
            switch state {
            case .ready:
                // 获得授权后，停止监听
                listener?.cancel()
            default:
                break
            }
        }
        listener?.start(queue: .main)
    }
}
