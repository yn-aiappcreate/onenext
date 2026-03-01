# ツギイチ (TsugiIchi)

**やりたいことを「次の一手」と「予定」に変換して放置を防ぐ** iOS アプリ。

## 要件

- iOS 17.0+
- Xcode 15.2+
- Swift 5.9+

## ローカル実行手順

1. リポジトリをクローン

```bash
git clone https://github.com/yn-aiappcreate/onenext.git
cd onenext
```

2. Xcode でプロジェクトを開く

```bash
open TsugiIchi.xcodeproj
```

3. シミュレータを選択して Run (⌘R)

- 推奨: iPhone 15 / iPhone 16 (iOS 17+)

## Bundle ID の変更

Bundle ID は `com.ynlabs.tsugiichi` を使用します（必要なら任意の値に変更してください）。
以下の箇所を自分のドメインに置換してください：

- `generate_pbxproj.py` 内の `com.ynlabs.tsugiichi` および `com.ynlabs.TsugiIchiTests`
- 置換後、`python3 generate_pbxproj.py` を実行して `TsugiIchi.xcodeproj/project.pbxproj` を再生成

## Xcode Cloud でビルドして実機テスト

1. Xcode で `TsugiIchi.xcodeproj` を開く
2. Target "TsugiIchi" → Signing & Capabilities で Team を選択（Bundle ID が App Store Connect のアプリと一致していること）
3. Xcode: Product → Xcode Cloud → Create Workflow
4. Workflow の Actions に "Test"（任意）と "Archive"（TestFlight へ配布）を設定
5. ビルド完了後、TestFlight から実機にインストール

## テスト実行

Xcode から:
- Product → Test (⌘U)

コマンドラインから:
```bash
xcodebuild test \
  -scheme TsugiIchi \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO
```

## アーキテクチャ

- **UI**: SwiftUI (TabView 4タブ: Backlog / Plan / Review / Settings)
- **永続化**: SwiftData (Goal, Step, PlanSlot, ReviewLog)
- **状態管理**: @Observable ViewModel + @Query
- **外部依存**: なし (SwiftUI + SwiftData のみ)

## プロジェクト構成

```
TsugiIchi/
├── App/              # @main エントリポイント, ContentView (TabView)
├── Models/           # SwiftData モデル (Goal, Step, PlanSlot, ReviewLog)
├── Views/            # タブごとの View (Backlog, Plan, Review, Settings)
├── Services/         # TemplateEngine (固定ロジック Step 生成)
└── Utilities/        # DateHelper, Constants
TsugiIchiTests/       # XCTest ユニットテスト
Docs/                 # PRD, MVP_SCOPE, ARCHITECTURE 等
```

## ライセンス

Private
