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
