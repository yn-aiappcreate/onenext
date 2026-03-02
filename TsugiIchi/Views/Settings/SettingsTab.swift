import SwiftUI
import SwiftData

struct SettingsTab: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allGoals: [Goal]
    @ObservedObject private var subscriptionManager = SubscriptionManager.shared

    @ObservedObject private var billing = BillingManager.shared
    @ObservedObject private var entitlements = EntitlementStore.shared
    @ObservedObject private var credits = CreditsStore.shared

    // MARK: - 通知設定
    @AppStorage("notificationWeekday") private var notificationWeekday: Int = 1   // 1=日曜
    @AppStorage("notificationHour") private var notificationHour: Int = 20
    @AppStorage("notificationMinute") private var notificationMinute: Int = 0

    // MARK: - AIアシスト
    @AppStorage("aiAssistEnabled") private var aiAssistEnabled = true
    @AppStorage("aiConsentGiven") private var aiConsentGiven = false
    @AppStorage("aiConfirmBeforeSend") private var aiConfirmBeforeSend = true
    @AppStorage("aiAutoRedact") private var aiAutoRedact = true
    @AppStorage("aiEndpointURL") private var aiEndpointURL = Constants.defaultAIProxyURL
    @AppStorage("aiAuthToken") private var aiAuthToken = Constants.defaultAIAuthToken

    // MARK: - カレンダー連携
    @AppStorage("calendarSyncEnabled") private var calendarSyncEnabled = false
    @AppStorage("calendarPreferredHour") private var calendarPreferredHour: Int = 20

    // MARK: - エクスポート
    @State private var showExportSheet = false
    @State private var exportCSV: String = ""
    @State private var exportFileName: String = ""

    // MARK: - Paywall
    @State private var showPaywall = false

    private var weekdayNames: [String] {
        [String(localized: "日曜日"), String(localized: "月曜日"), String(localized: "火曜日"),
         String(localized: "水曜日"), String(localized: "木曜日"), String(localized: "金曜日"), String(localized: "土曜日")]
    }
    // weekday values: 1=Sun, 2=Mon, ..., 7=Sat
    private let weekdayValues = [1, 2, 3, 4, 5, 6, 7]

    var body: some View {
        NavigationStack {
            List {
                notificationSection
                aiAssistSection
                subscriptionSection
                calendarSection
                exportSection
                appInfoSection
            }
            .navigationTitle("設定")
            .onChange(of: notificationWeekday) { _, _ in
                updateNotificationSchedule()
            }
            .onChange(of: notificationHour) { _, _ in
                updateNotificationSchedule()
            }
            .onChange(of: notificationMinute) { _, _ in
                updateNotificationSchedule()
            }
            .sheet(isPresented: $showExportSheet) {
                CSVShareSheet(csv: exportCSV, fileName: exportFileName)
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
            .task {
                await billing.loadProducts()
                await entitlements.refresh()
                await subscriptionManager.updateSubscriptionStatus()
            }
        }
    }

    // MARK: - 通知セクション

    private var notificationSection: some View {
        Section {
            Picker("曜日", selection: $notificationWeekday) {
                ForEach(Array(zip(weekdayValues, weekdayNames)), id: \.0) { value, name in
                    Text(name).tag(value)
                }
            }

            HStack {
                Text("時刻")
                Spacer()
                Picker("時", selection: $notificationHour) {
                    ForEach(0..<24, id: \.self) { h in
                        Text("\(h)時").tag(h)
                    }
                }
                .pickerStyle(.menu)

                Picker("分", selection: $notificationMinute) {
                    ForEach([0, 15, 30, 45], id: \.self) { m in
                        Text("\(String(format: "%02d", m))\(String(localized: "分"))").tag(m)
                    }
                }
                .pickerStyle(.menu)
            }
        } header: {
            Text("週次レビュー通知")
        } footer: {
            Text("毎週\(weekdayNames[notificationWeekday - 1]) \(notificationHour):\(String(format: "%02d", notificationMinute))に通知されます")
        }
    }

    // MARK: - AIアシストセクション

    private var aiAssistSection: some View {
        Section {
            Toggle("AIアシストを有効にする", isOn: $aiAssistEnabled)

            if aiAssistEnabled {
                Toggle("送信前に毎回確認", isOn: $aiConfirmBeforeSend)

                Toggle("個人情報を自動マスク", isOn: $aiAutoRedact)

                if aiConsentGiven {
                    Button(role: .destructive) {
                        aiConsentGiven = false
                    } label: {
                        Label("AI利用の同意をリセット", systemImage: "arrow.counterclockwise")
                    }
                } else {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundStyle(.secondary)
                        Text("初回利用時に同意画面が表示されます")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        } header: {
            Text("AIアシスト")
        } footer: {
            Text("Goal詳細画面からAIでステップ案を自動生成できます。")
        }
    }

    // MARK: - サブスクリプションセクション

    private var subscriptionSection: some View {
        Section {
            HStack {
                Image(systemName: entitlements.isPro ? "star.circle.fill" : "star.circle")
                    .foregroundStyle(entitlements.isPro ? Color.yellow : Color.secondary)
                Text(entitlements.isPro ? "Pro プラン利用中" : "Free プラン")
                    .fontWeight(.semibold)
                Spacer()
                if !entitlements.isPro {
                    Button("アップグレード") {
                        showPaywall = true
                    }
                    .font(.caption)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("AI残クレジット")
                        .font(.subheadline)
                    Spacer()
                    Text("\(credits.totalRemaining)回")
                        .font(.headline)
                        .foregroundStyle(credits.totalRemaining > 0 ? Color.primary : Color.red)
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

            if !billing.products.isEmpty {
                Button {
                    showPaywall = true
                } label: {
                    HStack {
                        Image(systemName: "bag.badge.plus")
                            .foregroundStyle(.blue)
                        Text("AI追加パックを購入")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Button("購入を復元") {
                Task { await billing.restorePurchases() }
            }
            .font(.footnote)
        } header: {
            Text("サブスクリプション")
        }
    }

    // MARK: - カレンダーセクション

    private var calendarSection: some View {
        Section {
            Toggle("カレンダー同期", isOn: $calendarSyncEnabled)
                .onChange(of: calendarSyncEnabled) { _, enabled in
                    if enabled {
                        Task {
                            let granted = await CalendarService.requestAccess()
                            if !granted {
                                calendarSyncEnabled = false
                            }
                        }
                    }
                }

            if calendarSyncEnabled {
                Picker("予定を入れる時刻", selection: $calendarPreferredHour) {
                    ForEach(0..<24, id: \.self) { h in
                        Text("\(h)時").tag(h)
                    }
                }
            }
        } header: {
            Text("カレンダー連携")
        } footer: {
            Text(calendarSyncEnabled
                 ? "Stepをカレンダーに追加すると、現在時刻から一番近い未来の\(calendarPreferredHour)時に予定が入ります。"
                 : "有効にすると、今週枠に追加したStepがiPhoneのカレンダーアプリに自動で登録されます。")
        }
    }

    // MARK: - エクスポートセクション

    private var exportSection: some View {
        Section("データエクスポート") {
            Button {
                exportGoalsCSV()
            } label: {
                Label("Goal一覧をCSVエクスポート", systemImage: "square.and.arrow.up")
            }

            Button {
                exportStepsCSV()
            } label: {
                Label("Step一覧をCSVエクスポート", systemImage: "square.and.arrow.up")
            }
        }
    }

    // MARK: - アプリ情報セクション

    private var appInfoSection: some View {
        Section("アプリ情報") {
            LabeledContent("バージョン", value: "1.0")
            LabeledContent("ビルド", value: "1")

            Link(destination: URL(string: "https://yn-aiappcreate.github.io/onenext/Docs/legal/privacy-policy.html")!) {
                Label("プライバシーポリシー", systemImage: "hand.raised")
            }

            Link(destination: URL(string: "https://yn-aiappcreate.github.io/onenext/Docs/legal/terms-of-service.html")!) {
                Label("利用規約", systemImage: "doc.text")
            }

            Link(destination: URL(string: "https://yn-aiappcreate.github.io/onenext/Docs/legal/support.html")!) {
                Label("サポート・お問い合わせ", systemImage: "questionmark.circle")
            }
        }
    }

    private func updateNotificationSchedule() {
        NotificationManager.scheduleWeeklyReview(
            weekday: notificationWeekday,
            hour: notificationHour,
            minute: notificationMinute
        )
    }

    private func exportGoalsCSV() {
        exportCSV = CSVExporter.exportGoals(allGoals)
        exportFileName = "tsugiichi_goals.csv"
        showExportSheet = true
    }

    private func exportStepsCSV() {
        exportCSV = CSVExporter.exportSteps(allGoals)
        exportFileName = "tsugiichi_steps.csv"
        showExportSheet = true
    }
}

// MARK: - CSVShareSheet

private struct CSVShareSheet: View {
    let csv: String
    let fileName: String

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text(fileName)
                        .font(.headline)

                    Text(csv)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .padding()
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .padding()
            }
            .navigationTitle("エクスポート")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        UIPasteboard.general.string = csv
                    } label: {
                        Label("コピー", systemImage: "doc.on.doc")
                    }
                }
            }
        }
    }
}

#Preview {
    SettingsTab()
        .modelContainer(for: [Goal.self, Step.self], inMemory: true)
}
