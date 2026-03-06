import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../home/home_screen.dart';
import '../research/research_dashboard_screen.dart';
import '../history/history_screen.dart';
import '../../core/theme/custom_theme.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentIndex = 0;

  final _screens = const [
    HomeScreen(),
    ResearchDashboardScreen(),
    HistoryScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: Colors.black, width: 3),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (i) => setState(() => _currentIndex = i),
          backgroundColor: Colors.white,
          selectedItemColor: Colors.black,
          unselectedItemColor: Colors.black45,
          selectedFontSize: 12,
          unselectedFontSize: 12,
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(LucideIcons.home),
              activeIcon: Icon(LucideIcons.home, color: RetroTheme.pink),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(LucideIcons.microscope),
              activeIcon: Icon(LucideIcons.microscope, color: RetroTheme.lavender),
              label: 'Research',
            ),
            BottomNavigationBarItem(
              icon: Icon(LucideIcons.clock),
              activeIcon: Icon(LucideIcons.clock, color: RetroTheme.mint),
              label: 'History',
            ),
          ],
        ),
      ),
    );
  }
}
