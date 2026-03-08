import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/theme/custom_theme.dart';
import '../../core/utils.dart';
import '../../services/notification_service.dart';
import 'notification_settings_screen.dart';

class NotificationCenterScreen extends StatefulWidget {
  const NotificationCenterScreen({super.key});

  @override
  State<NotificationCenterScreen> createState() =>
      _NotificationCenterScreenState();
}

class _NotificationCenterScreenState extends State<NotificationCenterScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _isLoading = true;
  StreamSubscription<int>? _unreadSub;

  @override
  void initState() {
    super.initState();
    NotificationService.instance.refreshState();
    _unreadSub = NotificationService.instance.unreadCountStream.listen((_) {
      if (mounted) {
        _load();
      }
    });
    _load();
  }

  @override
  void dispose() {
    _unreadSub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final items = await NotificationService.instance.fetchAll();
    if (mounted) {
      setState(() {
        _items = items;
        _isLoading = false;
      });
    }
  }

  Future<void> _markAllRead() async {
    await NotificationService.instance.markAllRead();
    setState(() {
      for (final item in _items) {
        item['is_read'] = true;
      }
    });
  }

  Future<void> _clearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final dlgColors = RetroColors.of(ctx);
        return AlertDialog(
          title: Text('Clear all notifications?', style: TextStyle(color: dlgColors.text, fontWeight: FontWeight.w800)),
          content: Text('This action cannot be undone.', style: TextStyle(color: dlgColors.textMuted)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel', style: TextStyle(color: dlgColors.textMuted, fontWeight: FontWeight.w700)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Clear all', style: TextStyle(color: dlgColors.text, fontWeight: FontWeight.w700)),
            ),
          ],
        );
      },
    );
    if (confirmed == true) {
      await NotificationService.instance.clearAll();
      setState(() => _items.clear());
    }
  }

  Future<void> _onTap(Map<String, dynamic> item) async {
    final id = item['id'];
    if (item['is_read'] != true) {
      await NotificationService.instance.markAsRead(id);
      setState(() => item['is_read'] = true);
    }
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'validation_complete':
        return LucideIcons.checkCircle;
      case 'research_complete':
        return LucideIcons.microscope;
      case 'high_score_alert':
        return LucideIcons.zap;
      case 'schedule_reminder':
        return LucideIcons.clock;
      default:
        return LucideIcons.bell;
    }
  }

  Color _colorForType(String type) {
    switch (type) {
      case 'validation_complete':
        return RetroTheme.mint;
      case 'research_complete':
        return RetroTheme.lavender;
      case 'high_score_alert':
        return RetroTheme.yellow;
      case 'schedule_reminder':
        return RetroTheme.blue;
      default:
        return RetroTheme.pink;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = RetroColors.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'NOTIFICATIONS',
          style: TextStyle(
            fontFamily: 'Outfit',
            fontWeight: FontWeight.w900,
            fontSize: RetroTheme.fontXl,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.checkCheck, size: 20),
            tooltip: 'Mark all read',
            onPressed: _items.any((i) => i['is_read'] != true)
                ? _markAllRead
                : null,
          ),
          IconButton(
            icon: Icon(LucideIcons.trash2, size: 20, color: colors.iconDefault),
            tooltip: 'Clear all',
            onPressed: _items.isNotEmpty ? _clearAll : null,
          ),
          IconButton(
            icon: const Icon(LucideIcons.settings, size: 20),
            tooltip: 'Settings',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const NotificationSettingsScreen(),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: colors.border,
                strokeWidth: 2.5,
              ),
            )
          : _items.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    LucideIcons.bellOff,
                    size: 48,
                    color: colors.iconMuted,
                  ),
                  const SizedBox(height: RetroTheme.spacingMd),
                  Text(
                    'No notifications yet',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: colors.textMuted,
                    ),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              color: colors.border,
              onRefresh: _load,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(
                  horizontal: RetroTheme.contentPaddingMobile,
                  vertical: RetroTheme.spacingMd,
                ),
                itemCount: _items.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: RetroTheme.spacingSm),
                itemBuilder: (_, i) => _buildItem(_items[i]),
              ),
            ),
    );
  }

  Widget _buildItem(Map<String, dynamic> item) {
    final colors = RetroColors.of(context);
    final type = item['type'] as String? ?? '';
    final title = item['title'] as String? ?? '';
    final body = item['body'] as String? ?? '';
    final isRead = item['is_read'] as bool? ?? false;
    final dateTime = formatDateTime(item['created_at']?.toString());
    final accentColor = _colorForType(type);

    return GestureDetector(
      onTap: () => _onTap(item),
      child: Container(
        decoration: BoxDecoration(
          color: isRead ? colors.surface : accentColor,
          borderRadius: BorderRadius.circular(RetroTheme.radiusMd),
          border: Border.all(
            color: isRead ? colors.border : Colors.black.withAlpha(40),
            width: isRead ? RetroTheme.borderWidthMedium : RetroTheme.borderWidthThin,
          ),
          boxShadow: isRead ? null : RetroTheme.shadowSmOf(context),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Icon ──
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isRead ? accentColor : Colors.black.withAlpha(20),
                  borderRadius: BorderRadius.circular(RetroTheme.radiusMd),
                  border: Border.all(
                    color: isRead ? colors.border : Colors.black.withAlpha(30),
                    width: RetroTheme.borderWidthThin,
                  ),
                ),
                child: Icon(
                  _iconForType(type),
                  size: 18,
                  color: isRead ? Colors.black : Colors.black.withAlpha(200),
                ),
              ),
              const SizedBox(width: 14),
              // ── Content ──
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontFamily: 'Outfit',
                              fontWeight: isRead ? FontWeight.w600 : FontWeight.w800,
                              fontSize: 15,
                              color: isRead ? colors.text : Colors.black,
                            ),
                          ),
                        ),
                        if (!isRead)
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(left: 8, top: 2),
                            decoration: BoxDecoration(
                              color: Colors.black.withAlpha(120),
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    if (body.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        body,
                        style: TextStyle(
                          fontSize: RetroTheme.fontSm,
                          height: 1.4,
                          color: isRead ? colors.textMuted : const Color(0xFF374151),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      dateTime,
                      style: TextStyle(
                        fontSize: RetroTheme.fontXs,
                        color: isRead ? colors.textSubtle : const Color(0xFF4B5563),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
