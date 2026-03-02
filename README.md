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

## AIアシスト（Step分解）

Goal詳細画面から「AIでステップ案を作る」をタップすると、外部AIサービスを使ってStep案（3〜8件）を自動生成できます。

### Proxyの必要性

**APIキーはアプリに埋め込みません**。アプリは設定画面で指定した「プロキシサーバーURL」にPOSTリクエストを送り、Proxyがバックエンド側でAPIキーを付与してAI APIを呼び出します。

推奨構成:
- **Cloudflare Workers** / **Vercel Edge Functions** / **AWS Lambda** 等の軽量Proxy
- Proxyが `POST /generate-steps` を受け取り、OpenAI等のAPIに転送
- レスポンスは `{ "steps": [...] }` のJSON固定フォーマット

設定画面の「エンドポイントURL（Proxy）」にProxyのURLを入力してください。デフォルトはダミーURL（`https://your-proxy.example.com`）です。

### 同意の設計

- 初回AI実行前に**必ず同意モーダル**を表示（送信先・送信データ種別・提供元を明示）
- 同意なしではデータ送信しない
- 同意フラグは `@AppStorage("aiConsentGiven")` で永続化
- 設定画面から同意をリセット可能
- 送信前にプレビュー画面でデータを確認可能（デフォルトON）
- メール/電話/郵便番号の自動マスク（デフォルトON、設定でOFF可能）

### App Privacy更新が必要

App Store Connect の「App Privacy」で以下の申告が必要です:
- **収集するデータ**: Goalのタイトル、メモ（テキスト）
- **使用目的**: App Functionality（アプリ機能の提供）
- **サードパーティ共有**: あり（AI APIプロバイダ）
- **位置情報・連絡先**: 収集しない

## プロジェクト構成

```
TsugiIchi/
├── App/              # @main エントリポイント, ContentView (TabView)
├── Models/           # SwiftData モデル (Goal, Step, PlanSlot, ReviewLog, AIModels)
├── Views/            # タブごとの View (Backlog, Plan, Review, Settings, AI)
│   └── AI/           # AIStepSheet, AIConsentView
├── Services/         # TemplateEngine, AIService, Redactor, NotificationManager
└── Utilities/        # DateHelper, Constants
TsugiIchiTests/       # XCTest ユニットテスト
Docs/                 # PRD, MVP_SCOPE, ARCHITECTURE, AI_ASSIST_SPEC 等
```

## ライセンス

Private
