import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/theme/custom_theme.dart';
import '../../shared_widgets/retro_card.dart';
import '../../shared_widgets/retro_button.dart';
import '../../core/utils.dart';
import '../loading/loading_screen.dart';

class ReportDetailScreen extends StatelessWidget {
  final Map<String, dynamic> report;
  const ReportDetailScreen({super.key, required this.report});

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
      MaterialPageRoute(builder: (_) => LoadingScreen(idea: ideaText)),
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
    final dateTime = formatDateTime(report['generated_at']?.toString());

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
            const Text('RESEARCH REPORT', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w900, fontSize: RetroTheme.fontXl)),
            Text(dateTime, style: const TextStyle(fontSize: RetroTheme.fontSm, color: Colors.black54, fontWeight: FontWeight.normal)),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: RetroTheme.contentPaddingMobile,
          vertical: RetroTheme.spacingMd,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (summary.isNotEmpty) ...[
              const Text('EXECUTIVE SUMMARY', style: RetroTheme.sectionTitle),
              const SizedBox(height: RetroTheme.spacingSm),
              RetroCard(
                backgroundColor: const Color(0xFFFEF9C3),
                padding: const EdgeInsets.all(RetroTheme.spacingMd),
                child: Text(summary, style: const TextStyle(fontSize: RetroTheme.fontMd, height: 1.5)),
              ),
              const SizedBox(height: RetroTheme.spacingLg),
            ],

            if (overview.isNotEmpty) ...[
              const Text('MARKET OVERVIEW', style: RetroTheme.sectionTitle),
              const SizedBox(height: RetroTheme.spacingSm),
              RetroCard(
                padding: const EdgeInsets.all(RetroTheme.spacingMd),
                child: Text(overview, style: const TextStyle(fontSize: RetroTheme.fontMd, height: 1.5)),
              ),
              const SizedBox(height: RetroTheme.spacingLg),
            ],

            Text('IDEAS (${ideas.length})', style: RetroTheme.sectionTitle),
            const SizedBox(height: RetroTheme.spacingSm),
            ...ideas.asMap().entries.map((entry) => Padding(
              padding: const EdgeInsets.only(bottom: RetroTheme.spacingMd),
              child: _buildIdeaCard(context, entry.key + 1, entry.value),
            )),

            if (sources.isNotEmpty) ...[
              const SizedBox(height: RetroTheme.spacingSm),
              SizedBox(
                width: double.infinity,
                child: RetroCard(
                  backgroundColor: Colors.white,
                  padding: const EdgeInsets.all(RetroTheme.spacingMd),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('DATA SOURCES', style: RetroTheme.sectionTitle),
                      const SizedBox(height: RetroTheme.spacingSm + 4),
                      Wrap(
                        spacing: RetroTheme.spacingSm,
                        runSpacing: RetroTheme.spacingSm,
                        children: sources.map((s) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: RetroTheme.background,
                            borderRadius: BorderRadius.circular(RetroTheme.radiusSm),
                            border: Border.all(color: Colors.black, width: RetroTheme.borderWidthMedium),
                          ),
                          child: Text(s, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                        )).toList(),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: RetroTheme.spacingXl),
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
      padding: const EdgeInsets.all(RetroTheme.spacingMd),
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
                      style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w800, fontSize: RetroTheme.fontLg),
                    ),
                    if (oneLiner.isNotEmpty)
                      Text(oneLiner, style: const TextStyle(fontSize: RetroTheme.fontSm, color: Colors.black54)),
                  ],
                ),
              ),
              const SizedBox(width: RetroTheme.spacingMd),
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: RetroTheme.scoreColor(score),
                  borderRadius: BorderRadius.circular(RetroTheme.radiusMd),
                  border: Border.all(color: RetroTheme.border, width: RetroTheme.borderWidthMedium),
                ),
                child: Center(
                  child: Text('${score.round()}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                ),
              ),
            ],
          ),

          const SizedBox(height: RetroTheme.spacingSm),

          if (trendType.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: RetroTheme.badgeDecoration(_trendColor(trendType)),
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
            const SizedBox(height: RetroTheme.spacingSm + 2),
            Text(problem, style: const TextStyle(fontSize: RetroTheme.fontSm, height: 1.5)),
          ],

          if (evidence.isNotEmpty) ...[
            const SizedBox(height: RetroTheme.spacingSm + 2),
            const Text('Why now:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: RetroTheme.fontSm)),
            ...evidence.map((e) => Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• ', style: TextStyle(fontSize: RetroTheme.fontSm)),
                  Expanded(child: Text(e, style: const TextStyle(fontSize: RetroTheme.fontSm, height: 1.4))),
                ],
              ),
            )),
          ],

          if (features.isNotEmpty) ...[
            const SizedBox(height: RetroTheme.spacingSm + 2),
            const Text('MVP Features:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: RetroTheme.fontSm)),
            ...features.map((f) => Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• ', style: TextStyle(fontSize: RetroTheme.fontSm)),
                  Expanded(child: Text(f, style: const TextStyle(fontSize: RetroTheme.fontSm, height: 1.4))),
                ],
              ),
            )),
          ],

          if (monetization.isNotEmpty) ...[
            const SizedBox(height: RetroTheme.spacingSm),
            Row(
              children: [
                const Icon(LucideIcons.dollarSign, size: 14, color: Colors.black54),
                const SizedBox(width: 4),
                Expanded(child: Text(monetization, style: const TextStyle(fontSize: RetroTheme.fontSm, color: Colors.black54))),
              ],
            ),
          ],

          const SizedBox(height: RetroTheme.spacingMd),
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
