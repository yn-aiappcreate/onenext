# M12: Server-side Pro Verification — セットアップ手順

## 概要

M11 では iOS 端末の `X-Is-Pro` ヘッダー申告を信用していた（MVP）。
M12 では **Apple StoreKit 2 の署名済みトランザクション（JWS）** を Proxy が暗号検証し、
Pro サブスクリプションの有効性をサーバ側で判定する。

### 検証フロー

```
iOS (StoreKit 2)                      Proxy (Cloudflare Worker)
─────────────────                     ─────────────────────────
Transaction.currentEntitlements
  → VerificationResult<Transaction>
  → .jwsRepresentation (JWS string)
                                      ← X-Signed-Transaction ヘッダーで受信
                                      1. JWS ヘッダーの x5c 証明書チェーンを取得
                                      2. ルート証明書が Apple Root CA G3 か検証（SHA-256 fingerprint）
                                      3. リーフ証明書の公開鍵で JWS 署名を検証（ES256）
                                      4. ペイロードの productId / expiresDate / revocationDate を確認
                                      5. 有効な Pro → Pro 枠適用 / 無効 → Free 枠
```

### フォールバック

- `X-Signed-Transaction` ヘッダーが無い場合（旧バージョンのアプリ）は `X-Is-Pro` ヘッダーにフォールバック
- Proxy の `verificationMethod` レスポンスフィールドで検証方法を確認可能:
  - `apple_jws_verified`: Apple JWS 検証成功（Pro確定）
  - `apple_jws_expired`: Apple JWS 検証成功だがサブスク期限切れ
  - `cache`: 直近5分以内の検証結果キャッシュ
  - `header_fallback`: JWS なし、X-Is-Pro ヘッダーで判定

---

## 前提条件

1. **App Store Connect でサブスクリプションが作成済み**
   - Product ID: `tsugiichi.pro.monthly`（自動更新サブスクリプション）
   - README の「サブスクリプション / AIクレジット (IAP)」セクション参照

2. **Cloudflare Worker がデプロイ済み**（M11 の KV 含む）

3. **iOS アプリが StoreKit 2 を使用**（M10 で実装済み）

---

## Proxy 側の設定

### 1. 環境変数の確認

`wrangler.toml` に以下が設定されていること：

```toml
[vars]
BUNDLE_ID = "com.ynlabs.tsugiichi"
PRO_PRODUCT_ID = "tsugiichi.pro.monthly"
```

- `BUNDLE_ID`: App Store Connect で登録したアプリの Bundle ID
- `PRO_PRODUCT_ID`: Pro サブスクリプションの Product ID

### 2. デプロイ

```bash
cd Server/cloudflare-worker
npx wrangler deploy
```

### 3. 動作確認

デプロイ後、AI ステップ生成リクエストのレスポンスに `verificationMethod` フィールドが含まれる：

```json
{
  "steps": [...],
  "remaining": 299,
  "verificationMethod": "apple_jws_verified"
}
```

---

## iOS 側の変更（自動）

M12 の iOS 変更はコードに含まれており、追加設定不要：

- `EntitlementStore.refresh()` で Pro トランザクションの JWS を取得・保持
- `AIService.generateSteps()` で `X-Signed-Transaction` ヘッダーに JWS を送信
- Pro サブスクリプションが無い場合はヘッダーを送信しない（フォールバック動作）

---

## Apple 証明書について

### Apple Root CA - G3

Proxy は JWS の x5c 証明書チェーンのルート証明書が **Apple Root CA - G3** であることを SHA-256 フィンガープリントで検証する。

- **ダウンロード元**: https://www.apple.com/certificateauthority/
- **ファイル**: `AppleRootCA-G3.cer`
- **SHA-256 fingerprint**: `63343abfb89a6a03ebb57e9b3f5fa7be7c4fbe29f2d6d0867aaf3386ee76e358`
- **有効期限**: 2039-04-30
- **アルゴリズム**: ECDSA P-384

この証明書は Apple が発行する全ての StoreKit 2 トランザクション署名のルートとなる。
証明書が更新された場合（2039年以降）、`index.js` の `APPLE_ROOT_CA_G3_FINGERPRINT` を更新する必要がある。

### 証明書チェーン構造

```
Apple Root CA - G3 (self-signed, ECDSA P-384)
  └── Apple Worldwide Developer Relations Certification Authority (intermediate)
        └── Prod/Sandbox ECC Apple App Store (leaf, ECDSA P-256)
              └── JWS 署名
```

---

## Sandbox テスト

### テスト手順

1. Sandbox テスターアカウントで Pro サブスクリプションを購入
2. AI ステップ生成を実行
3. レスポンスの `verificationMethod` が `apple_jws_verified` であることを確認
4. サブスクを解約し、期限切れ後に `verificationMethod` が `header_fallback` または `apple_jws_expired` になることを確認

### Sandbox 環境の注意点

- Sandbox のトランザクションも同じ証明書チェーン（Apple Root CA G3）で署名される
- トランザクションペイロードの `environment` フィールドが `"Sandbox"` になる
- サブスクの更新間隔が短縮される（1か月 → 約5分）

---

## セキュリティ考慮事項

### 保護されるもの

- **Pro 枠の不正利用**: 改造クライアントが `X-Is-Pro: true` を送信しても、`X-Signed-Transaction` が無ければ Free 枠にフォールバック
- **JWS 偽造**: Apple の秘密鍵なしでは有効な JWS を生成できない
- **証明書チェーン偽装**: ルート証明書の SHA-256 フィンガープリントで Apple Root CA G3 を検証

### 残存リスク

1. **旧バージョンのアプリ**: JWS を送信しないため `X-Is-Pro` フォールバックが効く。日次上限 + IP レート制限で被害を抑制
2. **インメモリキャッシュ**: Worker のアイソレート間でキャッシュは共有されない。各アイソレートで最初のリクエスト時に検証が走る
3. **中間証明書チェーンの完全検証なし**: リーフ → 中間 → ルートの署名チェーンは検証していない（ルートの fingerprint 一致 + リーフ公開鍵での JWS 署名検証のみ）。フルチェーン検証が必要な場合は後日対応

### 将来の強化（M12+）

- 中間証明書の署名検証（リーフ cert がルートから正しくチェーンされているか）
- `X-Is-Pro` フォールバックの段階的廃止（アプリの最小バージョンを上げた後）
- App Store Server Notifications v2 でサブスク変更をリアルタイム受信
