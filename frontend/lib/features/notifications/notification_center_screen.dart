import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/theme/custom_theme.dart';
import '../../core/utils.dart';
import '../../shared_widgets/retro_card.dart';
import '../../services/notification_service.dart';
import 'notification_settings_screen.dart';

class NotificationCenterScreen extends StatefulWidget {
  const NotificationCenterScreen({super.key});

  @override
  State<NotificationCenterScreen> createState() => _NotificationCenterScreenState();
}

class _NotificationCenterScreenState extends State<NotificationCenterScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final items = await NotificationService.instance.fetchAll();
    if (mounted) setState(() { _items = items; _isLoading = false; });
  }

  Future<void> _markAllRead() async {
    await NotificationService.instance.markAllRead();
    setState(() {
      for (final item in _items) {
        item['is_read'] = true;
      }
    });
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
      case 'validation_complete': return LucideIcons.checkCircle;
      case 'research_complete': return LucideIcons.microscope;
      case 'high_score_alert': return LucideIcons.zap;
      case 'schedule_reminder': return LucideIcons.clock;
      default: return LucideIcons.bell;
    }
  }

  Color _colorForType(String type) {
    switch (type) {
      case 'validation_complete': return RetroTheme.mint;
      case 'research_complete': return RetroTheme.lavender;
      case 'high_score_alert': return RetroTheme.yellow;
      case 'schedule_reminder': return RetroTheme.blue;
      default: return RetroTheme.pink;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RetroTheme.background,
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
            onPressed: _items.any((i) => i['is_read'] != true) ? _markAllRead : null,
          ),
          IconButton(
            icon: const Icon(LucideIcons.settings, size: 20),
            tooltip: 'Settings',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NotificationSettingsScreen()),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2.5))
          : _items.isEmpty
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(LucideIcons.bellOff, size: 48, color: Colors.black26),
                    const SizedBox(height: RetroTheme.spacingMd),
                    Text('No notifications yet',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(color: RetroTheme.textMuted)),
                  ]),
                )
              : RefreshIndicator(
                  color: Colors.black,
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: RetroTheme.contentPaddingMobile,
                      vertical: RetroTheme.spacingMd,
                    ),
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: RetroTheme.spacingSm),
                    itemBuilder: (_, i) => _buildItem(_items[i]),
                  ),
                ),
    );
  }

  Widget _buildItem(Map<String, dynamic> item) {
    final type = item['type'] as String? ?? '';
    final title = item['title'] as String? ?? '';
    final body = item['body'] as String? ?? '';
    final isRead = item['is_read'] as bool? ?? false;
    final dateTime = formatDateTime(item['created_at']?.toString());

    return GestureDetector(
      onTap: () => _onTap(item),
      child: RetroCard(
        backgroundColor: isRead ? Colors.white : _colorForType(type).withAlpha(40),
        padding: EdgeInsets.zero,
        child: IntrinsicHeight(
          child: Row(
            children: [
              if (!isRead)
                Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: _colorForType(type),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(RetroTheme.radiusMd),
                      bottomLeft: Radius.circular(RetroTheme.radiusMd),
                    ),
                  ),
                ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: _colorForType(type),
                          borderRadius: BorderRadius.circular(RetroTheme.radiusSm),
                          border: Border.all(color: RetroTheme.border, width: RetroTheme.borderWidthThin),
                        ),
                        child: Icon(_iconForType(type), size: 16, color: Colors.black),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: TextStyle(
                                fontFamily: 'Outfit',
                                fontWeight: isRead ? FontWeight.w600 : FontWeight.w800,
                                fontSize: RetroTheme.fontMd,
                              ),
                            ),
                            if (body.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                body,
                                style: const TextStyle(fontSize: RetroTheme.fontSm, color: Colors.black54),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                            const SizedBox(height: 4),
                            Text(
                              dateTime,
                              style: const TextStyle(fontSize: RetroTheme.fontXs, color: Colors.black38, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
