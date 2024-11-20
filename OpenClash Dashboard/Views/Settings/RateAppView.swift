import SwiftUI
import StoreKit

struct RateAppView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        List {
            Section {
                VStack(spacing: 20) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.orange)
                    
                    Text("喜欢这个应用吗？")
                        .font(.headline)
                    
                    Text("您的评分对我们很重要，它能帮助我们做得更好！")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Button("在 App Store 中评分") {
                        if let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
                            SKStoreReviewController.requestReview(in: scene)
                        }
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                }
                .padding()
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("评分")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        RateAppView()
    }
} 