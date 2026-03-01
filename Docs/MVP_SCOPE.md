# MVPスコープ（Must / Should / Later）

## Must（MVPで必須）
- Goal CRUD（タイトル必須、カテゴリ任意、優先度、期限、メモ、画像）
- テンプレ分解：旅行/イベント/学習/健康/趣味（固定ロジックでStep生成）
- Plan（今週枠）：Stepを枠に入れる・外す
- 実行確認：期限/枠を過ぎたStepの Done / 延期 / 破棄
- 週次レビュー：未完了確認→Backlogから今週の1Goal選択→次の3Stepを今週枠へ

## Should（MVP後すぐ）
- Appleカレンダーへのイベント書き出し（EventKit）
- Appleリマインダーへのタスク書き出し
- 通知（週次レビュー通知、予定超過確認）

## Later
- CloudKit同期 / CloudKit Sharing（Goal単位共有）
- Pro課金（買い切り）
- バッジ/リング
