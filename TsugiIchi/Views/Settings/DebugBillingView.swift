#if DEBUG
import StoreKit
import SwiftUI
import UIKit

/// Debug-only screen to diagnose billing state.
/// Accessible from Settings > "Debug Billing" (DEBUG builds only).
struct DebugBillingView: View {

    @ObservedObject private var entitlements = EntitlementStore.shared
    @ObservedObject private var credits = CreditsStore.shared
    @ObservedObject private var billing = BillingManager.shared
    @ObservedObject private var eventLog = BillingEventLog.shared

    @State private var isRefreshing = false

    // StoreKit diagnostics
    @State private var subscriptionStatusSummary: String = "(not loaded)"
    @State private var currentEntitlementsSummary: String = "(not loaded)"
    @State private var isLoadingDiagnostics = false

    // Export UI
    @State private var showCopiedAlert = false

    var body: some View {
        List {
            proStatusSection
            storeKitDiagnosticsSection
            creditsSection
            proxySection
            eventLogSection
            actionsSection
        }
        .navigationTitle("Debug Billing")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            // Best-effort preload
            await billing.loadProducts()
            await refreshStoreKitDiagnostics()
        }
        .alert("Copied", isPresented: $showCopiedAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Export text copied to clipboard")
        }
    }

    // MARK: - Pro Status

    private var proStatusSection: some View {
        Section("Pro Status") {
            row("EntitlementStore.isPro",
                value: entitlements.isPro ? "true" : "false",
                color: entitlements.isPro ? .green : .red)
            row("activeProductId", value: entitlements.activeProductId ?? "(nil)")
            row("proTransactionJWS",
                value: entitlements.proTransactionJWS != nil
                    ? "present (\(entitlements.proTransactionJWS!.prefix(20))...)"
                    : "(nil)",
                color: entitlements.proTransactionJWS != nil ? .green : .orange)

            row("lastEntitlementRefreshDate",
                value: entitlements.lastEntitlementRefreshDate.map { formatDateTime($0) } ?? "(nil)")
            row("lastTransactionUpdateDate",
                value: entitlements.lastTransactionUpdateDate.map { formatDateTime($0) } ?? "(nil)")
        }
    }

    // MARK: - StoreKit Diagnostics

    private var storeKitDiagnosticsSection: some View {
        Section("StoreKit Diagnostics") {
            HStack {
                Label("Refresh", systemImage: "arrow.clockwise")
                Spacer()
                if isLoadingDiagnostics {
                    ProgressView().controlSize(.small)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                Task { await refreshStoreKitDiagnostics() }
            }
            .disabled(isLoadingDiagnostics)

            LabeledContent("Products loaded", value: "\(billing.products.count)")

            VStack(alignment: .leading, spacing: 8) {
                Text("subscriptionStatus summary")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(subscriptionStatusSummary)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("currentEntitlements summary")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(currentEntitlementsSummary)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
            }
        }
    }

    // MARK: - Credits

    private var creditsSection: some View {
        Section("Credits") {
            row("monthlyUsed", value: "\(credits.monthlyUsedCount)")
            row("monthlyLimit (current)", value: "\(credits.monthlyLimit) (\(entitlements.isPro ? "Pro" : "Free"))")
            row("monthlyRemaining", value: "\(credits.monthlyRemaining)")
            row("purchasedCredits", value: "\(credits.purchasedCredits)")
            row("totalRemaining", value: "\(credits.totalRemaining)",
                color: credits.totalRemaining > 0 ? .primary : .red)
            row("canUseAI", value: credits.canUseAI ? "true" : "false")

            row("windowStart",
                value: credits.windowStartDate.map { formatDateTime($0) } ?? "(not started)")

            // Show both tiers explicitly (same windowStart/usedCount, different limits)
            row("free tier", value: "start=\(credits.windowStartDate.map(formatDateTime) ?? \"(nil)\") used=\(credits.monthlyUsedCount) limit=\(CreditsStore.freeMonthlyLimit)")
            row("pro tier", value: "start=\(credits.windowStartDate.map(formatDateTime) ?? \"(nil)\") used=\(credits.monthlyUsedCount) limit=\(CreditsStore.proMonthlyLimit)")
        }
    }

    // MARK: - Proxy

    private var proxySection: some View {
        Section("Proxy") {
            row("lastProxyRemaining", value: credits.lastProxyRemaining.map(String.init) ?? "(nil)")
            row("lastProxySyncDate", value: credits.lastProxySyncDate.map { formatDateTime($0) } ?? "(nil)")
            row("lastVerificationMethod", value: credits.lastVerificationMethod ?? "(nil)")

            row("X-Client-Id", value: shortClientId(ClientId.current))
            row("X-Is-Pro sent", value: entitlements.isPro ? "true" : "false")
            row("X-Signed-Transaction", value: entitlements.proTransactionJWS != nil ? "present" : "nil")
        }
    }

    // MARK: - Event Log

    private var eventLogSection: some View {
        Section("Billing Event Log (last 10)") {
            HStack {
                Button {
                    UIPasteboard.general.string = eventLog.exportText()
                    showCopiedAlert = true
                } label: {
                    Label("Copy export", systemImage: "doc.on.doc")
                }

                Spacer()

                Button {
                    shareExportText(eventLog.exportText())
                } label: {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
            }

            Button(role: .destructive) {
                eventLog.clear()
            } label: {
                Label("Clear log", systemImage: "trash")
            }

            if eventLog.entries.isEmpty {
                Text("(no events)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(eventLog.entries.prefix(10))) { entry in
                    Text("[\(entry.timeString)] [\(entry.category.rawValue)] \(entry.message)")
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
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
                        ProgressView().controlSize(.small)
                    }
                }
            }
            .disabled(isRefreshing)

            Button {
                Task {
                    isRefreshing = true
                    await billing.loadProducts()
                    await entitlements.refresh()
                    await refreshStoreKitDiagnostics()
                    isRefreshing = false
                }
            } label: {
                Label("Reload Products + Diagnostics", systemImage: "arrow.triangle.2.circlepath")
            }

            Button(role: .destructive) {
                credits.resetAll()
                BillingEventLog.shared.log(.credit, "CreditsStore.resetAll invoked from DebugBillingView")
            } label: {
                Label("Reset Credits (testing)", systemImage: "trash")
            }
        }
    }

    // MARK: - StoreKit Diagnostics

    private func refreshStoreKitDiagnostics() async {
        isLoadingDiagnostics = true
        defer { isLoadingDiagnostics = false }

        // subscriptionStatus
        var statusLines: [String] = []
        let ids = [BillingProduct.proMonthly.rawValue, BillingProduct.proYearly.rawValue]

        // Ensure products are loaded (best effort)
        if billing.products.isEmpty {
            await billing.loadProducts()
        }

        for id in ids {
            guard let product = billing.products.first(where: { $0.id == id }) else {
                statusLines.append("\(id): (product not loaded)")
                continue
            }
            guard let subscriptionInfo = product.subscription else {
                statusLines.append("\(id): (not a subscription product)")
                continue
            }

            do {
                let statuses = try await subscriptionInfo.status
                if statuses.isEmpty {
                    statusLines.append("\(id): (no status)")
                } else {
                    for status in statuses {
                        let state = String(describing: status.state)
                        var exp: String = "(nil)"
                        if let txResult = status.transaction {
                            switch txResult {
                            case .verified(let tx):
                                exp = tx.expirationDate.map { formatDateTime($0) } ?? "(nil)"
                            case .unverified(let tx, _):
                                exp = tx.expirationDate.map { formatDateTime($0) } ?? "(nil)"
                            }
                        }
                        statusLines.append("\(id): state=\(state) exp=\(exp)")
                    }
                }
            } catch {
                statusLines.append("\(id): error=\(error)")
            }
        }
        subscriptionStatusSummary = statusLines.isEmpty ? "(none)" : statusLines.joined(separator: "\n")

        // currentEntitlements
        var entitlementLines: [String] = []
        for await result in StoreKit.Transaction.currentEntitlements {
            switch result {
            case .verified(let t):
                let exp = t.expirationDate.map { formatDateTime($0) } ?? "(nil)"
                let revoked = t.revocationDate != nil ? "revoked" : "active"
                entitlementLines.append("verified: \(t.productID) exp=\(exp) \(revoked)")
            case .unverified(let t, let err):
                let exp = t.expirationDate.map { formatDateTime($0) } ?? "(nil)"
                entitlementLines.append("unverified: \(t.productID) exp=\(exp) err=\(err)")
            }
        }
        currentEntitlementsSummary = entitlementLines.isEmpty ? "(none)" : entitlementLines.joined(separator: "\n")

        BillingEventLog.shared.log(.entitlement, "DebugBillingView refreshed StoreKit diagnostics")
    }

    // MARK: - Export

    private func shareExportText(_ text: String) {
        let activityVC = UIActivityViewController(activityItems: [text], applicationActivities: nil)

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            if let popover = activityVC.popoverPresentationController {
                popover.sourceView = rootVC.view
                popover.sourceRect = CGRect(x: rootVC.view.bounds.midX, y: rootVC.view.bounds.midY, width: 0, height: 0)
                popover.permittedArrowDirections = []
            }
            rootVC.present(activityVC, animated: true)
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

    private func formatDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: date)
    }

    private func shortClientId(_ clientId: String) -> String {
        if clientId.count <= 10 { return clientId }
        return String(clientId.prefix(8)) + "..." + String(clientId.suffix(4))
    }
}

#Preview {
    NavigationStack {
        DebugBillingView()
    }
}
#endif
