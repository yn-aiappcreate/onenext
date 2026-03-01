# OneNext 実装計画 (M0〜M5)

> 制約: AI/LLM禁止 ・ 依存ライブラリ最小 ・ MVP優先 ・ iOS 17+ / SwiftUI / SwiftData

---

## 1. ディレクトリ構成（Xcode Project 含む）

```
onenext/
├── Docs/                          # 仕様ドキュメント（既存）
├── Devin/                         # Devin 運用ドキュメント（既存）
├── .github/
│   ├── pull_request_template.md
│   └── workflows/ci.yml
│
├── OneNext/                       # ← Xcode Project Root
│   ├── OneNext.xcodeproj
│   │
│   ├── App/
│   │   ├── OneNextApp.swift       # @main エントリポイント
│   │   ├── ContentView.swift      # TabView (Backlog/Plan/Review/Settings)
│   │   └── Assets.xcassets
│   │
│   ├── Models/                    # SwiftData モデル
│   │   ├── Goal.swift
│   │   ├── Step.swift
│   │   ├── PlanSlot.swift
│   │   └── ReviewLog.swift
│   │
│   ├── ViewModels/                # @Observable ViewModel
│   │   ├── BacklogViewModel.swift
│   │   ├── PlanViewModel.swift
│   │   ├── ReviewViewModel.swift
│   │   └── SettingsViewModel.swift
│   │
│   ├── Views/
│   │   ├── Backlog/
│   │   │   ├── BacklogTab.swift         # Goal 一覧
│   │   │   ├── GoalDetailView.swift     # Goal 詳細 + Step 一覧
│   │   │   ├── GoalFormSheet.swift      # Goal 作成/編集シート
│   │   │   └── StepRow.swift            # Step 行コンポーネント
│   │   │
│   │   ├── Plan/
│   │   │   ├── PlanTab.swift            # 今週枠一覧
│   │   │   └── PlanSlotRow.swift        # スロット行
│   │   │
│   │   ├── Review/
│   │   │   ├── ReviewTab.swift          # 週次レビュー画面
│   │   │   ├── PendingStepList.swift    # 未完了 Step 確認
│   │   │   └── GoalPickerSheet.swift    # 今週の1Goal 選択
│   │   │
│   │   ├── Settings/
│   │   │   └── SettingsTab.swift
│   │   │
│   │   └── Components/                  # 共通UIコンポーネント
│   │       ├── CategoryBadge.swift
│   │       ├── PriorityIndicator.swift
│   │       └── EmptyStateView.swift
│   │
│   ├── Services/
│   │   ├── TemplateEngine.swift         # 固定ロジックの Step 生成
│   │   ├── PlanService.swift            # 今週枠の管理ロジック
│   │   ├── ReviewService.swift          # 週次レビューロジック
│   │   └── NotificationService.swift    # UNUserNotificationCenter
│   │
│   ├── Utilities/
│   │   ├── DateHelper.swift             # 週番号・期限計算
│   │   └── Constants.swift              # 定数
│   │
│   └── Info.plist
│
├── OneNextTests/                  # ユニットテスト
│   ├── TemplateEngineTests.swift
│   ├── PlanServiceTests.swift
│   ├── ReviewServiceTests.swift
│   └── ModelTests.swift
│
├── OneNextUITests/                # UIテスト（後から追加可）
│
├── README.md
└── .gitignore
```

### ポイント
- **Xcode プロジェクト名**: `OneNext`（scheme名も `OneNext`）
- **CI の scheme**: `OneNext`（ci.yml の `-scheme DoNext` → `-scheme OneNext` に修正）
- **フォルダ参照**: Xcode の Group = 実ファイルシステムのフォルダ（Group with Folder を使用）
- **外部ライブラリ**: 原則ゼロ。xcpretty は CI のみ（`brew install xcpretty` or `gem`）

---

## 2. SwiftData モデル定義案

### Goal（やりたいこと）
```swift
import SwiftData
import Foundation

@Model
final class Goal {
    @Attribute(.unique) var id: UUID
    var title: String                          // 必須
    var category: GoalCategory?                // 任意（旅行/イベント/学習/健康/趣味）
    var priority: GoalPriority                 // .high / .medium / .low
    var dueDate: Date?                         // 任意
    var note: String?                          // メモ
    @Attribute(.externalStorage) var imageData: Data?  // 画像（大きいので外部保存）
    var status: GoalStatus                     // .active / .completed / .archived
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \Step.goal)
    var steps: [Step] = []

    init(title: String, category: GoalCategory? = nil,
         priority: GoalPriority = .medium, dueDate: Date? = nil,
         note: String? = nil, imageData: Data? = nil) {
        self.id = UUID()
        self.title = title
        self.category = category
        self.priority = priority
        self.dueDate = dueDate
        self.note = note
        self.imageData = imageData
        self.status = .active
        self.createdAt = Date()
    }
}

enum GoalCategory: String, Codable, CaseIterable {
    case travel   = "旅行"
    case event    = "イベント"
    case learning = "学習"
    case health   = "健康"
    case hobby    = "趣味"
}

enum GoalPriority: Int, Codable, CaseIterable, Comparable {
    case low = 0, medium = 1, high = 2
    static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
    var label: String {
        switch self {
        case .low: "低"
        case .medium: "中"
        case .high: "高"
        }
    }
}

enum GoalStatus: String, Codable {
    case active, completed, archived
}
```

### Step（次の一手）
```swift
@Model
final class Step {
    @Attribute(.unique) var id: UUID
    var title: String
    var durationMin: Int                      // 予想所要分
    var dueDate: Date?                        // 個別期限（任意）
    var type: StepType                        // .auto（テンプレ生成）/ .manual
    var status: StepStatus                    // .pending / .scheduled / .done / .postponed / .discarded
    var sortOrder: Int                        // Goal 内の並び順
    var scheduledAt: Date?                    // 今週枠に入った日時

    var goal: Goal?                           // 親 Goal

    init(title: String, durationMin: Int = 30,
         type: StepType = .auto, sortOrder: Int = 0) {
        self.id = UUID()
        self.title = title
        self.durationMin = durationMin
        self.type = type
        self.status = .pending
        self.sortOrder = sortOrder
    }
}

enum StepType: String, Codable {
    case auto    // テンプレ分解で生成
    case manual  // ユーザー手動追加
}

enum StepStatus: String, Codable {
    case pending     // 未着手
    case scheduled   // 今週枠に入っている
    case done        // 完了
    case postponed   // 延期
    case discarded   // 破棄
}
```

### PlanSlot（今週枠）
```swift
@Model
final class PlanSlot {
    @Attribute(.unique) var id: UUID
    var weekId: String                        // "2026-W09" 形式
    var index: Int                            // 枠内の並び順
    var startAt: Date?                        // 予定開始（任意）
    var endAt: Date?                          // 予定終了（任意）

    @Relationship var step: Step?             // 紐づく Step（nil = 空スロット）

    init(weekId: String, index: Int, step: Step? = nil) {
        self.id = UUID()
        self.weekId = weekId
        self.index = index
        self.step = step
    }
}
```

### ReviewLog（週次レビュー記録）
```swift
@Model
final class ReviewLog {
    @Attribute(.unique) var id: UUID
    var weekId: String                        // "2026-W09"
    var reviewedAt: Date
    var selectedGoalId: UUID?                 // 今週の1Goal
    var note: String?                         // 振り返りメモ

    init(weekId: String) {
        self.id = UUID()
        self.weekId = weekId
        self.reviewedAt = Date()
    }
}
```

### 設計判断
| 判断 | 理由 |
|------|------|
| enum は `String`/`Int` rawValue + `Codable` | SwiftData が自動保存可能 |
| `imageData` に `@Attribute(.externalStorage)` | 画像データが大きくなるため外部ストレージ |
| `Goal → Step` は `@Relationship(deleteRule: .cascade)` | Goal 削除時に Step も削除 |
| `PlanSlot → Step` は cascade なし | 枠を消しても Step は残す（Backlog に戻る） |
| `weekId` は ISO 8601 週番号文字列 | 週単位のフィルタが容易 |

---

## 3. 主要画面の遷移と状態管理方針

### タブ構成（ContentView = TabView）
```
┌─────────────────────────────────────────────┐
│  TabView                                     │
│  ┌──────┐ ┌──────┐ ┌──────┐ ┌──────────┐   │
│  │Backlog│ │ Plan │ │Review│ │ Settings │   │
│  └──┬───┘ └──┬───┘ └──┬───┘ └──────────┘   │
└─────┼────────┼────────┼─────────────────────┘
      │        │        │
      ▼        │        │
 GoalList      │        │
   │ tap       │        │
   ▼           │        │
 GoalDetail    │        │
   │ +Step     │        │
   ▼           │        │
 GoalForm      │        │
  (sheet)      │        │
               ▼        │
          PlanSlotList   │
            │ tap       │
            ▼           │
          StepPicker    │
           (sheet)      │
                        ▼
                   ReviewFlow
                   ├→ PendingStepList
                   ├→ GoalPicker (sheet)
                   └→ 確認 → 3Step自動配置
```

### 画面遷移詳細

| 画面 | 遷移元 | 遷移方法 | 内容 |
|------|--------|----------|------|
| **BacklogTab** | タブ | Tab | Goal 一覧（`@Query` で取得） |
| **GoalDetailView** | BacklogTab | `NavigationLink` | Goal 詳細 + Step リスト |
| **GoalFormSheet** | BacklogTab / GoalDetail | `.sheet` | Goal 作成・編集 |
| **TemplatePickerSheet** | GoalForm（保存直後） | `.sheet` | カテゴリに応じたテンプレ選択 → Step 生成 |
| **PlanTab** | タブ | Tab | 今週の PlanSlot 一覧 |
| **StepPickerSheet** | PlanTab | `.sheet` | Backlog から Step を選んで枠に入れる |
| **ReviewTab** | タブ | Tab | 週次レビューフロー |
| **GoalPickerSheet** | ReviewTab | `.sheet` | Backlog から今週の 1Goal を選択 |
| **SettingsTab** | タブ | Tab | 設定画面 |

### 状態管理方針

```
┌─────────────────────────────────────────────┐
│  SwiftData ModelContainer                    │
│  (OneNextApp で生成、.modelContainer() で注入)  │
└─────────────┬───────────────────────────────┘
              │ @Environment(\.modelContext)
              ▼
┌─────────────────────────────────────────────┐
│  @Observable ViewModel (各タブに1つ)          │
│                                              │
│  BacklogViewModel                            │
│    - goals: [Goal]      ← @Query で取得       │
│    - addGoal() / deleteGoal() / updateGoal() │
│                                              │
│  PlanViewModel                               │
│    - currentWeekId: String                   │
│    - slots: [PlanSlot]  ← @Query(filter:)    │
│    - scheduleStep() / unscheduleStep()       │
│                                              │
│  ReviewViewModel                             │
│    - pendingSteps: [Step] ← @Query(filter:)  │
│    - selectGoalForWeek()                     │
│    - autoPlaceNext3Steps()                   │
└─────────────────────────────────────────────┘
```

**方針まとめ:**
1. **ModelContainer** は `OneNextApp.swift` で1箇所だけ生成し `.modelContainer()` で全 View に注入
2. **@Query** を View 内で直接使い、リストの取得はSwiftDataに任せる（シンプルな画面はViewModelなしで `@Query` 直接でもOK）
3. **@Observable ViewModel** は複雑なビジネスロジック（テンプレ生成、レビューフロー）のある画面で使う
4. **画面間のデータ受け渡し** は `NavigationPath` + SwiftData の `PersistentIdentifier` で行う（Goalオブジェクト自体を渡さない → スレッド安全）
5. **副作用（通知・カレンダー）** は `Service` クラスに分離し、ViewModel から呼ぶ

---

## 4. 最初のPR（M0）で入れる内容

### M0: Repo Scaffold + CI

**目的:** ビルド・テストが通る空のXcodeプロジェクトと CI を整備し、以後のマイルストーンの土台を作る。

#### M0 に含めるファイル

```
OneNext/
├── OneNext.xcodeproj              # Xcode プロジェクト（iOS 17, SwiftUI lifecycle）
├── App/
│   ├── OneNextApp.swift           # @main + ModelContainer 設定
│   ├── ContentView.swift          # TabView（4タブの空スタブ）
│   └── Assets.xcassets            # AppIcon placeholder
├── Models/
│   ├── Goal.swift                 # SwiftData @Model（フル定義）
│   ├── Step.swift                 # SwiftData @Model（フル定義）
│   ├── PlanSlot.swift             # SwiftData @Model（フル定義）
│   └── ReviewLog.swift            # SwiftData @Model（フル定義）
├── Views/
│   ├── Backlog/BacklogTab.swift   # "Backlog" Text() のみ
│   ├── Plan/PlanTab.swift         # "Plan" Text() のみ
│   ├── Review/ReviewTab.swift     # "Review" Text() のみ
│   └── Settings/SettingsTab.swift # "Settings" Text() のみ
├── Services/
│   └── TemplateEngine.swift       # テンプレ定義のみ（呼び出しはM2）
├── Utilities/
│   ├── DateHelper.swift           # weekId 生成ヘルパー
│   └── Constants.swift
└── Info.plist                     # カメラ/写真/通知の UsageDescription

OneNextTests/
├── ModelTests.swift               # Goal/Step の生成・関連テスト
└── TemplateEngineTests.swift      # テンプレの出力件数テスト

.github/
└── workflows/ci.yml              # scheme名を "OneNext" に修正

.gitignore                         # Xcode / Swift 用
README.md                          # セットアップ手順
```

#### M0 の受け入れ条件
- [ ] `xcodebuild -scheme OneNext build` が成功する
- [ ] `xcodebuild -scheme OneNext test` が成功する（ModelTests + TemplateEngineTests）
- [ ] GitHub Actions CI が green になる
- [ ] シミュレータで4タブが表示される
- [ ] SwiftData の ModelContainer がクラッシュせず起動する

#### CI (ci.yml) 修正内容
```yaml
name: iOS CI

on:
  pull_request:
  push:
    branches: [main]

jobs:
  build-and-test:
    runs-on: macos-14          # M1 runner（Xcode 15+ プリインストール）
    steps:
      - uses: actions/checkout@v4
      - name: Select Xcode
        run: sudo xcode-select -s /Applications/Xcode_15.4.app/Contents/Developer
      - name: Build
        run: |
          xcodebuild -scheme OneNext \
            -destination 'platform=iOS Simulator,name=iPhone 15' \
            build | xcpretty
      - name: Test
        run: |
          xcodebuild -scheme OneNext \
            -destination 'platform=iOS Simulator,name=iPhone 15' \
            test | xcpretty
```

---

## 5. M1〜M5 マイルストーン詳細

### M1: DataModel + Backlog UI + CRUD
**目的:** Goal の作成・表示・編集・削除ができる Backlog タブを完成させる

| タスク | ファイル |
|--------|----------|
| BacklogTab に `@Query var goals` + `List` + `NavigationStack` | `Views/Backlog/BacklogTab.swift` |
| GoalFormSheet（タイトル/カテゴリ/優先度/期限/メモ/画像） | `Views/Backlog/GoalFormSheet.swift` |
| GoalDetailView（Goal 情報 + Step リスト） | `Views/Backlog/GoalDetailView.swift` |
| Goal 削除（スワイプ） | BacklogTab |
| 空状態の EmptyStateView | `Views/Components/EmptyStateView.swift` |
| 画像添付（PhotosPicker） | GoalFormSheet 内 |

**受け入れ:** Goal を作成・編集・削除できる。アプリ再起動後もデータが残る。

### M2: Template Engine + Step 生成 UI
**目的:** Goal 作成後にカテゴリに応じた固定ロジックで Step を自動生成する

| タスク | ファイル |
|--------|----------|
| `TemplateEngine.generate(category:) -> [StepTemplate]` の実装 | `Services/TemplateEngine.swift` |
| テンプレ 5種（旅行/イベント/学習/健康/趣味）各3〜8件 | 同上 |
| Goal 保存後に TemplatePickerSheet を表示 | `Views/Backlog/GoalFormSheet.swift` |
| 生成された Step を GoalDetailView に表示 | `Views/Backlog/GoalDetailView.swift` |
| Step の手動追加/編集/削除 | `Views/Backlog/StepRow.swift` |
| TemplateEngineTests 拡充 | `OneNextTests/` |

**受け入れ:** テンプレを選ぶと Step が 3〜8件生成される。手動で Step を追加/削除できる。

### M3: Plan（今週枠）+ Step 配置/解除
**目的:** Step を「今週枠」に入れて予定化する

| タスク | ファイル |
|--------|----------|
| PlanTab に今週の PlanSlot リスト表示 | `Views/Plan/PlanTab.swift` |
| StepPickerSheet（Backlog 内の pending Step を選択） | `Views/Plan/` |
| scheduleStep() / unscheduleStep() | `Services/PlanService.swift` |
| Step.status を `.scheduled` に更新 | PlanService |
| weekId 生成の DateHelper | `Utilities/DateHelper.swift` |
| PlanServiceTests | `OneNextTests/` |

**受け入れ:** Step を1件「今週枠」に入れられる / 外せる。

### M4: Review（週次レビュー）+ 今週の1Goal + 次の3Step自動配置
**目的:** 週次レビューで振り返りと次週の計画を行う

| タスク | ファイル |
|--------|----------|
| ReviewTab にフロー表示（未完了確認 → Goal選択 → 3Step配置） | `Views/Review/ReviewTab.swift` |
| PendingStepList（未完了 Step 一覧） | `Views/Review/PendingStepList.swift` |
| GoalPickerSheet（Backlog から 1Goal 選択） | `Views/Review/GoalPickerSheet.swift` |
| autoPlaceNext3Steps()（選択した Goal の pending Step 上位3件を枠に配置） | `Services/ReviewService.swift` |
| ReviewLog 保存 | ReviewService |
| ReviewServiceTests | `OneNextTests/` |

**受け入れ:** 週次レビューで未完了確認 → 1Goal選択 → 次の3Stepが今週枠に配置される。

### M5: 実行確認（Done/延期/破棄）+ 週次通知
**目的:** 期限超過 Step への対応と週次レビュー通知

| タスク | ファイル |
|--------|----------|
| PlanTab / GoalDetail で期限超過 Step にアクション表示 | Views |
| Done / 延期 / 破棄ボタン（ワンタップ） | Views + Service |
| 延期 → status を `.pending` に戻し scheduledAt をクリア | PlanService |
| 破棄 → status を `.discarded` に | PlanService |
| 週次レビュー通知（毎週日曜 20:00 など） | `Services/NotificationService.swift` |
| Info.plist に通知 UsageDescription | Info.plist |

**受け入れ:** 期限超過 Step に Done/延期/破棄がワンタップ可能。通知が届く。

---

## 6. 全体タイムライン概算

| Milestone | 内容 | 想定 PR 規模 |
|-----------|------|-------------|
| **M0** | Scaffold + CI | ~20 ファイル |
| **M1** | Backlog CRUD | ~8 ファイル |
| **M2** | Template + Step生成 | ~5 ファイル |
| **M3** | Plan 今週枠 | ~5 ファイル |
| **M4** | Review 週次 | ~6 ファイル |
| **M5** | 実行確認 + 通知 | ~5 ファイル |

M0〜M5 で MVP (Must) の全機能をカバー。M6 以降は Should/Later。
