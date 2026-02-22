import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/custom_theme.dart';
import 'features/home/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // TODO: Initialize Supabase here later
  
  runApp(
    // ProviderScope required for Riverpod
    const ProviderScope(
      child: IdeaValidatorApp(),
    ),
  );
}

class IdeaValidatorApp extends StatelessWidget {
  const IdeaValidatorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Validatyr',
      theme: RetroTheme.themeData,
      debugShowCheckedModeBanner: false,
      home: const HomeScreen(),
    );
  }
}
