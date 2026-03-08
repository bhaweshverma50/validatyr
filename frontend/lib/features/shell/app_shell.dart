import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../home/home_screen.dart';
import '../research/research_dashboard_screen.dart';
import '../history/history_screen.dart';
import '../../core/theme/custom_theme.dart';
import '../../shared_widgets/notification_bell.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  int _currentIndex = 0;
  final _historyKey = GlobalKey<HistoryScreenState>();

  late final List<Widget> _screens;

  static const _tabs = [
    (icon: LucideIcons.home, label: 'Home', color: RetroTheme.pink),
    (icon: LucideIcons.microscope, label: 'Research', color: RetroTheme.lavender),
    (icon: LucideIcons.clock, label: 'History', color: RetroTheme.yellow),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _screens = [
      const HomeScreen(),
      const ResearchDashboardScreen(),
      HistoryScreen(key: _historyKey),
    ];
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _historyKey.currentState?.refresh();
    }
  }

  void _onTabTapped(int i) {
    setState(() => _currentIndex = i);
    if (i == 2) {
      _historyKey.currentState?.refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(
            index: _currentIndex,
            children: _screens,
          ),
          // Floating notification bell — only on Home tab (no AppBar)
          if (_currentIndex == 0)
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              right: 12,
              child: NotificationBell.floating(context),
            ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: RetroTheme.surface,
          border: Border(
            top: BorderSide(color: RetroTheme.borderSubtle, width: 1),
          ),
        ),
        padding: EdgeInsets.only(
          top: 6,
          bottom: bottomPadding > 0 ? bottomPadding : 6,
        ),
        child: Row(
          children: [
            ...List.generate(_tabs.length, (i) {
              final tab = _tabs[i];
              final isActive = _currentIndex == i;
              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _onTabTapped(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: isActive ? tab.color : Colors.transparent,
                      borderRadius: BorderRadius.circular(RetroTheme.radiusMd),
                      border: Border.all(
                        color: isActive ? RetroTheme.border : Colors.transparent,
                        width: RetroTheme.borderWidthMedium,
                      ),
                      boxShadow: isActive
                          ? const [BoxShadow(color: Colors.black, offset: Offset(2, 2), blurRadius: 0)]
                          : null,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          tab.icon,
                          size: 20,
                          color: isActive ? Colors.black : Colors.black38,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          tab.label,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
                            color: isActive ? Colors.black : Colors.black45,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
