import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/theme/custom_theme.dart';
import 'core/providers/theme_provider.dart';
import 'firebase_options.dart';
import 'features/shell/app_shell.dart';
import 'services/notification_service.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Only load dotenv + prefs synchronously (both are fast, <50ms)
  await dotenv.load(fileName: '.env');
  final prefs = await SharedPreferences.getInstance();

  // Show the app immediately — no white screen
  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const IdeaValidatorApp(),
    ),
  );

  // Heavy init runs in background after first frame is painted
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _initServicesInBackground();
  });
}

/// Initializes Firebase, Supabase, and notifications without blocking the UI.
Future<void> _initServicesInBackground() async {
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  } catch (e) {
    debugPrint('Firebase init failed: $e');
  }

  final supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
  final supabaseKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';
  if (supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty) {
    try {
      await Supabase.initialize(url: supabaseUrl, anonKey: supabaseKey);
    } catch (e) {
      debugPrint('Supabase init failed: $e');
    }
  }

  try {
    await NotificationService.instance.init(appNavigatorKey);
  } catch (e) {
    debugPrint('NotificationService init failed: $e');
  }
}

class IdeaValidatorApp extends ConsumerWidget {
  const IdeaValidatorApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);
    return MaterialApp(
      navigatorKey: appNavigatorKey,
      title: 'Validatyr',
      theme: RetroTheme.themeData,
      darkTheme: RetroTheme.darkThemeData,
      themeMode: themeMode,
      debugShowCheckedModeBanner: false,
      home: const AppShell(),
    );
  }
}
