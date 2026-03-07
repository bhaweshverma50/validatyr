# Notification System Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add an in-app notification system using Supabase Realtime + local notifications so users see when validations complete, research finishes, high-scoring ideas appear, and scheduled research is about to run.

**Architecture:** Backend inserts rows into a `notifications` table in Supabase when events occur. Frontend subscribes to that table via Supabase Realtime, fires local push notifications via `flutter_local_notifications`, and provides a notification center screen with read/unread state and settings.

**Tech Stack:** Python/FastAPI (backend triggers), Supabase (Postgres + Realtime), Flutter + `flutter_local_notifications` + `shared_preferences` (frontend)

---

## Task 1: Add `send_notification` helper to backend

**Files:**
- Modify: `backend/services/db.py` (append after line 59)

**Step 1: Add the helper function**

Add to the end of `backend/services/db.py`:

```python
def send_notification(type: str, title: str, body: str, metadata: dict | None = None):
    """Insert a notification row into Supabase (triggers Realtime for frontend)."""
    supabase = get_supabase()
    if not supabase:
        logger.info(f"[MOCKED] Notification: {type} — {title}")
        return
    try:
        supabase.table("notifications").insert({
            "type": type,
            "title": title,
            "body": body,
            "metadata": metadata or {},
        }).execute()
    except Exception as e:
        logger.warning(f"Failed to send notification: {e}")
```

**Step 2: Commit**

```bash
git add backend/services/db.py
git commit -m "feat(notifications): add send_notification helper to db.py"
```

---

## Task 2: Fire `validation_complete` notification from validation routes

**Files:**
- Modify: `backend/api/routes.py`

**Step 1: Add import**

At `routes.py:18`, change:
```python
from services.db import save_validation_result
```
to:
```python
from services.db import save_validation_result, send_notification
```

**Step 2: Add notification after non-streaming save (line ~125)**

After `save_validation_result(request.idea, result.model_dump())` on line 125, add:

```python
        send_notification(
            type="validation_complete",
            title="Validation Complete",
            body=f"'{request.idea[:50]}' scored {result.opportunity_score}/100",
            metadata={"score": result.opportunity_score},
        )
```

**Step 3: Add notification after streaming save (line ~328)**

After the `save_validation_result(idea, final_result.model_dump())` block (inside the try around line 326), add:

```python
                send_notification(
                    type="validation_complete",
                    title="Validation Complete",
                    body=f"'{idea[:50]}' scored {opportunity_score}/100",
                    metadata={"score": opportunity_score},
                )
```

**Step 4: Commit**

```bash
git add backend/api/routes.py
git commit -m "feat(notifications): fire validation_complete notification"
```

---

## Task 3: Fire `research_complete` and `high_score_alert` from research pipeline

**Files:**
- Modify: `backend/services/research_pipeline.py`

**Step 1: Add import**

After the existing imports at top of file, add:
```python
from services.db import send_notification
```

**Step 2: Add notifications after report is saved (after line 101)**

After `saved = save_research_report(report.model_dump())` and `report_id = saved.get(...)` (lines 101-102), insert:

```python
        # Notify: research complete
        send_notification(
            type="research_complete",
            title="Research Report Ready",
            body=f"New report for {domain} topic",
            metadata={"topic_id": topic_id, "report_id": report_id},
        )

        # Notify: high-score ideas (threshold 75)
        for idea in report.ideas:
            score = getattr(idea, "opportunity_score", 0)
            name = getattr(idea, "name", "Untitled")
            if score >= 75:
                send_notification(
                    type="high_score_alert",
                    title=f"High-Score Idea: {name[:40]}",
                    body=f"Scored {score}/100 — tap to validate",
                    metadata={
                        "topic_id": topic_id,
                        "report_id": report_id,
                        "idea_name": name,
                        "score": score,
                    },
                )
```

**Step 3: Commit**

```bash
git add backend/services/research_pipeline.py
git commit -m "feat(notifications): fire research_complete and high_score_alert"
```

---

## Task 4: Fire `schedule_reminder` from research scheduler

**Files:**
- Modify: `backend/services/research_scheduler.py`

**Step 1: Add import**

After existing imports, add:
```python
from services.db import send_notification
```

**Step 2: Add reminder notification in `_execute_research_job`**

At the start of `_execute_research_job`, after the `is_active` check (around line 127), before `loop = asyncio.get_running_loop()`, add:

```python
    send_notification(
        type="schedule_reminder",
        title="Research Starting",
        body=f"{topic.get('domain', 'general')} topic research starting now",
        metadata={"topic_id": topic_id},
    )
```

**Step 3: Commit**

```bash
git add backend/services/research_scheduler.py
git commit -m "feat(notifications): fire schedule_reminder on scheduled runs"
```

---

## Task 5: Add notification API endpoints for frontend

**Files:**
- Modify: `backend/api/research_routes.py` (add notification endpoints to existing router, or create new file)

We'll add to the existing research_routes since the router is already mounted. Alternatively, add a small section at the bottom.

**Step 1: Add notification CRUD endpoints to `backend/api/research_routes.py`**

Append at the end of the file:

```python
# ---------------------------------------------------------------------------
# Notifications
# ---------------------------------------------------------------------------

@router.get("/notifications")
async def get_notifications(limit: int = 50, offset: int = 0):
    """Fetch notifications, newest first."""
    from services.db import get_supabase
    supabase = get_supabase()
    if not supabase:
        return {"notifications": []}
    try:
        response = (
            supabase.table("notifications")
            .select("*")
            .order("created_at", desc=True)
            .range(offset, offset + limit - 1)
            .execute()
        )
        return {"notifications": response.data or []}
    except Exception as e:
        logger.error(f"Error fetching notifications: {e}")
        return {"notifications": []}


@router.put("/notifications/{notification_id}/read")
async def mark_notification_read(notification_id: int):
    from services.db import get_supabase
    supabase = get_supabase()
    if not supabase:
        return {"status": "mocked"}
    try:
        supabase.table("notifications").update({"is_read": True}).eq("id", notification_id).execute()
        return {"status": "ok"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.put("/notifications/read-all")
async def mark_all_notifications_read():
    from services.db import get_supabase
    supabase = get_supabase()
    if not supabase:
        return {"status": "mocked"}
    try:
        supabase.table("notifications").update({"is_read": True}).eq("is_read", False).execute()
        return {"status": "ok"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
```

**Step 2: Commit**

```bash
git add backend/api/research_routes.py
git commit -m "feat(notifications): add GET/PUT notification API endpoints"
```

---

## Task 6: Add Flutter dependencies

**Files:**
- Modify: `frontend/pubspec.yaml`

**Step 1: Add dependencies**

In the `dependencies:` section of `pubspec.yaml`, add:

```yaml
  flutter_local_notifications: ^18.0.1
  shared_preferences: ^2.3.4
```

**Step 2: Install**

```bash
cd frontend && flutter pub get
```

**Step 3: Commit**

```bash
git add frontend/pubspec.yaml frontend/pubspec.lock
git commit -m "feat(notifications): add flutter_local_notifications and shared_preferences"
```

---

## Task 7: Create NotificationService

**Files:**
- Create: `frontend/lib/services/notification_service.dart`

**Step 1: Create the service**

```dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _unreadController = StreamController<int>.broadcast();
  Stream<int> get unreadCountStream => _unreadController.stream;
  int _unreadCount = 0;
  int get unreadCount => _unreadCount;

  FlutterLocalNotificationsPlugin? _localNotifications;
  RealtimeChannel? _channel;
  SharedPreferences? _prefs;

  // Preference keys
  static const _keyValidationComplete = 'notif_validation_complete';
  static const _keyResearchComplete = 'notif_research_complete';
  static const _keyHighScoreAlert = 'notif_high_score_alert';
  static const _keyScheduleReminder = 'notif_schedule_reminder';
  static const _keyScoreThreshold = 'notif_score_threshold';

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();

    // Init local notifications
    _localNotifications = FlutterLocalNotificationsPlugin();
    const initSettings = InitializationSettings(
      iOS: DarwinInitializationSettings(),
      macOS: DarwinInitializationSettings(),
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _localNotifications!.initialize(initSettings);

    // Load initial unread count
    await refreshUnreadCount();

    // Subscribe to Supabase Realtime
    _subscribeToRealtime();
  }

  void _subscribeToRealtime() {
    try {
      final client = Supabase.instance.client;
      _channel = client.channel('notifications');
      _channel!
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'notifications',
            callback: (payload) {
              final row = payload.newRecord;
              _onNewNotification(row);
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('NotificationService: Realtime subscribe failed: $e');
    }
  }

  void _onNewNotification(Map<String, dynamic> row) {
    _unreadCount++;
    _unreadController.add(_unreadCount);

    final type = row['type'] as String? ?? '';
    final title = row['title'] as String? ?? '';
    final body = row['body'] as String? ?? '';
    final metadata = row['metadata'] as Map<String, dynamic>? ?? {};

    if (!_isTypeEnabled(type, metadata)) return;

    _showLocalNotification(title, body);
  }

  bool _isTypeEnabled(String type, Map<String, dynamic> metadata) {
    final prefs = _prefs;
    if (prefs == null) return true;

    switch (type) {
      case 'validation_complete':
        return prefs.getBool(_keyValidationComplete) ?? true;
      case 'research_complete':
        return prefs.getBool(_keyResearchComplete) ?? true;
      case 'high_score_alert':
        if (!(prefs.getBool(_keyHighScoreAlert) ?? true)) return false;
        final threshold = prefs.getInt(_keyScoreThreshold) ?? 75;
        final score = (metadata['score'] as num?)?.toInt() ?? 0;
        return score >= threshold;
      case 'schedule_reminder':
        return prefs.getBool(_keyScheduleReminder) ?? true;
      default:
        return true;
    }
  }

  Future<void> _showLocalNotification(String title, String body) async {
    const details = NotificationDetails(
      iOS: DarwinNotificationDetails(),
      macOS: DarwinNotificationDetails(),
      android: AndroidNotificationDetails(
        'validatyr_notifications',
        'Validatyr',
        importance: Importance.high,
        priority: Priority.high,
      ),
    );
    await _localNotifications?.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
    );
  }

  Future<void> refreshUnreadCount() async {
    try {
      final client = Supabase.instance.client;
      final response = await client
          .from('notifications')
          .select('id')
          .eq('is_read', false);
      _unreadCount = (response as List).length;
      _unreadController.add(_unreadCount);
    } catch (e) {
      debugPrint('NotificationService: refreshUnreadCount failed: $e');
    }
  }

  Future<List<Map<String, dynamic>>> fetchAll() async {
    try {
      final client = Supabase.instance.client;
      final response = await client
          .from('notifications')
          .select()
          .order('created_at', ascending: false)
          .limit(50);
      return List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      debugPrint('NotificationService: fetchAll failed: $e');
      return [];
    }
  }

  Future<void> markAsRead(dynamic id) async {
    try {
      final client = Supabase.instance.client;
      await client.from('notifications').update({'is_read': true}).eq('id', id);
      _unreadCount = (_unreadCount - 1).clamp(0, 999);
      _unreadController.add(_unreadCount);
    } catch (e) {
      debugPrint('NotificationService: markAsRead failed: $e');
    }
  }

  Future<void> markAllRead() async {
    try {
      final client = Supabase.instance.client;
      await client.from('notifications').update({'is_read': true}).eq('is_read', false);
      _unreadCount = 0;
      _unreadController.add(_unreadCount);
    } catch (e) {
      debugPrint('NotificationService: markAllRead failed: $e');
    }
  }

  void dispose() {
    _channel?.unsubscribe();
    _unreadController.close();
  }
}
```

**Step 2: Commit**

```bash
git add frontend/lib/services/notification_service.dart
git commit -m "feat(notifications): create NotificationService with Realtime + local push"
```

---

## Task 8: Initialize NotificationService in main.dart

**Files:**
- Modify: `frontend/lib/main.dart`

**Step 1: Add import and init call**

Add import at top:
```dart
import 'services/notification_service.dart';
```

In the `main()` function, after the Supabase initialization block (after line 18, before `runApp`), add:

```dart
  // Init notification service (requires Supabase to be initialized)
  if (supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty) {
    try {
      await NotificationService.instance.init();
    } catch (_) {}
  }
```

**Step 2: Commit**

```bash
git add frontend/lib/main.dart
git commit -m "feat(notifications): initialize NotificationService on app start"
```

---

## Task 9: Create NotificationCenterScreen

**Files:**
- Create: `frontend/lib/features/notifications/notification_center_screen.dart`

**Step 1: Create the screen**

```dart
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/theme/custom_theme.dart';
import '../../core/utils.dart';
import '../../shared_widgets/retro_card.dart';
import '../../services/notification_service.dart';
import 'notification_settings_screen.dart';

class NotificationCenterScreen extends StatefulWidget {
  const NotificationCenterScreen({super.key});

  @override
  State<NotificationCenterScreen> createState() => _NotificationCenterScreenState();
}

class _NotificationCenterScreenState extends State<NotificationCenterScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final items = await NotificationService.instance.fetchAll();
    if (mounted) setState(() { _items = items; _isLoading = false; });
  }

  Future<void> _markAllRead() async {
    await NotificationService.instance.markAllRead();
    setState(() {
      for (final item in _items) {
        item['is_read'] = true;
      }
    });
  }

  Future<void> _onTap(Map<String, dynamic> item) async {
    final id = item['id'];
    if (item['is_read'] != true) {
      await NotificationService.instance.markAsRead(id);
      setState(() => item['is_read'] = true);
    }
    // Navigation based on type could be added here
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'validation_complete': return LucideIcons.checkCircle;
      case 'research_complete': return LucideIcons.microscope;
      case 'high_score_alert': return LucideIcons.zap;
      case 'schedule_reminder': return LucideIcons.clock;
      default: return LucideIcons.bell;
    }
  }

  Color _colorForType(String type) {
    switch (type) {
      case 'validation_complete': return RetroTheme.mint;
      case 'research_complete': return RetroTheme.lavender;
      case 'high_score_alert': return RetroTheme.yellow;
      case 'schedule_reminder': return RetroTheme.blue;
      default: return RetroTheme.pink;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RetroTheme.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'NOTIFICATIONS',
          style: TextStyle(
            fontFamily: 'Outfit',
            fontWeight: FontWeight.w900,
            fontSize: RetroTheme.fontXl,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.checkCheck, size: 20),
            tooltip: 'Mark all read',
            onPressed: _items.any((i) => i['is_read'] != true) ? _markAllRead : null,
          ),
          IconButton(
            icon: const Icon(LucideIcons.settings, size: 20),
            tooltip: 'Settings',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NotificationSettingsScreen()),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2.5))
          : _items.isEmpty
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(LucideIcons.bellOff, size: 48, color: Colors.black26),
                    const SizedBox(height: RetroTheme.spacingMd),
                    Text('No notifications yet',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(color: RetroTheme.textMuted)),
                  ]),
                )
              : RefreshIndicator(
                  color: Colors.black,
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: RetroTheme.contentPaddingMobile,
                      vertical: RetroTheme.spacingMd,
                    ),
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: RetroTheme.spacingSm),
                    itemBuilder: (_, i) => _buildItem(_items[i]),
                  ),
                ),
    );
  }

  Widget _buildItem(Map<String, dynamic> item) {
    final type = item['type'] as String? ?? '';
    final title = item['title'] as String? ?? '';
    final body = item['body'] as String? ?? '';
    final isRead = item['is_read'] as bool? ?? false;
    final dateTime = formatDateTime(item['created_at']?.toString());

    return GestureDetector(
      onTap: () => _onTap(item),
      child: RetroCard(
        backgroundColor: isRead ? Colors.white : _colorForType(type).withAlpha(40),
        padding: EdgeInsets.zero,
        child: IntrinsicHeight(
          child: Row(
            children: [
              if (!isRead)
                Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: _colorForType(type),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(RetroTheme.radiusMd),
                      bottomLeft: Radius.circular(RetroTheme.radiusMd),
                    ),
                  ),
                ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: _colorForType(type),
                          borderRadius: BorderRadius.circular(RetroTheme.radiusSm),
                          border: Border.all(color: RetroTheme.border, width: RetroTheme.borderWidthThin),
                        ),
                        child: Icon(_iconForType(type), size: 16, color: Colors.black),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: TextStyle(
                                fontFamily: 'Outfit',
                                fontWeight: isRead ? FontWeight.w600 : FontWeight.w800,
                                fontSize: RetroTheme.fontMd,
                              ),
                            ),
                            if (body.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                body,
                                style: const TextStyle(fontSize: RetroTheme.fontSm, color: Colors.black54),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                            const SizedBox(height: 4),
                            Text(
                              dateTime,
                              style: const TextStyle(fontSize: RetroTheme.fontXs, color: Colors.black38, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

**Step 2: Commit**

```bash
git add frontend/lib/features/notifications/notification_center_screen.dart
git commit -m "feat(notifications): create NotificationCenterScreen"
```

---

## Task 10: Create NotificationSettingsScreen

**Files:**
- Create: `frontend/lib/features/notifications/notification_settings_screen.dart`

**Step 1: Create the screen**

```dart
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/custom_theme.dart';
import '../../shared_widgets/retro_card.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  bool _validationComplete = true;
  bool _researchComplete = true;
  bool _highScoreAlert = true;
  bool _scheduleReminder = true;
  int _scoreThreshold = 75;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _validationComplete = prefs.getBool('notif_validation_complete') ?? true;
      _researchComplete = prefs.getBool('notif_research_complete') ?? true;
      _highScoreAlert = prefs.getBool('notif_high_score_alert') ?? true;
      _scheduleReminder = prefs.getBool('notif_schedule_reminder') ?? true;
      _scoreThreshold = prefs.getInt('notif_score_threshold') ?? 75;
      _loaded = true;
    });
  }

  Future<void> _saveBool(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  Future<void> _saveInt(String key, int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(key, value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RetroTheme.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'NOTIFICATION SETTINGS',
          style: TextStyle(
            fontFamily: 'Outfit',
            fontWeight: FontWeight.w900,
            fontSize: RetroTheme.fontXl,
          ),
        ),
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2.5))
          : ListView(
              padding: const EdgeInsets.symmetric(
                horizontal: RetroTheme.contentPaddingMobile,
                vertical: RetroTheme.spacingMd,
              ),
              children: [
                const Text('PUSH NOTIFICATIONS', style: RetroTheme.sectionTitle),
                const SizedBox(height: RetroTheme.spacingSm),
                const Text(
                  'Choose which events trigger local push notifications.',
                  style: TextStyle(fontSize: RetroTheme.fontSm, color: Colors.black54),
                ),
                const SizedBox(height: RetroTheme.spacingMd),
                _buildToggle(
                  icon: LucideIcons.checkCircle,
                  color: RetroTheme.mint,
                  title: 'Validation Complete',
                  subtitle: 'When an idea validation finishes',
                  value: _validationComplete,
                  onChanged: (v) {
                    setState(() => _validationComplete = v);
                    _saveBool('notif_validation_complete', v);
                  },
                ),
                const SizedBox(height: RetroTheme.spacingSm),
                _buildToggle(
                  icon: LucideIcons.microscope,
                  color: RetroTheme.lavender,
                  title: 'Research Complete',
                  subtitle: 'When a research report is generated',
                  value: _researchComplete,
                  onChanged: (v) {
                    setState(() => _researchComplete = v);
                    _saveBool('notif_research_complete', v);
                  },
                ),
                const SizedBox(height: RetroTheme.spacingSm),
                _buildToggle(
                  icon: LucideIcons.zap,
                  color: RetroTheme.yellow,
                  title: 'High-Score Ideas',
                  subtitle: 'When a research idea scores above threshold',
                  value: _highScoreAlert,
                  onChanged: (v) {
                    setState(() => _highScoreAlert = v);
                    _saveBool('notif_high_score_alert', v);
                  },
                ),
                if (_highScoreAlert) ...[
                  const SizedBox(height: RetroTheme.spacingSm),
                  RetroCard(
                    backgroundColor: const Color(0xFFFEF9C3),
                    padding: const EdgeInsets.all(RetroTheme.spacingMd),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SCORE THRESHOLD: $_scoreThreshold',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: RetroTheme.fontSm),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Only notify for ideas scoring at or above this value.',
                          style: TextStyle(fontSize: RetroTheme.fontSm, color: Colors.black54),
                        ),
                        Slider(
                          value: _scoreThreshold.toDouble(),
                          min: 50,
                          max: 95,
                          divisions: 9,
                          label: '$_scoreThreshold',
                          activeColor: Colors.black,
                          onChanged: (v) {
                            setState(() => _scoreThreshold = v.round());
                            _saveInt('notif_score_threshold', v.round());
                          },
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: RetroTheme.spacingSm),
                _buildToggle(
                  icon: LucideIcons.clock,
                  color: RetroTheme.blue,
                  title: 'Schedule Reminders',
                  subtitle: 'When scheduled research is about to run',
                  value: _scheduleReminder,
                  onChanged: (v) {
                    setState(() => _scheduleReminder = v);
                    _saveBool('notif_schedule_reminder', v);
                  },
                ),
              ],
            ),
    );
  }

  Widget _buildToggle({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return RetroCard(
      backgroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(RetroTheme.radiusSm),
              border: Border.all(color: RetroTheme.border, width: RetroTheme.borderWidthThin),
            ),
            child: Icon(icon, size: 16, color: Colors.black),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: RetroTheme.fontMd)),
                Text(subtitle, style: const TextStyle(fontSize: RetroTheme.fontSm, color: Colors.black54)),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeColor: Colors.black,
          ),
        ],
      ),
    );
  }
}
```

**Step 2: Commit**

```bash
git add frontend/lib/features/notifications/notification_settings_screen.dart
git commit -m "feat(notifications): create NotificationSettingsScreen with toggles and threshold"
```

---

## Task 11: Add bell icon with unread badge to AppShell

**Files:**
- Modify: `frontend/lib/features/shell/app_shell.dart`

**Step 1: Add imports**

Add at the top of the file:
```dart
import '../../services/notification_service.dart';
import '../notifications/notification_center_screen.dart';
```

**Step 2: Add bell icon to the build method**

In the `build` method, wrap the current `Scaffold` body's `appBar` — but since `AppShell` uses `IndexedStack` with each screen having its own `AppBar`, we need a different approach. Add a floating bell button or integrate into each screen.

**Better approach:** Add the bell icon as an overlay in the `AppShell` `Scaffold`. Add an `AppBar` to `AppShell` itself is not ideal since child screens have their own. Instead, add a small floating notification bell.

**Simplest approach:** Add the bell icon to the bottom nav bar area.

**Cleanest approach:** Each child screen doesn't have a unified AppBar we control, so add a `Stack` with a positioned bell icon overlay in the top-right corner.

Actually, the cleanest approach: Add a `actions` widget in the AppShell that shows on all screens. But since each screen has its own AppBar, let's add the bell to the `AppShell` `Scaffold` as a `floatingActionButton` positioned at top-right, or more practically, add it to each screen's AppBar actions.

**Best approach for consistency:** Add a bell widget to the bottom nav bar row. Place it at the far right of the bottom bar.

**Final decision:** Add the bell icon as an action in the bottom bar, next to the tabs. This keeps it visible everywhere.

In `app_shell.dart`, modify the `build` method. After the tab `Row`, add a bell icon at the end.

Replace the `bottomNavigationBar` container's `child: Row(...)` to include a notification bell. In the `Row` of tabs, add the bell after the tabs:

In the `build` method, change the bottom nav `Row` children from `List.generate(_tabs.length, ...)` to include a notification bell at the end:

```dart
child: Row(
  children: [
    ...List.generate(_tabs.length, (i) {
      // ... existing tab code
    }),
    // Notification bell
    StreamBuilder<int>(
      stream: NotificationService.instance.unreadCountStream,
      initialData: NotificationService.instance.unreadCount,
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const NotificationCenterScreen()),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(LucideIcons.bell, size: 20, color: Colors.black54),
                if (count > 0)
                  Positioned(
                    right: -6,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: RetroTheme.pink,
                        shape: BoxShape.circle,
                        border: Border.fromBorderSide(
                          BorderSide(color: Colors.black, width: 1.5),
                        ),
                      ),
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                      child: Text(
                        count > 9 ? '9+' : '$count',
                        style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.black),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    ),
  ],
),
```

**Step 3: Commit**

```bash
git add frontend/lib/features/shell/app_shell.dart
git commit -m "feat(notifications): add bell icon with unread badge to bottom nav"
```

---

## Task 12: Create Supabase `notifications` table

**Files:**
- Create: `docs/plans/notifications-table.sql` (reference SQL for the user)

**Step 1: Create SQL reference file**

```sql
-- Run this in your Supabase SQL Editor to create the notifications table.
-- Also enable Realtime on this table in the Supabase Dashboard:
--   Database → Replication → Enable for 'notifications' table

CREATE TABLE IF NOT EXISTS notifications (
  id          bigserial PRIMARY KEY,
  type        text NOT NULL,
  title       text NOT NULL,
  body        text NOT NULL,
  metadata    jsonb DEFAULT '{}',
  is_read     boolean DEFAULT false,
  created_at  timestamptz DEFAULT now()
);

-- Enable Realtime (run in SQL editor):
ALTER PUBLICATION supabase_realtime ADD TABLE notifications;
```

**Step 2: Commit**

```bash
git add docs/plans/notifications-table.sql
git commit -m "docs: add SQL for notifications table creation"
```

---

## Task 13: Final integration test

**Step 1: Run Flutter analyze**

```bash
cd frontend && flutter analyze
```

Fix any issues found.

**Step 2: Run backend to verify imports**

```bash
cd backend && python -c "from services.db import send_notification; print('OK')"
```

**Step 3: Final commit if any fixes needed**

```bash
git add -A
git commit -m "fix(notifications): resolve any lint/import issues"
```
