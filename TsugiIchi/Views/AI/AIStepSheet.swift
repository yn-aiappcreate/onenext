import SwiftUI
import SwiftData

/// Main AI step generation flow: consent → preview → loading → result/error.
struct AIStepSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let goal: Goal

    @AppStorage("aiConsentGiven") private var aiConsentGiven = false
    @AppStorage("aiConfirmBeforeSend") private var aiConfirmBeforeSend = true
    @AppStorage("aiAutoRedact") private var aiAutoRedact = true
    @AppStorage("aiEndpointURL") private var aiEndpointURL = Constants.defaultAIProxyURL
    @AppStorage("aiAuthToken") private var aiAuthToken = Constants.defaultAIAuthToken

    @State private var phase: Phase = .consent
    @State private var previewPayload: AIRequestPayload?
    @State private var redactionResult: Redactor.RedactionResult?
    @State private var generatedSteps: [AIStepResult] = []
    @State private var errorMessage: String?
    @State private var isLoading = false
    @State private var showPaywall = false

    @ObservedObject private var credits = CreditsStore.shared

    enum Phase {
        case consent
        case preview
        case loading
        case result
        case error
    }

    var body: some View {
        NavigationStack {
            Group {
                switch phase {
                case .consent:
                    AIConsentView(
                        onConsent: {
                            aiConsentGiven = true
                            preparePreview()
                        },
                        onCancel: { dismiss() }
                    )

                case .preview:
                    previewView

                case .loading:
                    loadingView

                case .result:
                    resultView

                case .error:
                    errorView
                }
            }
            .navigationTitle("AIステップ生成")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if phase != .loading {
                        Button("閉じる") { dismiss() }
                    }
                }
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
        }
        .onAppear {
            if aiConsentGiven {
                preparePreview()
            }
            // else: stays on .consent
        }
        .interactiveDismissDisabled(phase == .loading)
    }

    // MARK: - Preview Phase

    private var previewView: some View {
        List {
            Section("送信内容プレビュー") {
                LabeledContent("タイトル", value: goal.title)

                if let note = goal.note, !note.isEmpty {
                    if aiAutoRedact, let redaction = redactionResult {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("メモ（マスク済み）")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(redaction.masked)
                                .font(.body)
                        }
                    } else {
                        LabeledContent("メモ", value: note)
                    }
                }

                if let category = goal.category {
                    LabeledContent("カテゴリ", value: category.rawValue)
                }
            }

            if aiAutoRedact, let redaction = redactionResult, !redaction.changes.isEmpty {
                Section {
                    ForEach(Array(redaction.changes.enumerated()), id: \.offset) { _, change in
                        HStack {
                            Text(change.original)
                                .font(.caption)
                                .foregroundStyle(.red)
                                .strikethrough()
                            Image(systemName: "arrow.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(change.replacement)
                                .font(.caption)
                                .foregroundStyle(.green)
                                .fontWeight(.semibold)
                        }
                    }
                } header: {
                    Label("自動マスク", systemImage: "eye.slash")
                } footer: {
                    Text("個人情報っぽい文字列を自動的にマスクしました。設定からOFFにできます。")
                }
            }

            // MARK: - Credits info
            Section {
                HStack {
                    Image(systemName: "cpu")
                        .foregroundStyle(.purple)
                    Text("AI残クレジット: \(credits.totalRemaining)回")
                        .font(.subheadline)
                    Spacer()
                    if !credits.canUseAI {
                        Text("枠なし")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }

            Section {
                if credits.canUseAI {
                    Button {
                        Task { await sendRequest() }
                    } label: {
                        Label("送信する（1クレジット消費）", systemImage: "paperplane.fill")
                            .frame(maxWidth: .infinity)
                            .fontWeight(.semibold)
                    }
                    .buttonStyle(.borderedProminent)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                } else {
                    Button {
                        showPaywall = true
                    } label: {
                        Label("クレジットを追加する", systemImage: "star.circle")
                            .frame(maxWidth: .infinity)
                            .fontWeight(.semibold)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.yellow)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }
            }
        }
    }

    // MARK: - Loading Phase

    private var loadingView: some View {
        VStack(spacing: 20) {
            Spacer()
            ProgressView()
                .scaleEffect(1.5)
            Text("AIがステップ案を生成中...")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("通常10〜30秒かかります")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    // MARK: - Result Phase

    private var resultView: some View {
        List {
            Section {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("\(generatedSteps.count)件のステップ案が生成されました")
                        .font(.headline)
                }
            }

            Section("生成されたステップ") {
                ForEach(Array(generatedSteps.enumerated()), id: \.element.id) { index, step in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("\(index + 1).")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(width: 20)
                            Text(step.title)
                                .font(.body)
                        }
                        HStack(spacing: 12) {
                            Label("\(step.durationMin)分", systemImage: "clock")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(step.type)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(.secondary.opacity(0.15), in: RoundedRectangle(cornerRadius: 3))
                            if let notes = step.notes, !notes.isEmpty {
                                Text(notes)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        .padding(.leading, 28)
                    }
                }
            }

            Section {
                Button {
                    adoptSteps()
                    dismiss()
                } label: {
                    Label("このステップ案を採用する", systemImage: "checkmark.circle")
                        .frame(maxWidth: .infinity)
                        .fontWeight(.semibold)
                }
                .buttonStyle(.borderedProminent)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }
        }
    }

    // MARK: - Error Phase

    private var errorView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.orange)

            Text("生成に失敗しました")
                .font(.title3)
                .fontWeight(.semibold)

            if let errorMessage {
                Text(errorMessage)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Spacer()

            VStack(spacing: 12) {
                Button {
                    preparePreview()
                } label: {
                    Label("リトライ", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                        .fontWeight(.semibold)
                }
                .buttonStyle(.borderedProminent)

                if goal.category != nil {
                    Button {
                        fallbackToTemplate()
                        dismiss()
                    } label: {
                        Label("テンプレートで生成（フォールバック）", systemImage: "wand.and.stars")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }

                Button {
                    dismiss()
                } label: {
                    Text("閉じる")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
    }

    // MARK: - Logic

    private func preparePreview() {
        let noteText = goal.note ?? ""
        if aiAutoRedact && !noteText.isEmpty {
            redactionResult = Redactor.redact(noteText)
        } else {
            redactionResult = nil
        }

        previewPayload = AIRequestPayload(
            goalTitle: goal.title,
            goalNote: aiAutoRedact ? (redactionResult?.masked ?? goal.note) : goal.note,
            category: goal.category?.rawValue,
            constraints: nil
        )

        if aiConfirmBeforeSend {
            phase = .preview
        } else {
            Task { await sendRequest() }
        }
    }

    private func sendRequest() async {
        // Pre-check credits locally
        guard credits.canUseAI else {
            showPaywall = true
            return
        }

        phase = .loading
        isLoading = true
        errorMessage = nil

        let payload = previewPayload ?? AIRequestPayload(
            goalTitle: goal.title,
            goalNote: goal.note,
            category: goal.category?.rawValue,
            constraints: nil
        )

        // Consume one credit locally before sending
        credits.ensureWindowStarted()
        let consumed = credits.consumeOne()
        guard consumed else {
            showPaywall = true
            isLoading = false
            return
        }

        do {
            let result = try await AIService.generateSteps(
                payload: payload,
                endpointURL: aiEndpointURL,
                authToken: aiAuthToken
            )
            generatedSteps = result.steps
            // Sync remaining + verificationMethod from Proxy (M11/M12)
            if let remaining = result.remaining {
                credits.syncFromProxy(remaining: remaining, verificationMethod: result.verificationMethod)
            } else if let method = result.verificationMethod {
                credits.lastVerificationMethod = method
            }
            phase = .result
        } catch let error as AIServiceError {
            if case .creditsExhausted = error {
                showPaywall = true
                phase = .preview
            } else {
                // Checklist: 失敗時はテンプレ分解へフォールバック
                if goal.category != nil {
                    // Auto-fallback to template decomposition
                    fallbackToTemplate()
                    errorMessage = (error.errorDescription ?? "AI生成に失敗") + "\nテンプレートで自動生成しました"
                    BillingEventLog.shared.log(.error,
                        "AI failed, auto-fallback to template: \(error.errorDescription ?? "unknown")")
                    phase = .result
                } else {
                    errorMessage = error.errorDescription
                    phase = .error
                }
            }
        } catch {
            // Checklist: 失敗時はテンプレ分解へフォールバック
            if goal.category != nil {
                fallbackToTemplate()
                errorMessage = error.localizedDescription + "\nテンプレートで自動生成しました"
                BillingEventLog.shared.log(.error,
                    "AI failed, auto-fallback to template: \(error.localizedDescription)")
                phase = .result
            } else {
                errorMessage = error.localizedDescription
                phase = .error
            }
        }

        isLoading = false
    }

    private func adoptSteps() {
        let existingMax = goal.steps.map(\.sortOrder).max() ?? -1
        for (index, aiStep) in generatedSteps.enumerated() {
            let step = Step(
                title: aiStep.title,
                durationMin: aiStep.durationMin,
                type: .ai,
                sortOrder: existingMax + 1 + index
            )
            goal.steps.append(step)
        }
    }

    private func fallbackToTemplate() {
        guard let category = goal.category else { return }
        TemplateEngine.generateSteps(for: goal, category: category)
    }
}

#Preview {
    AIStepSheet(goal: Goal(title: "サンプルGoal", category: .travel, priority: .high))
        .modelContainer(for: Goal.self, inMemory: true)
}
