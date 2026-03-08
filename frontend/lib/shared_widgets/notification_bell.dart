import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../core/theme/custom_theme.dart';
import '../services/notification_service.dart';
import '../features/notifications/notification_center_screen.dart';

/// Shared notification bell widget used in AppBars and as a floating button.
class NotificationBell {
  NotificationBell._();

  static Widget _buildBadge(int count, RetroColors colors) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: RetroTheme.yellow,
        shape: BoxShape.circle,
        border: Border.all(color: colors.border, width: 1.5),
      ),
      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
      child: Text(
        count > 9 ? '9+' : '$count',
        style: const TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w900,
          color: Colors.black, // text on yellow accent
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  /// Bell icon for use in AppBar `actions` lists.
  static Widget appBarIcon(BuildContext context) {
    final colors = RetroColors.of(context);
    return StreamBuilder<int>(
      stream: NotificationService.instance.unreadCountStream,
      initialData: NotificationService.instance.unreadCount,
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const NotificationCenterScreen(),
              ),
            ),
            child: SizedBox(
              width: 44,
              height: 44,
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Icon(
                        LucideIcons.bell,
                        size: 24,
                        color: colors.iconDefault,
                      ),
                      if (count > 0)
                        Positioned(
                          right: -6,
                          top: -4,
                          child: _buildBadge(count, colors),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Floating retro-styled bell button (for screens without AppBar).
  static Widget floating(BuildContext context) {
    final colors = RetroColors.of(context);
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
              color: count > 0 ? RetroTheme.mint : colors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: colors.border, width: 2),
              boxShadow: RetroTheme.shadowSmOf(context),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Center(
                  child: Icon(LucideIcons.bell, size: 18,
                    color: count > 0 ? Colors.black : colors.iconDefault, // black on mint accent
                  ),
                ),
                if (count > 0)
                  Positioned(right: -4, top: -4, child: _buildBadge(count, colors)),
              ],
            ),
          ),
        );
      },
    );
  }
}
