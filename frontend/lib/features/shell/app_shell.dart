import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../home/home_screen.dart';
import '../research/research_dashboard_screen.dart';
import '../history/history_screen.dart';
import '../settings/settings_screen.dart';
import '../../core/theme/custom_theme.dart';
import '../../services/notification_service.dart' show NotificationService;
import '../notifications/notification_center_screen.dart';

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
    (
      icon: LucideIcons.microscope,
      label: 'Research',
      color: RetroTheme.lavender,
    ),
    (icon: LucideIcons.clock, label: 'History', color: RetroTheme.yellow),
    (icon: LucideIcons.bell, label: 'Alerts', color: RetroTheme.mint),
    (icon: LucideIcons.settings, label: 'Settings', color: RetroTheme.blue),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _screens = [
      const HomeScreen(),
      const ResearchDashboardScreen(),
      HistoryScreen(key: _historyKey),
      const SettingsScreen(),
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
      NotificationService.instance.refreshState(reconnectRealtime: true);
    }
  }

  void _onTabTapped(int i) {
    if (i == 3) {
      // Alerts tab — push notification center instead of switching screen
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const NotificationCenterScreen()),
      );
      return;
    }
    if (i == 4) {
      // Settings tab — screen index 3
      setState(() => _currentIndex = 3);
      return;
    }
    setState(() => _currentIndex = i);
    if (i == 2) {
      _historyKey.currentState?.refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final colors = RetroColors.of(context);

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border(
            top: BorderSide(color: colors.borderSubtle, width: 1),
          ),
        ),
        padding: EdgeInsets.only(
          top: 6,
          bottom: bottomPadding > 0 ? bottomPadding : 6,
        ),
        child: StreamBuilder<int>(
          stream: NotificationService.instance.unreadCountStream,
          initialData: NotificationService.instance.unreadCount,
          builder: (context, snapshot) {
            final unreadCount = snapshot.data ?? 0;
            return Row(
              children: [
                ...List.generate(_tabs.length, (i) {
                  final tab = _tabs[i];
                  // Map visual index to screen index for active check
                  final isActive = (i < 3 && _currentIndex == i) ||
                      (i == 4 && _currentIndex == 3);
                  final isAlerts = i == 3;
                  return Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _onTabTapped(i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        decoration: BoxDecoration(
                          color: isActive ? tab.color : Colors.transparent,
                          borderRadius:
                              BorderRadius.circular(RetroTheme.radiusMd),
                          border: Border.all(
                            color: isActive
                                ? colors.border
                                : Colors.transparent,
                            width: RetroTheme.borderWidthMedium,
                          ),
                          boxShadow: isActive
                              ? RetroTheme.shadowSmOf(context)
                              : null,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Icon(
                                  tab.icon,
                                  size: 20,
                                  color: isActive
                                      ? Colors.black
                                      : colors.iconMuted,
                                ),
                                if (isAlerts && unreadCount > 0)
                                  Positioned(
                                    right: -8,
                                    top: -6,
                                    child: Container(
                                      padding: const EdgeInsets.all(2.5),
                                      decoration: BoxDecoration(
                                        color: RetroTheme.pink,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.black,
                                          width: 1.5,
                                        ),
                                      ),
                                      constraints: const BoxConstraints(
                                        minWidth: 16,
                                        minHeight: 16,
                                      ),
                                      child: Text(
                                        unreadCount > 9
                                            ? '9+'
                                            : '$unreadCount',
                                        style: const TextStyle(
                                          fontSize: 8,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.black,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              tab.label,
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: isActive
                                    ? FontWeight.w800
                                    : FontWeight.w500,
                                color:
                                    isActive ? Colors.black : colors.iconMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ],
            );
          },
        ),
      ),
    );
  }
}
