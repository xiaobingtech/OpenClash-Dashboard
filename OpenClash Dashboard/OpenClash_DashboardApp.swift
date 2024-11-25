//
//  OpenClash_DashboardApp.swift
//  OpenClash Dashboard
//
//  Created by Mou Yan on 11/19/24.
//

import SwiftUI

@main
struct OpenClash_DashboardApp: App {
    @StateObject private var networkMonitor = NetworkMonitor()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(networkMonitor)
        }
    }
}
