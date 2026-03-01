# アーキテクチャ方針（iOS）

- SwiftUI + SwiftData
- State管理：Observation（@Observable）でViewModel
- ドメイン：Goal / Step / PlanSlot / ReviewLog
- 通知：UNUserNotificationCenter
- カレンダー/リマインダー（Should以降）：EventKit

## データモデル
Goal:
- id, title, category?, priority, dueDate?, note?, imageData?, status, createdAt

Step:
- id, goalId, title, durationMin, dueDate?, type, status, scheduledAt?

PlanSlot:
- weekId, index(0..N), startAt?, endAt?, stepId?
