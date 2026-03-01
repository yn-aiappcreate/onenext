import SwiftUI

struct EmptyStateView: View {
    let title: String
    let systemImage: String
    let description: String

    var body: some View {
        ContentUnavailableView(
            title,
            systemImage: systemImage,
            description: Text(description)
        )
    }
}

#Preview {
    EmptyStateView(
        title: "Goalがありません",
        systemImage: "tray",
        description: "右上の＋ボタンからGoalを作成しましょう"
    )
}
