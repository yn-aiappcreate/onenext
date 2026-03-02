# ツギイチ 課金仕様 v1.0（Proサブスク + AI追加パック）

目的：
- AI（ステップ分解）の運用コストを回収しつつ、無料でも価値体験できるようにする
- 不正/濫用でOpenAI費用が爆発しないよう Proxy 側で回数制御する

---

## プラン
### Free（無料）
- 基本機能：Goal / Step / Plan（今週枠）/ Review（週次レビュー）
- AI分解：無料枠「10回 / 30日」（ローリング30日）
- AIが使えないとき：テンプレ分解にフォールバック（常に利用可能）

### Pro（月額サブスク）
- 価格：¥300 / 月（初期）
- AI分解：300回 / 30日（ローリング30日）
- Pro特典：カレンダー/リマインダー書き出し（後で実装でもOK）
- Proでも回数は上限あり（濫用で原価が死なないため）

### AI追加パック（消耗型IAP）
- 価格：¥300（1回購入）
- 追加AIクレジット：+300回
- 有効期限：なし（Proが切れても保持）
- 消費順：月次枠（Free/Pro）→ 追加パック（購入分）

---

## 商品ID（App Store Connectで作成する）
| 種別 | Product ID | 備考 |
|---|---|---|
| サブスク（月額） | tsugiichi.pro.monthly | 自動更新 |
| 消耗型 | tsugiichi.ai.pack300 | +300回 |

※将来の上位プランは later（例 tsugiichi.proplus.monthly）

---

## AIクレジットの定義
- credit = 「AI分解 1回」
- AI分解は必ずユーザー操作（ボタン）で実行する
- 1回の生成は steps 3〜8、JSONのみ（出力を短く固定）

---

## 30日ウィンドウ（ローリング方式）
- Free：最初にAIを使った時刻を起点に 30日
- Pro：最初にProが有効になった時刻（or 更新時刻）を起点に 30日
- 追加パック：期限なし

---

## 課金の解放条件（端末側）
- Proの判定：StoreKit2の currentEntitlements / subscriptionStatus で isPro を判定
- 追加パック：StoreKit2の transaction（購入イベント）で local creditsPurchased を加算

---

## Proxy側の回数制御（必須）
理由：iOS側だけで回数を制御すると、改造/再インストールで無限化するため。
Proxyは以下を行う：
- clientId（端末固有ID）をKeychainに保存し、全APIリクエストで送る
- proxyは clientId 単位で回数・レート制限を実施
- Proのときは「Pro枠 300/30日」を適用（端末からの isPro 申告だけに依存せず、最低限の防御を入れる）
  - MVPは “isPro申告を一旦信じる” でも可（ただしIP/日次上限を強めに）
  - Harden版は App Store Server API でサーバ側検証する（後述）

---

## 返却仕様（Proxy）
- /generate-steps のレスポンスに remaining を含める
- iOSは remaining を表示できるようにする
