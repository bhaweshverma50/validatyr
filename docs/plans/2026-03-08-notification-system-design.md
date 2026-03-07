# Notification System Design

**Date:** 2026-03-08
**Status:** Approved

## Overview

Add an in-app notification system to Validatyr so users know when validations complete, research reports finish, high-scoring ideas surface, and scheduled research is about to run — without manually checking each tab.

## Architecture

```
Backend (FastAPI)                          Frontend (Flutter)
┌─────────────────────┐                   ┌──────────────────────────┐
│ Pipeline completes   │                   │ NotificationService      │
│  → insert into       │──Supabase────────│  subscribes via Realtime │
│    notifications     │   Realtime        │  → local push via        │
│    table             │                   │    flutter_local_notifs   │
└─────────────────────┘                   │  → updates badge count   │
                                          ├──────────────────────────┤
                                          │ AppShell: bell icon +    │
                                          │   unread badge           │
                                          ├──────────────────────────┤
                                          │ NotificationCenterScreen │
                                          │   list with read/unread  │
                                          ├──────────────────────────┤
                                          │ NotificationSettings     │
                                          │   toggles + threshold    │
                                          │   (shared_preferences)   │
                                          └──────────────────────────┘
```

**Delivery mechanism:** Supabase Realtime (Postgres changes) + `flutter_local_notifications` for local push. No FCM/APNs — notifications only fire while the app process is alive (foreground or background). This avoids all push infrastructure complexity.

## Database Schema

```sql
CREATE TABLE notifications (
  id          bigserial PRIMARY KEY,
  type        text NOT NULL,        -- validation_complete, research_complete, high_score_alert, schedule_reminder
  title       text NOT NULL,
  body        text NOT NULL,
  metadata    jsonb DEFAULT '{}',   -- { validation_id, topic_id, score, ... }
  is_read     boolean DEFAULT false,
  created_at  timestamptz DEFAULT now()
);
```

Single-user app — no `user_id` column needed.

## Notification Triggers

### 1. `validation_complete` — in `backend/api/routes.py`

After the validation pipeline returns and result is saved to Supabase, insert:

```python
send_notification(
    type="validation_complete",
    title="Validation Complete",
    body=f"'{idea[:50]}' scored {score}/100",
    metadata={"validation_id": row_id, "score": score}
)
```

### 2. `research_complete` — in `backend/services/research_pipeline.py`

After report is saved:

```python
send_notification(
    type="research_complete",
    title="Research Report Ready",
    body=f"New report for {domain} topic",
    metadata={"topic_id": topic_id, "report_id": report_id}
)
```

### 3. `high_score_alert` — in `backend/services/research_pipeline.py`

After report is saved, check each idea's score against threshold (default 75):

```python
for idea in ideas:
    if idea["opportunity_score"] >= HIGH_SCORE_THRESHOLD:
        send_notification(
            type="high_score_alert",
            title=f"High-Score Idea: {idea['name'][:40]}",
            body=f"Scored {idea['opportunity_score']}/100 — tap to validate",
            metadata={"topic_id": topic_id, "report_id": report_id, "idea_name": idea["name"], "score": idea["opportunity_score"]}
        )
```

### 4. `schedule_reminder` — in `backend/services/research_scheduler.py`

Fire 5 minutes before a scheduled research run:

```python
send_notification(
    type="schedule_reminder",
    title="Research Starting Soon",
    body=f"{domain} topic runs in 5 minutes",
    metadata={"topic_id": topic_id}
)
```

### Helper function — in `backend/services/db.py`

```python
def send_notification(type: str, title: str, body: str, metadata: dict = {}):
    if not _client:
        return
    _client.table("notifications").insert({
        "type": type,
        "title": title,
        "body": body,
        "metadata": metadata,
    }).execute()
```

## Frontend Components

### NotificationService (`frontend/lib/services/notification_service.dart`)

- Singleton, initialized once in `main.dart`
- Subscribes to Supabase Realtime on `notifications` table (INSERT events)
- On new row: check user's toggle settings from `shared_preferences`; if enabled for that type, fire local notification via `flutter_local_notifications`
- Exposes `unreadCount` stream for badge
- Methods: `markAsRead(id)`, `markAllRead()`, `fetchAll()`, `deleteOld()`

### Bell Icon + Badge — in `AppShell`

- Add bell icon to the right of the AppBar (or as a 4th nav item)
- `StreamBuilder` on `unreadCount` shows red dot / count badge
- Tap opens `NotificationCenterScreen`

### NotificationCenterScreen (`frontend/lib/features/notifications/notification_center_screen.dart`)

- `ListView` of notification cards, newest first
- Unread items have a left accent bar (mint color)
- Tap marks as read + navigates to relevant screen based on `type`:
  - `validation_complete` → `ResultsScreen` (fetch by validation_id from metadata)
  - `research_complete` → `ReportDetailScreen`
  - `high_score_alert` → `ReportDetailScreen`
  - `schedule_reminder` → `TopicChannelScreen`
- "Mark all read" button in AppBar
- Pull-to-refresh

### NotificationSettingsScreen (`frontend/lib/features/notifications/notification_settings_screen.dart`)

- 4 toggle switches (one per notification type), default all ON
- Score threshold slider (50–95, default 75) — only for `high_score_alert`
- Stored in `shared_preferences`, read by `NotificationService` before firing local push
- Accessible from a gear icon in `NotificationCenterScreen` AppBar

## Limitations

- **No notifications when app is killed** — Supabase Realtime requires an active connection. Acceptable trade-off to avoid FCM/APNs infrastructure.
- **Single device** — No cross-device sync. Notifications table is shared, but Realtime subscription is per-device.

## Dependencies

- `flutter_local_notifications` — local push notifications
- `shared_preferences` — persist toggle settings
- `supabase_flutter` (already in pubspec) — Realtime subscription
