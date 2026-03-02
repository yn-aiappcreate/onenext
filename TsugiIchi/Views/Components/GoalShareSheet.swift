import SwiftUI

struct GoalShareSheet: View {
    let goal: Goal
    @Environment(\.dismiss) private var dismiss

    private var shareText: String {
        let appName = "ツギイチ"
        let stepsCount = goal.steps.count
        let doneCount = goal.steps.filter { $0.status == .done }.count
        var text = "🎉 Goal達成！\n\n"
        text += "「\(goal.title)」を達成しました！\n"
        text += "✅ \(doneCount)/\(stepsCount) Steps完了\n"
        if let category = goal.category {
            text += "📂 カテゴリ: \(category.localizedName)\n"
        }
        text += "\n#\(appName) #Goal達成"
        return text
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Achievement card preview
                VStack(spacing: 16) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.yellow)

                    Text("Goal達成！")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text(goal.title)
                        .font(.headline)
                        .multilineTextAlignment(.center)

                    if let category = goal.category {
                        Label(category.localizedName, systemImage: category.systemImage)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("\(goal.steps.filter { $0.status == .done }.count)/\(goal.steps.count) Steps")
                            .font(.subheadline)
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemBackground))
                        .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
                )

                // Share text preview
                Text(shareText)
                    .font(.subheadline)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                Spacer()

                // Share button
                Button {
                    shareToSNS()
                } label: {
                    Label("シェアする", systemImage: "square.and.arrow.up")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .navigationTitle("Goal達成をシェア")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }

    private func shareToSNS() {
        let activityItems: [Any] = [shareText]
        let activityVC = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            // Handle iPad popover
            if let popover = activityVC.popoverPresentationController {
                popover.sourceView = rootVC.view
                popover.sourceRect = CGRect(
                    x: rootVC.view.bounds.midX,
                    y: rootVC.view.bounds.midY,
                    width: 0,
                    height: 0
                )
                popover.permittedArrowDirections = []
            }
            rootVC.present(activityVC, animated: true)
        }
    }
}

#Preview {
    GoalShareSheet(goal: Goal(title: "英語をマスターする", category: .learning, priority: .high))
}
