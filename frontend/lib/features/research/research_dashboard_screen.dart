import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/theme/custom_theme.dart';
import '../../shared_widgets/retro_card.dart';
import '../../shared_widgets/retro_button.dart';
import '../../services/research_api_service.dart';
import 'new_topic_screen.dart';
import 'topic_channel_screen.dart';
import '../../shared_widgets/notification_bell.dart';

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
    for (final topic in _topics) {
      final topicId = topic['id']?.toString() ?? '';
      if (topicId.isEmpty) continue;
      try {
        final job = await ResearchApiService.getLatestJob(topicId);
        if (mounted && job != null) {
          setState(() => _topicJobs[topicId] = job);
        }
      } catch (_) {}
    }
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

  void _openNewTopic() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const NewTopicScreen()),
    );
    if (created == true) _loadTopics();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RetroTheme.background,
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
          NotificationBell.appBarIcon(context),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2.5));
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
                Text(_errorMessage!, style: const TextStyle(fontSize: RetroTheme.fontMd)),
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
              const Icon(LucideIcons.microscope, size: 48, color: Colors.black26),
              const SizedBox(height: RetroTheme.spacingMd),
              const Text('No research topics yet', style: TextStyle(fontSize: RetroTheme.fontLg, color: Colors.black45)),
              const SizedBox(height: RetroTheme.spacingMd),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 240),
                child: RetroButton(
                  text: 'CREATE FIRST TOPIC',
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
      color: Colors.black,
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

  Widget _buildTopicCard(Map<String, dynamic> topic) {
    final domain = topic['domain'] as String? ?? 'general';
    final keywords = List<String>.from(topic['keywords'] ?? []);
    final schedule = topic['schedule_cron'] as String?;
    final isActive = topic['is_active'] as bool? ?? true;
    final topicId = topic['id']?.toString() ?? '';
    final latestJob = _topicJobs[topicId];
    final jobStatus = latestJob?['status'] as String?;
    final jobStep = latestJob?['current_step'] as String?;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => TopicChannelScreen(topic: topic)),
        ).then((_) => _loadTopics());
      },
      child: RetroCard(
        padding: const EdgeInsets.all(RetroTheme.spacingMd),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _domainColor(domain),
                borderRadius: BorderRadius.circular(RetroTheme.radiusMd),
                border: Border.all(color: RetroTheme.border, width: RetroTheme.borderWidthMedium),
              ),
              child: Icon(_domainIcon(domain), color: Colors.black, size: 20),
            ),
            const SizedBox(width: RetroTheme.spacingMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _domainLabel(domain),
                    style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  if (keywords.isNotEmpty)
                    Text(
                      keywords.join(', '),
                      style: const TextStyle(fontSize: RetroTheme.fontSm, color: Colors.black54),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: RetroTheme.spacingSm),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      _buildBadge(_scheduleLabel(schedule), RetroTheme.yellow),
                      if (!isActive) _buildBadge('Paused', RetroTheme.pink),
                      if (jobStatus == 'running' || jobStatus == 'pending')
                        _buildPulsingBadge(jobStep ?? 'starting...'),
                      if (jobStatus == 'failed')
                        _buildBadge('Failed', Colors.red.shade300),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(LucideIcons.chevronRight, color: Colors.black38, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildPulsingBadge(String step) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: RetroTheme.badgeDecoration(RetroTheme.mint),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 10, height: 10,
            child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.black),
          ),
          const SizedBox(width: 4),
          Text(step.replaceAll('_', ' '), style: const TextStyle(fontSize: RetroTheme.fontXs, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: RetroTheme.badgeDecoration(color),
      child: Text(text, style: RetroTheme.badgeStyle),
    );
  }
}
