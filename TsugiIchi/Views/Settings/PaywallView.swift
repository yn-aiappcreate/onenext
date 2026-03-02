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
                            if entitlements.isPro {
                                // Already subscribed - show current plan
                                HStack {
                                    Image(systemName: "checkmark.seal.fill")
                                        .foregroundStyle(.green)
                                    Text(entitlements.activeProductId == BillingProduct.proYearly.rawValue
                                         ? "Pro（年額）プラン利用中"
                                         : "Pro（月額）プラン利用中")
                                        .font(.headline)
                                        .foregroundStyle(.green)
                                }
                                .padding()
                            } else {
                                // Not subscribed - show both options
                                // Yearly plan (recommended)
                                YearlyProductButton {
                                    if let yearly = billing.proYearlyProduct {
                                        Task { await billing.purchase(yearly) }
                                    }
                                }
                                // Monthly plan
                                MonthlyProductButton {
                                    if let monthly = billing.proMonthlyProduct {
                                        Task { await billing.purchase(monthly) }
                                    }
                                }
                            }
                            // AI pack available for Pro users
                            if entitlements.isPro {
                                PackProductButton {
                                    if let pack = billing.packProduct {
                                        Task { await billing.purchase(pack) }
                                    }
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
                            .foregroundStyle(credits.totalRemaining > 0 ? Color.primary : Color.red)
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

// MARK: - YearlyProductButton

private struct YearlyProductButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text("Pro（年額）")
                                .font(.headline)
                            Text("おすすめ")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.orange, in: RoundedRectangle(cornerRadius: 4))
                        }
                        HStack(spacing: 6) {
                            Text("¥3,600")
                                .font(.subheadline)
                                .strikethrough()
                                .foregroundStyle(.secondary)
                            Text("¥2,500 / 年")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.orange)
                        }
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 4) {
                    Text("月あたり約¥208")
                        .font(.caption)
                        .foregroundStyle(.orange)
                    Text("· 30%OFF")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.orange)
                }
            }
            .padding()
            .background(Color.orange.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.orange.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - MonthlyProductButton

private struct MonthlyProductButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Pro（月額）")
                        .font(.headline)
                    Text("¥300 / 月")
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
}

// MARK: - PackProductButton

private struct PackProductButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("AI追加パック (+300回)")
                        .font(.headline)
                    Text("¥500")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(Color.blue.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    PaywallView()
}
