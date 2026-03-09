import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../features/notifications/notification_center_screen.dart';
import 'api_service.dart';

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
  GlobalKey<NavigatorState>? _navigatorKey;
  bool _didHandleInitialMessage = false;

  // Preference keys
  static const _keyValidationComplete = 'notif_validation_complete';
  static const _keyResearchComplete = 'notif_research_complete';
  static const _keyHighScoreAlert = 'notif_high_score_alert';
  static const _keyScheduleReminder = 'notif_schedule_reminder';
  static const _keyScoreThreshold = 'notif_score_threshold';
  static const _notificationCenterPayload = 'notification_center';

  Future<void> init(GlobalKey<NavigatorState> navigatorKey) async {
    _navigatorKey = navigatorKey;
    _prefs = await SharedPreferences.getInstance();

    // Load initial unread count and subscribe to Realtime FIRST
    // (these only depend on Supabase which is already initialized)
    await refreshUnreadCount();
    _subscribeToRealtime();

    // Init local notifications (may fail on some platforms)
    try {
      _localNotifications = FlutterLocalNotificationsPlugin();
      final initSettings = InitializationSettings(
        iOS: DarwinInitializationSettings(),
        macOS: DarwinInitializationSettings(),
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      );
      await _localNotifications!.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (response) {
          if (response.payload == _notificationCenterPayload) {
            _openNotificationCenter();
          }
        },
      );
      await _createAndroidChannel();
      await requestSystemPermissions();
    } catch (e) {
      debugPrint('NotificationService: local notifications init failed: $e');
    }

    // Firebase Messaging (may fail if not configured)
    try {
      await _setupFirebaseMessaging();
    } catch (e) {
      debugPrint('NotificationService: Firebase messaging setup failed: $e');
    }
  }

  /// Returns true if permission was granted, false otherwise.
  Future<bool> requestSystemPermissions() async {
    final plugin = _localNotifications;
    if (plugin == null) return false;

    try {
      bool granted = false;

      if (defaultTargetPlatform == TargetPlatform.android) {
        // On Android 13+, this shows the native permission dialog.
        // On older versions, notifications are granted by default.
        final result = await plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.requestNotificationsPermission();
        granted = result ?? false;

        // Also request via Firebase (ensures internal state is synced)
        await FirebaseMessaging.instance.requestPermission(
          alert: true, badge: true, sound: true, provisional: false,
        );
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        final messaging = FirebaseMessaging.instance;
        final currentSettings = await messaging.getNotificationSettings();

        if (currentSettings.authorizationStatus == AuthorizationStatus.denied) {
          // iOS won't re-prompt after denial — open system Settings
          await launchUrl(Uri.parse('app-settings:'));
          return false;
        }

        final settings = await messaging.requestPermission(
          alert: true, badge: true, sound: true, provisional: false,
        );
        await plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >()
            ?.requestPermissions(alert: true, badge: true, sound: true);
        granted = settings.authorizationStatus == AuthorizationStatus.authorized ||
            settings.authorizationStatus == AuthorizationStatus.provisional;
      } else {
        // macOS / other
        final messaging = FirebaseMessaging.instance;
        final settings = await messaging.requestPermission(
          alert: true, badge: true, sound: true, provisional: false,
        );
        await plugin
            .resolvePlatformSpecificImplementation<
              MacOSFlutterLocalNotificationsPlugin
            >()
            ?.requestPermissions(alert: true, badge: true, sound: true);
        granted = settings.authorizationStatus == AuthorizationStatus.authorized ||
            settings.authorizationStatus == AuthorizationStatus.provisional;
      }

      if (granted) {
        await _ensureFcmTokenRegistered();
      }
      return granted;
    } catch (e) {
      debugPrint('NotificationService: permission request failed: $e');
      return false;
    }
  }

  /// Attempt to get and register the FCM token (called after permission grant).
  Future<void> _ensureFcmTokenRegistered() async {
    try {
      final messaging = FirebaseMessaging.instance;
      if (_platformLabel == 'ios' || _platformLabel == 'macos') {
        final apnsToken = await messaging.getAPNSToken();
        if (apnsToken == null) return;
      }
      final token = await messaging.getToken();
      if (token != null) {
        await _registerPushToken(token);
      }
    } catch (e) {
      debugPrint('NotificationService: FCM token registration after permission failed: $e');
    }
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
  }

  Future<void> _setupFirebaseMessaging() async {
    final messaging = FirebaseMessaging.instance;

    try {
      await messaging.setAutoInitEnabled(true);
    } catch (e) {
      debugPrint('NotificationService: auto init failed: $e');
    }

    final initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null && !_didHandleInitialMessage) {
      _didHandleInitialMessage = true;
      unawaited(refreshState(reconnectRealtime: true));
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _openNotificationCenter();
      });
    }

    FirebaseMessaging.onMessage.listen((message) {
      unawaited(refreshState(reconnectRealtime: false));

      final type = message.data['type']?.toString() ?? '';
      final metadata = Map<String, dynamic>.from(message.data);
      if (!_isTypeEnabled(type, metadata)) {
        return;
      }

      final notification = message.notification;
      if (notification != null) {
        _showLocalNotification(
          notification.title ?? 'Validatyr',
          notification.body ?? 'You have a new notification.',
        );
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((_) {
      unawaited(refreshState(reconnectRealtime: true));
      _openNotificationCenter();
    });

    try {
      if (_platformLabel == 'ios' || _platformLabel == 'macos') {
        // APNs token may not be ready immediately; retry a few times.
        String? apnsToken;
        for (int i = 0; i < 5; i++) {
          apnsToken = await messaging.getAPNSToken();
          if (apnsToken != null) break;
          await Future.delayed(const Duration(seconds: 2));
        }
        if (apnsToken == null) {
          debugPrint(
            'NotificationService: APNs token unavailable after retries; '
            'will register on next token refresh.',
          );
        } else {
          final token = await messaging.getToken();
          if (token != null) {
            await _registerPushToken(token);
          }
        }
      } else {
        final token = await messaging.getToken();
        if (token != null) {
          await _registerPushToken(token);
        }
      }
    } catch (e) {
      debugPrint('NotificationService: initial token fetch failed: $e');
    }

    messaging.onTokenRefresh
        .listen((token) async {
          await _registerPushToken(token);
        })
        .onError((error) {
          debugPrint('NotificationService: token refresh failed: $error');
        });
  }

  Future<void> _registerPushToken(String token) async {
    try {
      await ApiService.registerPushToken(
        token: token,
        platform: _platformLabel,
      );
    } catch (e) {
      debugPrint('NotificationService: push token registration failed: $e');
    }
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
      payload: _notificationCenterPayload,
    );
  }

  Future<void> _createAndroidChannel() async {
    const channel = AndroidNotificationChannel(
      'validatyr_notifications',
      'Validatyr',
      description: 'Validation and research notifications',
      importance: Importance.high,
    );

    try {
      await _localNotifications
          ?.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(channel);
    } catch (e) {
      debugPrint('NotificationService: channel creation failed: $e');
    }
  }

  void _openNotificationCenter() {
    final navigator = _navigatorKey?.currentState;
    final context = navigator?.context;
    if (navigator == null || context == null) return;

    navigator.push(
      MaterialPageRoute(builder: (_) => const NotificationCenterScreen()),
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

  Future<void> refreshState({bool reconnectRealtime = false}) async {
    await refreshUnreadCount();
    if (reconnectRealtime) {
      await _channel?.unsubscribe();
      _channel = null;
      _subscribeToRealtime();
    }
  }

  String get _platformLabel {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.macOS:
        return 'macos';
      default:
        return defaultTargetPlatform.name;
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
      await client
          .from('notifications')
          .update({'is_read': true})
          .eq('is_read', false);
      _unreadCount = 0;
      _unreadController.add(_unreadCount);
    } catch (e) {
      debugPrint('NotificationService: markAllRead failed: $e');
    }
  }

  Future<void> deleteNotification(dynamic id) async {
    try {
      final client = Supabase.instance.client;
      await client.from('notifications').delete().eq('id', id);
    } catch (e) {
      debugPrint('NotificationService: deleteNotification failed: $e');
    }
  }

  Future<void> clearAll() async {
    try {
      final client = Supabase.instance.client;
      await client.from('notifications').delete().neq('id', 0);
      _unreadCount = 0;
      _unreadController.add(_unreadCount);
    } catch (e) {
      debugPrint('NotificationService: clearAll failed: $e');
    }
  }

  void dispose() {
    _channel?.unsubscribe();
    _unreadController.close();
  }
}
