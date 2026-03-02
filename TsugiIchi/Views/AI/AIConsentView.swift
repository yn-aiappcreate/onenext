import SwiftUI

/// First-time consent modal shown before any AI data is sent.
struct AIConsentView: View {
    let onConsent: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "cpu")
                .font(.system(size: 48))
                .foregroundStyle(Color.accentColor)

            Text("AIアシストについて")
                .font(.title2)
                .fontWeight(.bold)

            VStack(alignment: .leading, spacing: 16) {
                Text("このGoalの情報を外部AIサービスに送信してStep案を生成します。")
                    .font(.body)

                VStack(alignment: .leading, spacing: 8) {
                    Label("送信されるデータ", systemImage: "doc.text")
                        .font(.headline)
                        .padding(.bottom, 2)
                    bulletItem("Goalのタイトル")
                    bulletItem("メモ（入力されている場合）")
                    bulletItem("カテゴリ（設定されている場合）")
                }

                VStack(alignment: .leading, spacing: 8) {
                    Label("送信されないデータ", systemImage: "lock.shield")
                        .font(.headline)
                        .padding(.bottom, 2)
                    bulletItem("位置情報・連絡先は送信しません")
                    bulletItem("個人情報は自動マスク（設定でON/OFF可）")
                }

                VStack(alignment: .leading, spacing: 8) {
                    Label("提供元", systemImage: "server.rack")
                        .font(.headline)
                        .padding(.bottom, 2)
                    Text("設定画面で指定したプロキシサーバー経由でAI APIに接続します。APIキーはアプリに埋め込まれていません。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal)

            Spacer()

            VStack(spacing: 12) {
                Button {
                    onConsent()
                } label: {
                    Text("同意して利用する")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button {
                    onCancel()
                } label: {
                    Text("キャンセル")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 32)
    }

    @ViewBuilder
    private func bulletItem(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("・")
                .foregroundStyle(.secondary)
            Text(text)
                .font(.subheadline)
        }
    }
}

#Preview {
    AIConsentView(onConsent: {}, onCancel: {})
}
