import SwiftUI
import StoreKit

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var billing = BillingManager.shared
    @ObservedObject private var entitlements = EntitlementStore.shared
    @ObservedObject private var credits = CreditsStore.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // MARK: - Header
                    VStack(spacing: 8) {
                        Image(systemName: "star.circle.fill")
                            .font(.system(size: 56))
                            .foregroundStyle(.yellow)
                        Text("ツギイチ Pro")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        Text("AIでステップ分解をもっと活用しよう")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 20)

                    // MARK: - Credits status
                    creditsStatusSection

                    // MARK: - Pro features
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Pro特典")
                            .font(.headline)
                            .padding(.horizontal)

                        ProFeatureRow(
                            icon: "cpu",
                            color: .purple,
                            title: "AI分解 300回/30日",
                            subtitle: "無料枠の30倍"
                        )
                        ProFeatureRow(
                            icon: "bag.badge.plus",
                            color: .blue,
                            title: "追加パック購入",
                            subtitle: "+300回のAIクレジット（期限なし）"
                        )
                        ProFeatureRow(
                            icon: "calendar",
                            color: .green,
                            title: "カレンダー書き出し",
                            subtitle: "Stepをカレンダーに同期"
                        )
                        ProFeatureRow(
                            icon: "infinity",
                            color: .orange,
                            title: "無制限のGoal",
                            subtitle: "Free版は\(SubscriptionManager.freeGoalLimit)件まで"
                        )
                    }
                    .padding(.vertical, 8)

                    // MARK: - Products
                    if billing.products.isEmpty {
                        ProgressView("商品を読み込み中...")
                            .padding()
                    } else {
                        VStack(spacing: 12) {
                            if let pro = billing.proProduct {
                                ProductButton(product: pro, label: "Pro（月額）") {
                                    Task { await billing.purchase(pro) }
                                }
                            }
                            if let pack = billing.packProduct {
                                ProductButton(product: pack, label: "AI追加パック (+300回)") {
                                    Task { await billing.purchase(pack) }
                                }
                            }
                        }
                        .padding(.horizontal)
                    }

                    // MARK: - Error
                    if let error = billing.purchaseError {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .padding(.horizontal)
                    }

                    // MARK: - Restore
                    Button("購入を復元") {
                        Task { await billing.restorePurchases() }
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                    // MARK: - Legal
                    VStack(spacing: 4) {
                        Text("サブスクリプションはApple IDに課金され、期間終了の24時間前までにキャンセルしない限り自動更新されます。")
                        Link("利用規約", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                        Link("プライバシーポリシー", destination: URL(string: "https://www.apple.com/privacy/")!)
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("アップグレード")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
            .task {
                if billing.products.isEmpty {
                    await billing.loadProducts()
                }
            }
            .disabled(billing.isPurchasing)
            .overlay {
                if billing.isPurchasing {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    ProgressView("購入処理中...")
                        .padding()
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    // MARK: - Credits Status

    private var creditsStatusSection: some View {
        VStack(spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("AI残クレジット")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(credits.totalRemaining)")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundStyle(credits.totalRemaining > 0 ? .primary : .red)
                        Text("回")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("プラン")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(entitlements.isPro ? "Pro" : "Free")
                        .font(.headline)
                        .foregroundStyle(entitlements.isPro ? .yellow : .secondary)
                }
            }

            HStack(spacing: 16) {
                Label("月次枠: \(credits.monthlyRemaining)/\(credits.monthlyLimit)",
                      systemImage: "calendar.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if credits.purchasedCredits > 0 {
                    Label("購入枠: \(credits.purchasedCredits)",
                          systemImage: "bag.circle")
                        .font(.caption)
                        .foregroundStyle(.blue)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }
}

// MARK: - ProFeatureRow

private struct ProFeatureRow: View {
    let icon: String
    let color: Color
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal)
    }
}

// MARK: - ProductButton

private struct ProductButton: View {
    let product: Product
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.headline)
                    Text(product.displayPrice + periodSuffix)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(Color.accentColor.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private var periodSuffix: String {
        if product.type == .autoRenewable {
            return " / 月"
        }
        return ""
    }
}

#Preview {
    PaywallView()
}
