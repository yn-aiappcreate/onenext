# ツギイチ AI Proxy セットアップガイド

ツギイチアプリのAIステップ生成機能は、**自前のプロキシサーバー**を経由してAI APIを呼び出します。
APIキーはアプリに埋め込まず、Proxy側で保持します。

## アーキテクチャ

```
┌──────────────┐     POST /generate-steps     ┌───────────────────┐     Chat API     ┌──────────┐
│  ツギイチ App │  ───────────────────────────▶ │ Cloudflare Worker │ ──────────────▶  │ OpenAI   │
│  (iOS)       │  ◀─────────────────────────── │ (Proxy)           │ ◀──────────────  │ API      │
└──────────────┘     JSON { steps: [...] }     └───────────────────┘                  └──────────┘
```

- アプリはGoal情報のみをProxyに送信
- ProxyがOpenAI APIキーを付与してリクエストを転送
- レスポンスはJSON固定フォーマット（余計な文を含まない）

## 前提条件

- [Node.js](https://nodejs.org/) v18+
- [Cloudflare アカウント](https://dash.cloudflare.com/sign-up)（無料プランでOK）
- [OpenAI API キー](https://platform.openai.com/api-keys)

## セットアップ手順

### 1. 依存パッケージをインストール

```bash
cd Server/cloudflare-worker
npm install
```

### 2. Wrangler にログイン

```bash
npx wrangler login
```

ブラウザが開くので、Cloudflareアカウントで認証してください。

### 3. OpenAI APIキーを設定（秘密鍵）

```bash
npx wrangler secret put OPENAI_API_KEY
```

プロンプトが表示されたら、OpenAI APIキー（`sk-...`）を入力してください。

> **重要**: APIキーは `wrangler.toml` やソースコードに**絶対に書かない**でください。
> `wrangler secret` で設定した値はCloudflareのシークレットストアに暗号化保存されます。

### 3.5 認証トークンを設定（推奨）

```bash
npx wrangler secret put API_AUTH_TOKEN
```

任意のランダム文字列を入力してください。例:
```bash
openssl rand -hex 32
```

> **なぜ必要？**: 認証トークンを設定すると、WorkerはBearerトークンが一致するリクエストのみ受け付けます。
> URLが漏れても、トークンを知らない第三者はOpenAI APIクレジットを消費できません。
> 設定しない場合は認証なし（レート制限のみ）で動作します。

### 4. デプロイ

```bash
npx wrangler deploy
```

デプロイ完了後、以下のようなURLが表示されます:

```
Published tsugiichi-ai-proxy (x.xx sec)
  https://tsugiichi-ai-proxy.<your-subdomain>.workers.dev
```

このURLをメモしてください。

### 5. 動作確認

```bash
curl -X POST https://tsugiichi-ai-proxy.<your-subdomain>.workers.dev/generate-steps \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <あなたのトークン>" \
  -d '{"goalTitle": "沖縄旅行の計画を立てる"}'
```

正常なレスポンス例:
```json
{
  "steps": [
    {
      "title": "沖縄の観光スポットを調べる",
      "type": "調べる",
      "durationMin": 15,
      "dueSuggestion": "today",
      "notes": "まずは定番スポットをリストアップ"
    },
    ...
  ]
}
```

## ツギイチ側の設定

### iOS アプリでProxy URLを設定

1. ツギイチアプリを開く
2. **設定タブ** → **AIアシスト** セクション
3. **エンドポイントURL（Proxy）** に、デプロイしたWorkerのURLを入力:
   ```
   https://tsugiichi-ai-proxy.<your-subdomain>.workers.dev
   ```
4. **認証トークン（任意）** に、ステップ3.5で設定したトークンを入力
5. これで「AIでステップ案を作る」ボタンが動作します

## 環境変数一覧

### シークレット（`wrangler secret put` で設定）

| 変数名 | 必須 | 説明 |
|--------|------|------|
| `OPENAI_API_KEY` | Yes | OpenAI APIキー（`sk-...`） |
| `API_AUTH_TOKEN` | 推奨 | Bearer認証トークン（未設定時は認証なし） |

### 環境変数（`wrangler.toml` の `[vars]` で設定）

| 変数名 | デフォルト | 説明 |
|--------|-----------|------|
| `OPENAI_MODEL` | `gpt-4o-mini` | 使用するOpenAIモデル |
| `MAX_INPUT_LENGTH` | `2000` | 入力テキストの最大文字数 |
| `RATE_LIMIT_PER_MINUTE` | `10` | IPあたりの1分間リクエスト上限 |

## セキュリティ

### レート制限
- IPアドレスあたり **10リクエスト/分**（デフォルト）
- 超過時は `429 Too Many Requests` + `Retry-After` ヘッダーを返却

### 入力サイズ制限
- goalTitle + goalNote + category + constraints の合計が **2000文字**（デフォルト）を超えると `400 Bad Request`

### Bearerトークン認証
- `API_AUTH_TOKEN` を設定すると、`Authorization: Bearer <token>` ヘッダーが必須になる
- URLが漏洩しても、トークンなしではAPIを利用できない
- 未設定時は認証なし（レート制限のみ）で動作

### CORSポリシー
- iOSネイティブアプリからの通信にはCORS不要のため、ワイルドカードは削除済み

## ローカル開発

```bash
cd Server/cloudflare-worker

# ローカルでAPI KEY を.dev.varsファイルに設定（.gitignoreされること）
echo "OPENAI_API_KEY=sk-your-key-here" > .dev.vars

# ローカルサーバー起動（http://localhost:8787）
npm run dev
```

> `.dev.vars` は `.gitignore` に追加して、リポジトリにコミットしないでください。

## トラブルシューティング

| エラー | 原因 | 対処 |
|--------|------|------|
| `401: Unauthorized` | 認証トークン不一致 | iOSの設定画面で正しいトークンを入力（Worker側の `API_AUTH_TOKEN` と一致させる） |
| `500: OPENAI_API_KEY not set` | シークレット未設定 | `wrangler secret put OPENAI_API_KEY` |
| `404: Not Found` | パスが間違い | `POST /generate-steps` を確認 |
| `400: goalTitle is required` | リクエストボディ不正 | JSON形式で `goalTitle` を含める |
| `400: Input too long` | 入力文字数超過 | テキストを短くする or `MAX_INPUT_LENGTH` を変更 |
| `429: Rate limit exceeded` | リクエスト過多 | `Retry-After` 秒待つ |
| `500: AI generation failed` | OpenAI APIエラー | ログを確認（`wrangler tail`） |
