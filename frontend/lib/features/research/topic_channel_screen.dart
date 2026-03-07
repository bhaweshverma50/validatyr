import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/theme/custom_theme.dart';
import '../../shared_widgets/retro_card.dart';
import '../../shared_widgets/retro_button.dart';
import '../../core/utils.dart';
import '../../services/research_api_service.dart';
import 'report_detail_screen.dart';

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

  String get _topicId => widget.topic['id']?.toString() ?? '';
  String get _domain => widget.topic['domain']?.toString() ?? 'general';
  List<String> get _keywords => List<String>.from(widget.topic['keywords'] ?? []);

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    try {
      final reports = await ResearchApiService.getReports(_topicId);
      if (mounted) setState(() { _reports = reports; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() { _errorMessage = e.toString(); _isLoading = false; });
    }
  }

  Future<void> _triggerResearch() async {
    setState(() => _isRefreshing = true);
    try {
      await ResearchApiService.startResearch(_topicId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Research started! Check back soon for results.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
    if (mounted) setState(() => _isRefreshing = false);
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
                style: const TextStyle(fontSize: RetroTheme.fontSm, color: Colors.black54, fontWeight: FontWeight.normal),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: _isRefreshing
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                : const Icon(LucideIcons.refreshCw),
            onPressed: _isRefreshing ? null : _triggerResearch,
          ),
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
                Text(_errorMessage!),
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
            const Icon(LucideIcons.fileSearch, size: 48, color: Colors.black26),
            const SizedBox(height: RetroTheme.spacingMd),
            const Text('No reports yet', style: TextStyle(fontSize: RetroTheme.fontLg, color: Colors.black45)),
            const SizedBox(height: RetroTheme.spacingMd),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 240),
              child: RetroButton(
                text: 'RUN RESEARCH NOW',
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
      color: Colors.black,
      onRefresh: _loadReports,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(
          horizontal: RetroTheme.contentPaddingMobile,
          vertical: RetroTheme.spacingMd,
        ),
        itemCount: _reports.length,
        separatorBuilder: (_, __) => const SizedBox(height: RetroTheme.spacingMd),
        itemBuilder: (context, index) => _buildReportCard(_reports[index]),
      ),
    );
  }

  Widget _buildReportCard(Map<String, dynamic> report) {
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
                const Icon(LucideIcons.barChart3, size: 16, color: Colors.black54),
                const SizedBox(width: RetroTheme.spacingSm),
                const Expanded(
                  child: Text('Research Report', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w700, fontSize: 15)),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(date, style: const TextStyle(fontSize: RetroTheme.fontSm, color: Colors.black54)),
                    Text(time, style: const TextStyle(fontSize: RetroTheme.fontXs, color: Colors.black38)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: RetroTheme.spacingXs),
            Text('${ideas.length} ideas found', style: const TextStyle(fontSize: RetroTheme.fontSm, color: Colors.black54)),
            if (summary.isNotEmpty) ...[
              const SizedBox(height: RetroTheme.spacingSm),
              Text(
                summary.length > 120 ? '${summary.substring(0, 120)}...' : summary,
                style: const TextStyle(fontSize: RetroTheme.fontSm, height: 1.4),
              ),
            ],
            const SizedBox(height: RetroTheme.spacingSm),
            const Align(
              alignment: Alignment.centerRight,
              child: Icon(LucideIcons.chevronRight, size: 16, color: Colors.black38),
            ),
          ],
        ),
      ),
    );
  }
}
