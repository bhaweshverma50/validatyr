import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/theme/custom_theme.dart';
import 'features/shell/app_shell.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  final supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
  final supabaseKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';
  if (supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty) {
    try {
      await Supabase.initialize(url: supabaseUrl, anonKey: supabaseKey);
    } catch (_) {
      // Supabase init failed — app continues without persistence
    }
    // Init notification service (requires Supabase to be initialized)
    try {
      await NotificationService.instance.init();
    } catch (_) {}
  }
  runApp(const ProviderScope(child: IdeaValidatorApp()));
}

class IdeaValidatorApp extends StatelessWidget {
  const IdeaValidatorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Validatyr',
      theme: RetroTheme.themeData,
      debugShowCheckedModeBanner: false,
      home: const AppShell(),
    );
  }
}
