//
//  LogLevelSelectionView.swift
//  OpenClash Dashboard
//
//  Created by Mou Yan on 11/28/24.
//


import SwiftUI

struct LogLevelSelectionView: View {
    @Binding var selectedLevel: LogLevel
    let onLevelSelected: (LogLevel) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        Form {
            Section {
                ForEach(LogLevel.allCases, id: \.self) { level in
                    Button {
                        selectedLevel = level
                        onLevelSelected(level)
                        dismiss()
                    } label: {
                        HStack {
                            Label {
                                Text(level.rawValue)
                            } icon: {
                                Image(systemName: level.systemImage)
                                    .foregroundColor(level.color)
                            }
                            
                            Spacer()
                            
                            if level == selectedLevel {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .foregroundColor(.primary)
                }
            }
            
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("日志级别说明")
                        .font(.headline)
                    
                    Text("选择要显示的日志级别，高级别会包含低级别的日志")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Image(systemName: "arrow.down")
                        Text("日志级别从高到低")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(LogLevel.allCases, id: \.self) { level in
                            Label {
                                Text(level.rawValue)
                            } icon: {
                                Image(systemName: level.systemImage)
                            }
                            .foregroundColor(level.color)
                            .font(.caption)
                        }
                    }
                    .padding(.leading)
                }
                .padding(.vertical, 8)
            }
        }
        .navigationTitle("日志级别")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationView {
        LogLevelSelectionView(
            selectedLevel: .constant(.info),
            onLevelSelected: { _ in }
        )
    }
}
