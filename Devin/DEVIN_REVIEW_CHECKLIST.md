# Devin PRレビュー観点（人間が見るポイント）

- Must要件が全部満たされているか（Docs/ACCEPTANCE_TESTS.md）
- 画面が4タブ構成になっているか（Backlog/Plan/Review/Settings）
- 60秒予定化の導線が最短になっているか（余計な画面遷移がない）
- テンプレ分解が固定ロジックで安定しているか（AI禁止）
- データ永続化が壊れないか（SwiftData）
- iOS権限（写真/通知）説明文がInfo.plistにあるか
- エラー時にクラッシュしないか（nil/権限拒否/空データ）
