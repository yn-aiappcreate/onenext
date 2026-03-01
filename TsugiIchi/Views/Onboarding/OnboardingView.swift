import SwiftUI

struct OnboardingView: View {
    @Binding var hasCompletedOnboarding: Bool
    @State private var currentPage = 0

    private let pages: [(icon: String, title: String, description: String)] = [
        ("tray.full", "Backlog", "やりたいことをGoalとして登録。\nテンプレートからStepを自動生成できます。"),
        ("calendar", "Plan", "今週やるStepを選んで枠に配置。\n週10件まで集中して取り組めます。"),
        ("checkmark.circle", "Review", "週末に振り返り。\n完了・延期・破棄をワンタップで記録。"),
        ("gearshape", "Settings", "通知時間やデータエクスポートなど、\n自分好みにカスタマイズできます。"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $currentPage) {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                    VStack(spacing: 24) {
                        Spacer()

                        Image(systemName: page.icon)
                            .font(.system(size: 64))
                            .foregroundStyle(Color.accentColor)

                        Text(page.title)
                            .font(.title)
                            .fontWeight(.bold)

                        Text(page.description)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)

                        Spacer()
                    }
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))

            Button {
                if currentPage < pages.count - 1 {
                    withAnimation {
                        currentPage += 1
                    }
                } else {
                    hasCompletedOnboarding = true
                }
            } label: {
                Text(currentPage < pages.count - 1 ? "次へ" : "はじめる")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)

            if currentPage < pages.count - 1 {
                Button("スキップ") {
                    hasCompletedOnboarding = true
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.bottom, 24)
            } else {
                Spacer()
                    .frame(height: 48)
            }
        }
    }
}

#Preview {
    OnboardingView(hasCompletedOnboarding: .constant(false))
}
