import SwiftUI
import SwiftData

struct SettingsTab: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allGoals: [Goal]

    // MARK: - 通知設定
    @AppStorage("notificationWeekday") private var notificationWeekday: Int = 1   // 1=日曜
    @AppStorage("notificationHour") private var notificationHour: Int = 20
    @AppStorage("notificationMinute") private var notificationMinute: Int = 0

    // MARK: - エクスポート
    @State private var showExportSheet = false
    @State private var exportCSV: String = ""
    @State private var exportFileName: String = ""

    private let weekdayNames = ["日曜日", "月曜日", "火曜日", "水曜日", "木曜日", "金曜日", "土曜日"]
    // weekday values: 1=Sun, 2=Mon, ..., 7=Sat
    private let weekdayValues = [1, 2, 3, 4, 5, 6, 7]

    var body: some View {
        NavigationStack {
            List {
                // MARK: - 通知
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
                                Text(String(format: "%02d分", m)).tag(m)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                } header: {
                    Text("週次レビュー通知")
                } footer: {
                    Text("毎週\(weekdayNames[notificationWeekday - 1]) \(notificationHour):\(String(format: "%02d", notificationMinute))に通知されます")
                }

                // MARK: - データエクスポート
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

                // MARK: - アプリ情報
                Section("アプリ情報") {
                    LabeledContent("バージョン", value: "1.0")
                    LabeledContent("ビルド", value: "1")
                }
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
