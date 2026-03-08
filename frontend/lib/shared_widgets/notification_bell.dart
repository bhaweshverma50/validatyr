import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../core/theme/custom_theme.dart';
import '../services/notification_service.dart';
import '../features/notifications/notification_center_screen.dart';

/// Shared notification bell widget used in AppBars and as a floating button.
class NotificationBell {
  NotificationBell._();

  /// Bell icon for use in AppBar `actions` lists.
  static Widget appBarIcon(BuildContext context) {
    return StreamBuilder<int>(
      stream: NotificationService.instance.unreadCountStream,
      initialData: NotificationService.instance.unreadCount,
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;
        return IconButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const NotificationCenterScreen()),
          ),
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(LucideIcons.bell, color: count > 0 ? Colors.black : Colors.black54),
              if (count > 0)
                Positioned(
                  right: -4,
                  top: -4,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: RetroTheme.pink,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.black, width: 1.5),
                    ),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text(
                      count > 9 ? '9+' : '$count',
                      style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Colors.black),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  /// Floating retro-styled bell button (for screens without AppBar).
  static Widget floating(BuildContext context) {
    return StreamBuilder<int>(
      stream: NotificationService.instance.unreadCountStream,
      initialData: NotificationService.instance.unreadCount,
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;
        return GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const NotificationCenterScreen()),
          ),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: count > 0 ? RetroTheme.pink : RetroTheme.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.black, width: 2),
              boxShadow: const [
                BoxShadow(color: Colors.black, offset: Offset(2, 2), blurRadius: 0),
              ],
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                const Center(
                  child: Icon(LucideIcons.bell, size: 18, color: Colors.black),
                ),
                if (count > 0)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: RetroTheme.yellow,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.black, width: 1.5),
                      ),
                      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                      child: Text(
                        count > 9 ? '9+' : '$count',
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          color: Colors.black,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
