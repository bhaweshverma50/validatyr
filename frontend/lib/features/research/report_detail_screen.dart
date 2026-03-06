import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/theme/custom_theme.dart';
import '../../shared_widgets/retro_card.dart';
import '../../shared_widgets/retro_button.dart';
import '../loading/loading_screen.dart';

class ReportDetailScreen extends StatelessWidget {
  final Map<String, dynamic> report;
  const ReportDetailScreen({super.key, required this.report});

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

  Color _trendColor(String type) {
    switch (type) {
      case 'pain_point': return RetroTheme.pink;
      case 'rising_demand': return RetroTheme.mint;
      case 'follow_trend': return RetroTheme.blue;
      default: return RetroTheme.lavender;
    }
  }

  String _trendLabel(String type) {
    switch (type) {
      case 'pain_point': return 'PAIN POINT';
      case 'rising_demand': return 'RISING DEMAND';
      case 'follow_trend': return 'FOLLOW TREND';
      default: return type.toUpperCase();
    }
  }

  IconData _trendIcon(String type) {
    switch (type) {
      case 'pain_point': return LucideIcons.flame;
      case 'rising_demand': return LucideIcons.trendingUp;
      case 'follow_trend': return LucideIcons.rocket;
      default: return LucideIcons.lightbulb;
    }
  }

  void _deepValidate(BuildContext context, Map<String, dynamic> idea) {
    final name = idea['name'] ?? '';
    final oneLiner = idea['one_liner'] ?? '';
    final problem = idea['problem_statement'] ?? '';
    final ideaText = '$name — $oneLiner. $problem';

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LoadingScreen(idea: ideaText),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final summary = report['executive_summary'] as String? ?? '';
    final overview = report['market_overview'] as String? ?? '';
    final ideas = List<Map<String, dynamic>>.from(
      (report['ideas'] as List?)?.map((e) => Map<String, dynamic>.from(e)) ?? [],
    );
    final sources = List<String>.from(report['data_sources'] ?? []);
    final date = _formatDate(report['generated_at']?.toString());

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
            const Text('RESEARCH REPORT', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w900, fontSize: 18)),
            Text(date, style: const TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.normal)),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (summary.isNotEmpty) ...[
              const Text('EXECUTIVE SUMMARY', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w800, fontSize: 14, letterSpacing: 1)),
              const SizedBox(height: 8),
              RetroCard(
                backgroundColor: RetroTheme.yellow.withValues(alpha: 0.2),
                child: Text(summary, style: const TextStyle(fontSize: 14, height: 1.5)),
              ),
              const SizedBox(height: 20),
            ],

            if (overview.isNotEmpty) ...[
              const Text('MARKET OVERVIEW', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w800, fontSize: 14, letterSpacing: 1)),
              const SizedBox(height: 8),
              RetroCard(
                child: Text(overview, style: const TextStyle(fontSize: 14, height: 1.5)),
              ),
              const SizedBox(height: 20),
            ],

            Text(
              'IDEAS (${ideas.length})',
              style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w800, fontSize: 14, letterSpacing: 1),
            ),
            const SizedBox(height: 8),
            ...ideas.asMap().entries.map((entry) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildIdeaCard(context, entry.key + 1, entry.value),
            )),

            if (sources.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text('DATA SOURCES', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w800, fontSize: 14, letterSpacing: 1)),
              const SizedBox(height: 8),
              RetroCard(
                backgroundColor: Colors.grey.shade100,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: sources.map((s) => Chip(
                    label: Text(s, style: const TextStyle(fontSize: 12)),
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: Colors.black, width: 1),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                  )).toList(),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildIdeaCard(BuildContext context, int index, Map<String, dynamic> idea) {
    final name = idea['name'] as String? ?? 'Untitled';
    final oneLiner = idea['one_liner'] as String? ?? '';
    final problem = idea['problem_statement'] as String? ?? '';
    final score = (idea['opportunity_score'] as num?)?.toDouble() ?? 0.0;
    final trendType = idea['trend_type'] as String? ?? '';
    final features = List<String>.from(idea['suggested_features'] ?? []);
    final evidence = List<String>.from(idea['trend_evidence'] ?? []);
    final monetization = idea['monetization_hint'] as String? ?? '';

    return RetroCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$index. $name',
                      style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w800, fontSize: 16),
                    ),
                    if (oneLiner.isNotEmpty)
                      Text(oneLiner, style: const TextStyle(fontSize: 13, color: Colors.black54)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: RetroTheme.scoreColor(score),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.black, width: 2),
                ),
                child: Center(
                  child: Text('${score.round()}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          if (trendType.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _trendColor(trendType),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.black, width: 1.5),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_trendIcon(trendType), size: 12),
                  const SizedBox(width: 4),
                  Text(_trendLabel(trendType), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                ],
              ),
            ),

          if (problem.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(problem, style: const TextStyle(fontSize: 13, height: 1.5)),
          ],

          if (evidence.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Text('Why now:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
            ...evidence.map((e) => Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• ', style: TextStyle(fontSize: 13)),
                  Expanded(child: Text(e, style: const TextStyle(fontSize: 12, height: 1.4))),
                ],
              ),
            )),
          ],

          if (features.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Text('MVP Features:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
            ...features.map((f) => Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• ', style: TextStyle(fontSize: 13)),
                  Expanded(child: Text(f, style: const TextStyle(fontSize: 12, height: 1.4))),
                ],
              ),
            )),
          ],

          if (monetization.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(LucideIcons.dollarSign, size: 14, color: Colors.black54),
                const SizedBox(width: 4),
                Expanded(child: Text(monetization, style: const TextStyle(fontSize: 12, color: Colors.black54))),
              ],
            ),
          ],

          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerRight,
            child: RetroButton(
              text: 'DEEP VALIDATE',
              icon: const Icon(LucideIcons.search, size: 14),
              onPressed: () => _deepValidate(context, idea),
              color: RetroTheme.mint,
            ),
          ),
        ],
      ),
    );
  }
}
