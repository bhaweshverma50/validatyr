import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/theme/custom_theme.dart';
import '../../shared_widgets/retro_card.dart';
import '../../shared_widgets/retro_button.dart';
import '../../shared_widgets/retro_skeleton.dart';
import '../../services/research_api_service.dart';
import 'new_topic_screen.dart';
import 'topic_channel_screen.dart';

class ResearchDashboardScreen extends StatefulWidget {
  const ResearchDashboardScreen({super.key});

  @override
  State<ResearchDashboardScreen> createState() =>
      _ResearchDashboardScreenState();
}

class _ResearchDashboardScreenState extends State<ResearchDashboardScreen> {
  List<Map<String, dynamic>> _topics = [];
  bool _isLoading = true;
  String? _errorMessage;
  final Map<String, Map<String, dynamic>> _topicJobs = {};

  @override
  void initState() {
    super.initState();
    _loadTopics();
  }

  Future<void> _loadTopics() async {
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      final topics = await ResearchApiService.getTopics();
      if (mounted) {
        setState(() { _topics = topics; _isLoading = false; });
        _loadJobStatuses();
      }
    } catch (e) {
      if (mounted) {
        setState(() { _errorMessage = e.toString(); _isLoading = false; });
      }
    }
  }

  Future<void> _loadJobStatuses() async {
    await Future.wait(_topics.map((topic) async {
      final topicId = topic['id']?.toString() ?? '';
      if (topicId.isEmpty) return;
      try {
        final job = await ResearchApiService.getLatestJob(topicId);
        if (mounted && job != null) {
          setState(() => _topicJobs[topicId] = job);
        }
      } catch (_) {}
    }));
  }

  IconData _domainIcon(String domain) {
    switch (domain) {
      case 'apps': return LucideIcons.smartphone;
      case 'saas': return LucideIcons.globe;
      case 'hardware': return LucideIcons.cpu;
      case 'fintech': return LucideIcons.wallet;
      default: return LucideIcons.search;
    }
  }

  Color _domainColor(String domain) {
    switch (domain) {
      case 'apps': return RetroTheme.pink;
      case 'saas': return RetroTheme.blue;
      case 'hardware': return RetroTheme.orange;
      case 'fintech': return RetroTheme.mint;
      default: return RetroTheme.lavender;
    }
  }

  String _domainLabel(String domain) {
    switch (domain) {
      case 'apps': return 'Mobile Apps';
      case 'saas': return 'SaaS / Web';
      case 'hardware': return 'Hardware';
      case 'fintech': return 'FinTech';
      default: return 'General';
    }
  }

  static const _dowLabels = {1: 'Mon', 2: 'Tue', 3: 'Wed', 4: 'Thu', 5: 'Fri', 6: 'Sat', 7: 'Sun'};
  static const _dowIndex = {1: DateTime.monday, 2: DateTime.tuesday, 3: DateTime.wednesday, 4: DateTime.thursday, 5: DateTime.friday, 6: DateTime.saturday, 7: DateTime.sunday};

  String _scheduleLabel(String? schedule) {
    if (schedule == null || schedule.isEmpty) return 'Manual';
    final parts = schedule.split('|');
    final kind = parts[0];
    if (kind == 'daily') {
      final time = parts.length >= 2 ? parts[1] : '06:00';
      return 'Daily $time';
    }
    if (kind == 'weekly') {
      final day = parts.length >= 2 ? (_dowLabels[int.tryParse(parts[1]) ?? 1] ?? 'Mon') : 'Mon';
      final time = parts.length >= 3 ? parts[2] : '06:00';
      return '$day $time';
    }
    return 'Manual';
  }

  /// Compute the next run DateTime from a schedule_cron string.
  /// If the latest job already ran today (for daily) or this week (for weekly),
  /// the next run is pushed to the next cycle.
  String _nextRunLabel(String? schedule, bool isActive, Map<String, dynamic>? latestJob) {
    if (schedule == null || schedule.isEmpty || !isActive) return '';
    try {
      final parts = schedule.split('|');
      final kind = parts[0];
      final now = DateTime.now();

      // Check if the latest job already ran in the current cycle
      DateTime? lastRunAt;
      final jobStarted = latestJob?['started_at']?.toString() ?? latestJob?['created_at']?.toString();
      if (jobStarted != null && jobStarted.isNotEmpty) {
        try { lastRunAt = DateTime.parse(jobStarted).toLocal(); } catch (_) {}
      }

      if (kind == 'daily') {
        final timeParts = (parts.length >= 2 ? parts[1] : '06:00').split(':');
        final h = int.parse(timeParts[0]);
        final m = int.parse(timeParts[1]);
        var next = DateTime(now.year, now.month, now.day, h, m);
        // Only count as "already ran" if the job ran near the scheduled time (±15 min)
        // so manual runs don't consume the scheduled slot
        final scheduledRanToday = lastRunAt != null &&
            lastRunAt.year == now.year && lastRunAt.month == now.month && lastRunAt.day == now.day &&
            (lastRunAt.hour * 60 + lastRunAt.minute - (h * 60 + m)).abs() <= 15;
        if (next.isBefore(now) || scheduledRanToday) next = next.add(const Duration(days: 1));
        return _fmtNextRun(next);
      }

      if (kind == 'weekly') {
        final targetDow = _dowIndex[int.tryParse(parts.length >= 2 ? parts[1] : '1') ?? 1] ?? DateTime.monday;
        final timeParts = (parts.length >= 3 ? parts[2] : '06:00').split(':');
        final h = int.parse(timeParts[0]);
        final m = int.parse(timeParts[1]);
        var next = DateTime(now.year, now.month, now.day, h, m);
        // Only count as "already ran" if the job ran near the scheduled time
        final scheduledRanThisWeek = lastRunAt != null &&
            now.difference(lastRunAt).inDays < 7 &&
            lastRunAt.weekday == targetDow &&
            (lastRunAt.hour * 60 + lastRunAt.minute - (h * 60 + m)).abs() <= 15;
        while (next.weekday != targetDow || next.isBefore(now) || (scheduledRanThisWeek && next.day == now.day)) {
          next = next.add(const Duration(days: 1));
        }
        return _fmtNextRun(next);
      }
    } catch (_) {}
    return '';
  }

  String _fmtNextRun(DateTime dt) {
    final now = DateTime.now();
    final diff = dt.difference(now);
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final min = dt.minute.toString().padLeft(2, '0');
    final amPm = dt.hour < 12 ? 'AM' : 'PM';
    final timeStr = '$hour:$min $amPm';

    final today = DateTime(now.year, now.month, now.day);
    final targetDay = DateTime(dt.year, dt.month, dt.day);
    final daysDiff = targetDay.difference(today).inDays;

    if (daysDiff == 0) {
      if (diff.inMinutes <= 60) return 'Next: in ${diff.inMinutes}m';
      return 'Next: today $timeStr';
    }
    if (daysDiff == 1) return 'Next: tomorrow $timeStr';
    return 'Next: ${months[dt.month - 1]} ${dt.day} $timeStr';
  }

  void _openNewTopic() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const NewTopicScreen()),
    );
    if (created == true) _loadTopics();
  }

  @override
  Widget build(BuildContext context) {
    final colors = RetroColors.of(context);
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text(
          'RESEARCH LAB',
          style: TextStyle(
            fontFamily: 'Outfit',
            fontWeight: FontWeight.w900,
            fontSize: RetroTheme.fontDisplay,
            letterSpacing: -0.5,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.plus),
            onPressed: _openNewTopic,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final colors = RetroColors.of(context);
    if (_isLoading) {
      return const RetroSkeletonList(itemCount: 3, lineCount: 2, showAvatar: true);
    }
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(RetroTheme.spacingXl),
          child: RetroCard(
            backgroundColor: RetroTheme.pink,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_errorMessage!, style: const TextStyle(fontSize: RetroTheme.fontMd, color: Colors.black)),
                const SizedBox(height: RetroTheme.spacingMd),
                RetroButton(text: 'RETRY', onPressed: _loadTopics, color: RetroTheme.yellow),
              ],
            ),
          ),
        ),
      );
    }
    if (_topics.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(RetroTheme.spacingXl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.microscope, size: 48, color: colors.iconMuted),
              const SizedBox(height: RetroTheme.spacingMd),
              Text('No research topics yet', style: TextStyle(fontSize: RetroTheme.fontLg, color: colors.textSubtle)),
              const SizedBox(height: RetroTheme.spacingMd),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 240),
                child: RetroButton(
                  text: 'NEW TOPIC',
                  icon: const Icon(LucideIcons.plus, size: 16),
                  onPressed: _openNewTopic,
                  color: RetroTheme.lavender,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: colors.text,
      onRefresh: _loadTopics,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(
          horizontal: RetroTheme.contentPaddingMobile,
          vertical: RetroTheme.spacingMd,
        ),
        itemCount: _topics.length,
        separatorBuilder: (_, __) => const SizedBox(height: RetroTheme.spacingMd),
        itemBuilder: (context, index) => _buildTopicCard(_topics[index]),
      ),
    );
  }

  Future<void> _toggleActive(Map<String, dynamic> topic) async {
    final topicId = topic['id']?.toString() ?? '';
    final isActive = topic['is_active'] as bool? ?? true;
    try {
      await ResearchApiService.toggleTopicActive(topicId, !isActive);
      _loadTopics();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _cancelRunningJob(String topicId) async {
    final latestJob = _topicJobs[topicId];
    final jobId = latestJob?['id']?.toString();
    if (jobId == null) return;
    try {
      await ResearchApiService.cancelJob(jobId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Research job cancelled.')),
        );
        _loadTopics();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Cancel failed: $e')));
      }
    }
  }

  void _editTopic(Map<String, dynamic> topic) async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => NewTopicScreen(topic: topic)),
    );
    if (updated == true) _loadTopics();
  }

  Future<void> _deleteTopic(Map<String, dynamic> topic) async {
    final topicId = topic['id']?.toString() ?? '';
    final domain = topic['domain'] as String? ?? 'general';
    final colors = RetroColors.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: colors.border, width: 3),
        ),
        title: Text('Delete Topic', style: TextStyle(fontWeight: FontWeight.w900, color: colors.text)),
        content: Text(
          'Delete "${_domainLabel(domain)}" topic and all its reports?',
          style: TextStyle(color: colors.text),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(fontWeight: FontWeight.w700, color: colors.textMuted)),
          ),
          TextButton(
            style: TextButton.styleFrom(
              backgroundColor: RetroTheme.pink,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
                side: BorderSide(color: colors.border, width: 2),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ResearchApiService.deleteTopic(topicId);
      _loadTopics();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
      }
    }
  }

  Widget _buildTopicCard(Map<String, dynamic> topic) {
    final colors = RetroColors.of(context);
    final domain = topic['domain'] as String? ?? 'general';
    final keywords = List<String>.from(topic['keywords'] ?? []);
    final schedule = topic['schedule_cron'] as String?;
    final isActive = topic['is_active'] as bool? ?? true;
    final topicId = topic['id']?.toString() ?? '';
    final latestJob = _topicJobs[topicId];
    final jobStatus = latestJob?['status'] as String?;
    final jobStep = latestJob?['current_step'] as String?;
    final isJobRunning = jobStatus == 'running' || jobStatus == 'pending';
    final hasSchedule = schedule != null && schedule.isNotEmpty;
    final nextRun = _nextRunLabel(schedule, isActive, latestJob);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => TopicChannelScreen(topic: topic)),
        ).then((_) => _loadTopics());
      },
      child: RetroCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            // Domain icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _domainColor(domain),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: colors.border, width: 2),
              ),
              child: Icon(_domainIcon(domain), color: Colors.black, size: 18),
            ),
            const SizedBox(width: 12),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _domainLabel(domain),
                    style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                  if (keywords.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        keywords.join(', '),
                        style: TextStyle(fontSize: RetroTheme.fontSm, color: colors.textMuted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      if (hasSchedule) _buildBadge(_scheduleLabel(schedule), RetroTheme.yellow),
                      if (!hasSchedule) _buildBadge('Manual', colors.surface),
                      if (!isActive) _buildBadge('Paused', RetroTheme.pink),
                      if (isJobRunning)
                        _buildPulsingBadge(jobStep ?? 'starting...'),
                      if (jobStatus == 'failed')
                        _buildBadge('Failed', Colors.red.shade300),
                      if (jobStatus == 'cancelled')
                        _buildBadge('Cancelled', Colors.orange.shade200),
                    ],
                  ),
                  if (nextRun.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        nextRun,
                        style: TextStyle(fontSize: RetroTheme.fontXs, color: colors.textSubtle),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            // Actions menu
            _buildOverflowMenu(
              topic: topic,
              topicId: topicId,
              isJobRunning: isJobRunning,
              isActive: isActive,
              hasSchedule: hasSchedule,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverflowMenu({
    required Map<String, dynamic> topic,
    required String topicId,
    required bool isJobRunning,
    required bool isActive,
    required bool hasSchedule,
  }) {
    final colors = RetroColors.of(context);
    return PopupMenuButton<String>(
      icon: Icon(LucideIcons.moreVertical, size: 18, color: colors.iconMuted),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: colors.border, width: 2),
      ),
      color: colors.surface,
      onSelected: (value) {
        switch (value) {
          case 'stop':
            _cancelRunningJob(topicId);
            break;
          case 'toggle':
            _toggleActive(topic);
            break;
          case 'edit':
            _editTopic(topic);
            break;
          case 'delete':
            _deleteTopic(topic);
            break;
        }
      },
      itemBuilder: (_) => [
        if (isJobRunning)
          const PopupMenuItem(
            value: 'stop',
            child: Row(
              children: [
                Icon(LucideIcons.square, size: 16),
                SizedBox(width: 8),
                Text('Stop research', style: TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        if (hasSchedule)
          PopupMenuItem(
            value: 'toggle',
            child: Row(
              children: [
                Icon(isActive ? LucideIcons.pause : LucideIcons.play, size: 16),
                const SizedBox(width: 8),
                Text(
                  isActive ? 'Pause schedule' : 'Resume schedule',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        const PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              Icon(LucideIcons.pencil, size: 16),
              SizedBox(width: 8),
              Text('Edit topic', style: TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(LucideIcons.trash2, size: 16, color: Colors.red),
              SizedBox(width: 8),
              Text('Delete topic', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.red)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPulsingBadge(String step) {
    final colors = RetroColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: RetroTheme.badgeDecoration(RetroTheme.mint, borderColor: colors.border),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 10, height: 10,
            child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.black), // on mint accent
          ),
          const SizedBox(width: 4),
          Text(step.replaceAll('_', ' '), style: const TextStyle(fontSize: RetroTheme.fontXs, fontWeight: FontWeight.w600, color: Colors.black)),
        ],
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: RetroTheme.badgeDecoration(color, borderColor: RetroColors.of(context).border),
      child: Text(text, style: RetroTheme.badgeStyle),
    );
  }
}

