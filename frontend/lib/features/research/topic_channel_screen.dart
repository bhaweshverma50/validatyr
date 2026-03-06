import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/theme/custom_theme.dart';
import '../../shared_widgets/retro_card.dart';
import '../../shared_widgets/retro_button.dart';
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
    if (mounted) setState(() => _isRefreshing = false);
  }

  String _formatDate(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso);
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
    } catch (_) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RetroTheme.background,
      appBar: AppBar(
        backgroundColor: RetroTheme.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _domain.toUpperCase(),
              style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w900, fontSize: 18),
            ),
            if (_keywords.isNotEmpty)
              Text(
                _keywords.join(', '),
                style: const TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.normal),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: _isRefreshing
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(LucideIcons.refreshCw, color: Colors.black),
            onPressed: _isRefreshing ? null : _triggerResearch,
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
                Text(_errorMessage!),
                const SizedBox(height: 12),
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
            const SizedBox(height: 16),
            const Text('No reports yet', style: TextStyle(fontSize: 16, color: Colors.black45)),
            const SizedBox(height: 16),
            RetroButton(
              text: 'RUN RESEARCH NOW',
              icon: const Icon(LucideIcons.play, size: 16),
              onPressed: _triggerResearch,
              isLoading: _isRefreshing,
              color: RetroTheme.lavender,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadReports,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _reports.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) => _buildReportCard(_reports[index]),
      ),
    );
  }

  Widget _buildReportCard(Map<String, dynamic> report) {
    final ideas = List.from(report['ideas'] ?? []);
    final summary = report['executive_summary'] as String? ?? '';
    final date = _formatDate(report['generated_at']?.toString());

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ReportDetailScreen(report: report)),
        );
      },
      child: RetroCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(LucideIcons.barChart3, size: 18, color: Colors.black54),
                const SizedBox(width: 8),
                const Text('Research Report', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w700, fontSize: 15)),
                const Spacer(),
                Text(date, style: const TextStyle(fontSize: 12, color: Colors.black45)),
              ],
            ),
            const SizedBox(height: 4),
            Text('${ideas.length} ideas found', style: const TextStyle(fontSize: 13, color: Colors.black54)),
            if (summary.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                summary.length > 120 ? '${summary.substring(0, 120)}...' : summary,
                style: const TextStyle(fontSize: 13, height: 1.4),
              ),
            ],
            const SizedBox(height: 8),
            const Align(
              alignment: Alignment.centerRight,
              child: Icon(LucideIcons.chevronRight, size: 18, color: Colors.black38),
            ),
          ],
        ),
      ),
    );
  }
}
