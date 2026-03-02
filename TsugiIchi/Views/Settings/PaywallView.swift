import SwiftUI
import StoreKit

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var subscriptionManager = SubscriptionManager.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "star.circle.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(.yellow)

                        Text("ツギイチ Pro")
                            .font(.largeTitle)
                            .fontWeight(.bold)

                        Text("すべての機能をアンロック")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 20)

                    // Features list
                    VStack(alignment: .leading, spacing: 16) {
                        ProFeatureRow(
                            icon: "cpu",
                            color: .purple,
                            title: "AIアシスト",
                            description: "AIでGoalをStepに自動分解"
                        )
                        ProFeatureRow(
                            icon: "calendar.badge.plus",
                            color: .blue,
                            title: "カレンダー連携",
                            description: "PlanのStepをiPhoneカレンダーに同期"
                        )
                        ProFeatureRow(
                            icon: "square.and.arrow.up",
                            color: .green,
                            title: "CSVエクスポート",
                            description: "Goal・Stepデータをcsv出力"
                        )
                        ProFeatureRow(
                            icon: "infinity",
                            color: .orange,
                            title: "無制限のGoal",
                            description: "Free版は\(SubscriptionManager.freeGoalLimit)件まで"
                        )
                    }
                    .padding(.horizontal)

                    // Products
                    VStack(spacing: 12) {
                        if subscriptionManager.products.isEmpty {
                            ProgressView()
                                .padding()
                        } else {
                            ForEach(subscriptionManager.products, id: \.id) { product in
                                ProductButton(product: product) {
                                    Task {
                                        await subscriptionManager.purchase(product)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal)

                    if let error = subscriptionManager.purchaseError {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    // Restore
                    Button("購入を復元") {
                        Task {
                            await subscriptionManager.restorePurchases()
                        }
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                    // Legal
                    VStack(spacing: 4) {
                        Text("サブスクリプションはiTunesアカウントに請求されます。")
                        Text("期間終了の24時間前までにキャンセルしない限り自動更新されます。")
                        Link("利用規約", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                        Link("プライバシーポリシー", destination: URL(string: "https://www.apple.com/legal/privacy/")!)
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
            .task {
                await subscriptionManager.loadProducts()
            }
        }
    }
}

// MARK: - ProFeatureRow

private struct ProFeatureRow: View {
    let icon: String
    let color: Color
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
                .frame(width: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - ProductButton

private struct ProductButton: View {
    let product: Product
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(product.displayName)
                        .font(.headline)
                    if let subscription = product.subscription {
                        Text(periodLabel(subscription.subscriptionPeriod))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Text(product.displayPrice)
                    .font(.title3)
                    .fontWeight(.bold)
            }
            .padding()
            .background(Color.accentColor.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.accentColor, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func periodLabel(_ period: Product.SubscriptionPeriod) -> String {
        switch period.unit {
        case .month: return period.value == 1 ? "毎月自動更新" : "\(period.value)ヶ月ごと"
        case .year:  return period.value == 1 ? "毎年自動更新" : "\(period.value)年ごと"
        case .week:  return "\(period.value)週間ごと"
        case .day:   return "\(period.value)日ごと"
        @unknown default: return ""
        }
    }
}

#Preview {
    PaywallView()
}
