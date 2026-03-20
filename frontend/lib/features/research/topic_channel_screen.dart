import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/theme/custom_theme.dart';
import '../../shared_widgets/retro_card.dart';
import '../../shared_widgets/retro_button.dart';
import '../../core/utils.dart';
import '../../services/research_api_service.dart';
import 'report_detail_screen.dart';
import 'new_topic_screen.dart';

class TopicChannelScreen extends StatefulWidget {
  final Map<String, dynamic> topic;
  const TopicChannelScreen({super.key, required this.topic});

  @override
  State<TopicChannelScreen> createState() => _TopicChannelScreenState();
}

class _TopicChannelScreenState extends State<TopicChannelScreen> {
  List<Map<String, dynamic>> _reports = [];
  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _errorMessage;
  Map<String, dynamic>? _latestJob;
  List<Map<String, dynamic>> _jobHistory = [];
  bool _historyExpanded = false;

  String get _topicId => widget.topic['id']?.toString() ?? '';
  String get _domain => widget.topic['domain']?.toString() ?? 'general';
  List<String> get _keywords => List<String>.from(widget.topic['keywords'] ?? []);

  bool get _isJobRunning {
    final status = _latestJob?['status'] as String?;
    return status == 'running' || status == 'pending';
  }

  @override
  void initState() {
    super.initState();
    _loadReports();
    _loadLatestJob();
    _loadJobHistory();
  }

  Future<void> _loadReports() async {
    try {
      final reports = await ResearchApiService.getReports(_topicId);
      if (mounted) setState(() { _reports = reports; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() { _errorMessage = e.toString(); _isLoading = false; });
    }
  }

  Future<void> _loadLatestJob() async {
    try {
      final job = await ResearchApiService.getLatestJob(_topicId);
      if (mounted) setState(() => _latestJob = job);
    } catch (_) {}
  }

  Future<void> _loadJobHistory() async {
    try {
      final jobs = await ResearchApiService.getJobHistory(_topicId);
      if (mounted) setState(() => _jobHistory = jobs);
    } catch (_) {}
  }

  Future<void> _triggerResearch() async {
    setState(() => _isRefreshing = true);
    try {
      await ResearchApiService.startResearch(_topicId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Research started! Check back soon for results.')),
        );
        _loadLatestJob();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
    if (mounted) setState(() => _isRefreshing = false);
  }

  Future<void> _cancelJob() async {
    final jobId = _latestJob?['id']?.toString();
    if (jobId == null) return;
    try {
      await ResearchApiService.cancelJob(jobId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Research job cancelled.')),
        );
        _loadLatestJob();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Cancel failed: $e')));
      }
    }
  }

  Future<void> _deleteTopic() async {
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
          'Delete this topic and all its reports?',
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
      await ResearchApiService.deleteTopic(_topicId);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = RetroColors.of(context);
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _domain.toUpperCase(),
              style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w900, fontSize: RetroTheme.fontXl),
            ),
            if (_keywords.isNotEmpty)
              Text(
                _keywords.join(', '),
                style: TextStyle(fontSize: RetroTheme.fontSm, color: colors.textMuted, fontWeight: FontWeight.normal),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        actions: [
          // Stop running job
          if (_isJobRunning)
            IconButton(
              icon: const Icon(LucideIcons.square, size: 20),
              tooltip: 'Stop research',
              onPressed: _cancelJob,
            ),
          // Run research
          IconButton(
            icon: _isRefreshing
                ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: colors.text))
                : const Icon(LucideIcons.refreshCw),
            onPressed: _isRefreshing ? null : _triggerResearch,
          ),
          // Edit topic
          IconButton(
            icon: const Icon(LucideIcons.pencil, size: 20),
            tooltip: 'Edit topic',
            onPressed: () async {
              final updated = await Navigator.push<bool>(
                context,
                MaterialPageRoute(builder: (_) => NewTopicScreen(topic: widget.topic)),
              );
              if (updated == true && mounted) {
                Navigator.pop(context);
              }
            },
          ),
          // Delete topic
          IconButton(
            icon: const Icon(LucideIcons.trash2, size: 20),
            tooltip: 'Delete topic',
            onPressed: _deleteTopic,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final colors = RetroColors.of(context);
    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: colors.text, strokeWidth: 2.5));
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
                Text(_errorMessage!, style: const TextStyle(color: Colors.black)),
                const SizedBox(height: RetroTheme.spacingMd),
                RetroButton(text: 'RETRY', onPressed: _loadReports, color: RetroTheme.yellow),
              ],
            ),
          ),
        ),
      );
    }
    if (_reports.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.fileSearch, size: 48, color: colors.iconMuted),
            const SizedBox(height: RetroTheme.spacingMd),
            Text('No reports yet', style: TextStyle(fontSize: RetroTheme.fontLg, color: colors.textSubtle)),
            const SizedBox(height: RetroTheme.spacingMd),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 240),
              child: RetroButton(
                text: 'RUN NOW',
                icon: const Icon(LucideIcons.play, size: 16),
                onPressed: _triggerResearch,
                isLoading: _isRefreshing,
                color: RetroTheme.lavender,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: colors.text,
      onRefresh: () async {
        await Future.wait([_loadReports(), _loadJobHistory()]);
      },
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(
          horizontal: RetroTheme.contentPaddingMobile,
          vertical: RetroTheme.spacingMd,
        ),
        itemCount: _reports.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) return _buildRunHistory();
          return Padding(
            padding: const EdgeInsets.only(bottom: RetroTheme.spacingMd),
            child: _buildReportCard(_reports[index - 1]),
          );
        },
      ),
    );
  }

  Widget _buildRunHistory() {
    if (_jobHistory.isEmpty) return const SizedBox.shrink();
    final colors = RetroColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: RetroTheme.spacingMd),
      child: RetroCard(
        padding: const EdgeInsets.all(RetroTheme.spacingSm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () => setState(() => _historyExpanded = !_historyExpanded),
              child: Row(
                children: [
                  Icon(LucideIcons.history, size: 16, color: colors.iconMuted),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text('Run History', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w700, fontSize: 14)),
                  ),
                  Text('${_jobHistory.length} runs', style: TextStyle(fontSize: RetroTheme.fontSm, color: colors.textMuted)),
                  const SizedBox(width: 4),
                  Icon(
                    _historyExpanded ? LucideIcons.chevronUp : LucideIcons.chevronDown,
                    size: 16, color: colors.iconMuted,
                  ),
                ],
              ),
            ),
            if (_historyExpanded) ...[
              const SizedBox(height: RetroTheme.spacingSm),
              ...(_jobHistory.take(10).map(_buildJobRow)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildJobRow(Map<String, dynamic> job) {
    final colors = RetroColors.of(context);
    final status = job['status'] as String? ?? 'unknown';
    final startedAt = job['started_at']?.toString() ?? '';
    final step = job['current_step'] as String? ?? '';
    final error = job['error'] as String? ?? '';

    IconData icon;
    Color iconColor;
    switch (status) {
      case 'completed':
        icon = LucideIcons.checkCircle;
        iconColor = RetroTheme.mint;
        break;
      case 'failed':
        icon = LucideIcons.xCircle;
        iconColor = RetroTheme.pink;
        break;
      case 'cancelled':
        icon = LucideIcons.minusCircle;
        iconColor = RetroTheme.orange;
        break;
      case 'running':
      case 'pending':
        icon = LucideIcons.loader;
        iconColor = RetroTheme.blue;
        break;
      default:
        icon = LucideIcons.helpCircle;
        iconColor = colors.iconMuted;
    }

    String subtitle = status;
    if (status == 'running' && step.isNotEmpty) subtitle = step.replaceAll('_', ' ');
    if (status == 'failed' && error.isNotEmpty) {
      subtitle = error.length > 50 ? '${error.substring(0, 50)}...' : error;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icon, size: 14, color: iconColor),
          const SizedBox(width: 8),
          if (startedAt.isNotEmpty)
            Text(
              _formatJobTime(startedAt),
              style: TextStyle(fontSize: RetroTheme.fontXs, color: colors.textMuted, fontWeight: FontWeight.w600),
            ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              subtitle,
              style: TextStyle(fontSize: RetroTheme.fontXs, color: colors.textSubtle),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  String _formatJobTime(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final m = dt.minute.toString().padLeft(2, '0');
      final amPm = dt.hour < 12 ? 'AM' : 'PM';
      return '${months[dt.month - 1]} ${dt.day}, $h:$m $amPm';
    } catch (_) {
      return '';
    }
  }

  Widget _buildReportCard(Map<String, dynamic> report) {
    final colors = RetroColors.of(context);
    final ideas = List.from(report['ideas'] ?? []);
    final summary = report['executive_summary'] as String? ?? '';
    final date = formatDate(report['generated_at']?.toString());
    final time = formatTime(report['generated_at']?.toString());

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ReportDetailScreen(report: report)),
        );
      },
      child: RetroCard(
        padding: const EdgeInsets.all(RetroTheme.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(LucideIcons.barChart3, size: 16, color: colors.iconMuted),
                const SizedBox(width: RetroTheme.spacingSm),
                const Expanded(
                  child: Text('Research Report', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w700, fontSize: 15)),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(date, style: TextStyle(fontSize: RetroTheme.fontSm, color: colors.textMuted)),
                    Text(time, style: TextStyle(fontSize: RetroTheme.fontXs, color: colors.textSubtle)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: RetroTheme.spacingXs),
            Text('${ideas.length} ideas found', style: TextStyle(fontSize: RetroTheme.fontSm, color: colors.textMuted)),
            if (summary.isNotEmpty) ...[
              const SizedBox(height: RetroTheme.spacingSm),
              Text(
                summary.length > 120 ? '${summary.substring(0, 120)}...' : summary,
                style: const TextStyle(fontSize: RetroTheme.fontSm, height: 1.4),
              ),
            ],
            const SizedBox(height: RetroTheme.spacingSm),
            Align(
              alignment: Alignment.centerRight,
              child: Icon(LucideIcons.chevronRight, size: 16, color: colors.iconMuted),
            ),
          ],
        ),
      ),
    );
  }
}
