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
- **課金**: StoreKit 2 (Proサブスク + AIクレジットパック)
- **状態管理**: @Observable ViewModel + @Query
- **外部依存**: なし (SwiftUI + SwiftData + StoreKit 2 のみ)

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

## サブスクリプション / AIクレジット (IAP)

### 商品ID

| 商品ID | タイプ | 内容 |
|---|---|---|
| `tsugiichi.pro.monthly` | 自動更新サブスクリプション | Proプラン（AI 300回/30日） |
| `tsugiichi.ai.pack300` | 消耗型 | AI追加パック +300回（期限なし） |

### App Store Connect でのIAP作成手順

1. [App Store Connect](https://appstoreconnect.apple.com/) → アプリ → ツギイチ → **サブスクリプション**
2. **サブスクリプショングループを作成**: 名前=「TsugiIchi Pro」
3. **サブスクリプションを追加**:
   - 参照名: `tsugiichi.pro.monthly`
   - 期間: 1か月
   - ローカライズ: 「ツギイチ Pro」/ 「AIステップ生成 300回/月」
   - 価格を設定（例: ¥480/月）
4. **App内課金** → **消耗型を作成**:
   - 参照名: `tsugiichi.ai.pack300`
   - ローカライズ: 「AI追加パック」/ 「AIステップ生成 +300回」
   - 価格を設定（例: ¥240）
5. 両方のステータスが **「完了」** または **「審査待ち」** になったことを確認

### Sandboxテスト手順

1. **Sandboxテスターアカウント作成**:
   - App Store Connect → ユーザとアクセス → Sandbox → テスター → 「+」
   - テスト用のメールアドレスとパスワードを設定
2. **実機でテスト** (Sandboxはシミュレータ非対応):
   - Settings.app → App Store → 下部「SANDBOX ACCOUNT」にテスターでサインイン
   - またはアプリ内で購入ボタン押下時にSandboxアカウントでサインイン
3. **確認事項**:
   - Sandboxではサブスクの更新間隔が短縮されます（1か月 → 5分）
   - 購入後、設定画面で「Pro プラン利用中」と表示されることを確認
   - AI分解時にクレジット消費がカウントされることを確認
   - 「購入を復元」ボタンが動作することを確認

### AIクレジット仕様

| プラン | 月次枠 | リセットサイクル | 購入枠 |
|---|---|---|---|
| Free | 10回/30日 | 初回AI使用時からローリング | 不可 |
| Pro | 300回/30日 | Pro開始時からローリング | +300回/パック |

- 消費順：月次枠 → 購入枠（購入枠は期限なし）
- 枠切れ時はPaywall表示（テンプレート生成は常に可能）

## プロジェクト構成

```
TsugiIchi/
├── App/              # @main エントリポイント, ContentView (TabView)
├── Models/           # SwiftData モデル (Goal, Step, PlanSlot, ReviewLog, AIModels)
├── Views/            # タブごとの View (Backlog, Plan, Review, Settings, AI)
│   ├── AI/           # AIStepSheet, AIConsentView
│   └── Settings/     # SettingsTab, PaywallView
├── Services/         # TemplateEngine, AIService, BillingManager, EntitlementStore, CreditsStore
└── Utilities/        # DateHelper, Constants, ClientId
TsugiIchiTests/       # XCTest ユニットテスト
Docs/                 # PRD, MVP_SCOPE, ARCHITECTURE, BILLING_SPEC 等
```

## ライセンス

Private
