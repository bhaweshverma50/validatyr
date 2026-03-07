import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/theme/custom_theme.dart';
import '../../shared_widgets/retro_card.dart';
import '../../shared_widgets/retro_button.dart';
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
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final topics = await ResearchApiService.getTopics();
      if (mounted) {
        setState(() {
          _topics = topics;
          _isLoading = false;
        });
        _loadJobStatuses();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
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
      case 'apps':
        return LucideIcons.smartphone;
      case 'saas':
        return LucideIcons.globe;
      case 'hardware':
        return LucideIcons.cpu;
      case 'fintech':
        return LucideIcons.wallet;
      default:
        return LucideIcons.search;
    }
  }

  Color _domainColor(String domain) {
    switch (domain) {
      case 'apps':
        return RetroTheme.pink;
      case 'saas':
        return RetroTheme.blue;
      case 'hardware':
        return RetroTheme.orange;
      case 'fintech':
        return RetroTheme.mint;
      default:
        return RetroTheme.lavender;
    }
  }

  String _domainLabel(String domain) {
    switch (domain) {
      case 'apps':
        return 'Mobile Apps';
      case 'saas':
        return 'SaaS / Web';
      case 'hardware':
        return 'Hardware';
      case 'fintech':
        return 'FinTech';
      default:
        return 'General';
    }
  }

  String _scheduleLabel(String? schedule) {
    switch (schedule) {
      case 'daily':
        return 'Daily';
      case 'weekly':
        return 'Weekly';
      default:
        return 'Manual';
    }
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
            fontSize: 22,
            letterSpacing: -0.5,
          ),
        ),
        backgroundColor: RetroTheme.background,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.plus, color: Colors.black),
            onPressed: () async {
              final created = await Navigator.push<bool>(
                context,
                MaterialPageRoute(builder: (_) => const NewTopicScreen()),
              );
              if (created == true) _loadTopics();
            },
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: RetroCard(
            backgroundColor: RetroTheme.pink,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_errorMessage!, style: const TextStyle(fontSize: 14)),
                const SizedBox(height: 12),
                RetroButton(
                  text: 'RETRY',
                  onPressed: _loadTopics,
                  color: RetroTheme.yellow,
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (_topics.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.microscope, size: 48, color: Colors.black26),
            const SizedBox(height: 16),
            const Text(
              'No research topics yet',
              style: TextStyle(fontSize: 16, color: Colors.black45),
            ),
            const SizedBox(height: 16),
            RetroButton(
              text: 'CREATE FIRST TOPIC',
              icon: const Icon(LucideIcons.plus, size: 16),
              onPressed: () async {
                final created = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(builder: (_) => const NewTopicScreen()),
                );
                if (created == true) _loadTopics();
              },
              color: RetroTheme.lavender,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadTopics,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _topics.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
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
        backgroundColor: _domainColor(domain).withValues(alpha: 0.15),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _domainColor(domain),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.black, width: 2),
              ),
              child: Icon(_domainIcon(domain), color: Colors.black, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _domainLabel(domain),
                    style: const TextStyle(
                      fontFamily: 'Outfit',
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  if (keywords.isNotEmpty)
                    Text(
                      keywords.join(', '),
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black54,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _buildBadge(_scheduleLabel(schedule), RetroTheme.yellow),
                      if (!isActive) ...[
                        const SizedBox(width: 6),
                        _buildBadge('Paused', RetroTheme.pink),
                      ],
                      if (jobStatus == 'running' || jobStatus == 'pending') ...[
                        const SizedBox(width: 6),
                        _buildPulsingBadge(jobStep ?? 'starting...'),
                      ],
                      if (jobStatus == 'failed') ...[
                        const SizedBox(width: 6),
                        _buildBadge('Failed', Colors.red.shade300),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const Icon(LucideIcons.chevronRight, color: Colors.black38),
          ],
        ),
      ),
    );
  }

  Widget _buildPulsingBadge(String step) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: RetroTheme.mint,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.black, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 10,
            height: 10,
            child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.black),
          ),
          const SizedBox(width: 4),
          Text(
            step.replaceAll('_', ' '),
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.black, width: 1.5),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}
