# Devin Master Prompt（最初の1回で必ず読むこと）

あなたはiOSエンジニアとして、Docs/ 以下の仕様に従ってアプリを実装してください。
AI/LLM機能は禁止。テンプレ分解は固定ロジックのみ。

## 進め方
1) まず Ask モード相当で、実装計画とファイル構成とCIを提案
2) その後 Agent として、マイルストーン単位でPRを作成する
3) PRごとに「受け入れ条件（Docs/ACCEPTANCE_TESTS.md）」を満たす証拠（スクショ or 簡単な動画の代替としてログ）をPR本文に書く

## 重要制約
- 個人開発。過剰設計禁止。MVP優先。
- 依存ライブラリは最小。SwiftUI/SwiftData中心。
- 例外や権限拒否でもクラッシュしない。

## 成果物
- 動くiOSアプリ（iOS 17+）
- GitHub Actionsで `xcodebuild test` が通る（可能なら）
- READMEにセットアップ手順
