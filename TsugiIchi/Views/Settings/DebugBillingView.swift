#if DEBUG
import SwiftUI
import StoreKit

/// Debug-only screen to diagnose billing state.
/// Accessible from Settings > "課金デバッグ" (DEBUG builds only).
struct DebugBillingView: View {

    @ObservedObject private var entitlements = EntitlementStore.shared
    @ObservedObject private var credits = CreditsStore.shared
    @ObservedObject private var billing = BillingManager.shared

    @State private var isRefreshing = false
    @State private var proxyTestResult: String?
    @State private var isTestingProxy = false

    var body: some View {
        List {
            proStatusSection
            creditsSection
            proxySection
            transactionsSection
            actionsSection
        }
        .navigationTitle("課金デバッグ")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Pro Status

    private var proStatusSection: some View {
        Section("Pro Status") {
            row("EntitlementStore.isPro", value: entitlements.isPro ? "true" : "false",
                color: entitlements.isPro ? .green : .red)
            row("activeProductId", value: entitlements.activeProductId ?? "(nil)")
            row("proTransactionJWS",
                value: entitlements.proTransactionJWS != nil
                    ? "あり (\(entitlements.proTransactionJWS!.prefix(20))...)"
                    : "(nil)",
                color: entitlements.proTransactionJWS != nil ? .green : .orange)
        }
    }

    // MARK: - Credits

    private var creditsSection: some View {
        Section("Credits") {
            row("monthlyLimit", value: "\(credits.monthlyLimit) (\(entitlements.isPro ? "Pro" : "Free"))")
            row("monthlyUsed", value: "\(credits.monthlyUsedCount)")
            row("monthlyRemaining", value: "\(credits.monthlyRemaining)")
            row("purchasedCredits", value: "\(credits.purchasedCredits)")
            row("totalRemaining", value: "\(credits.totalRemaining)",
                color: credits.totalRemaining > 0 ? .primary : .red)
            row("canUseAI", value: credits.canUseAI ? "true" : "false")
            row("windowStart",
                value: credits.windowStartDate.map { formatDate($0) } ?? "(未開始)")
            if let lastProxy = credits.lastProxyRemaining {
                row("lastProxyRemaining", value: "\(lastProxy)")
            }
        }
    }

    // MARK: - Proxy Verification

    private var proxySection: some View {
        Section("Proxy Verification") {
            row("lastVerificationMethod",
                value: credits.lastVerificationMethod ?? "(未取得)")
            row("X-Client-Id", value: String(ClientId.current.prefix(8)) + "...")
            row("X-Is-Pro sent", value: entitlements.isPro ? "true" : "false")
            row("X-Signed-Transaction",
                value: entitlements.proTransactionJWS != nil ? "送信あり" : "送信なし")

            if let result = proxyTestResult {
                Text(result)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Transactions

    private var transactionsSection: some View {
        Section("StoreKit Transactions") {
            Text("Xcodeコンソールで [EntitlementStore] / [BillingManager] ログを確認")
                .font(.caption)
                .foregroundStyle(.secondary)

            LabeledContent("Products loaded", value: "\(billing.products.count)")
            ForEach(billing.products, id: \.id) { product in
                HStack {
                    Text(product.displayName)
                        .font(.caption)
                    Spacer()
                    Text(product.displayPrice)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Actions

    private var actionsSection: some View {
        Section("Actions") {
            Button {
                Task {
                    isRefreshing = true
                    await entitlements.refresh()
                    isRefreshing = false
                }
            } label: {
                HStack {
                    Label("Refresh Entitlements", systemImage: "arrow.clockwise")
                    if isRefreshing {
                        Spacer()
                        ProgressView()
                            .controlSize(.small)
                    }
                }
            }
            .disabled(isRefreshing)

            Button(role: .destructive) {
                credits.resetAll()
            } label: {
                Label("Reset Credits (テスト用)", systemImage: "trash")
            }

            Button {
                Task {
                    isRefreshing = true
                    await billing.loadProducts()
                    await entitlements.refresh()
                    isRefreshing = false
                }
            } label: {
                Label("Reload Products + Entitlements", systemImage: "arrow.triangle.2.circlepath")
            }
        }
    }

    // MARK: - Helpers

    private func row(_ label: String, value: String, color: Color = .primary) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(color)
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: date)
    }
}

#Preview {
    NavigationStack {
        DebugBillingView()
    }
}
#endif
