import 'dart:math';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/theme/custom_theme.dart';
import '../../shared_widgets/retro_card.dart';

class _ScoreGaugePainter extends CustomPainter {
  final double score;
  final Color scoreColor;

  _ScoreGaugePainter({required this.score, required this.scoreColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 15;
    const strokeWidth = 28.0;
    const startAngle = -pi / 2;
    final sweepAngle = 2 * pi * (score / 100);

    // Border ring
    final borderPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth + 6;
    canvas.drawCircle(center, radius, borderPaint);

    // Background track
    final bgPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bgPaint);

    // Score arc
    if (score > 0) {
      final scorePaint = Paint()
        ..color = scoreColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        scorePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ScoreGaugePainter old) =>
      old.score != score || old.scoreColor != scoreColor;
}

class ResultsScreen extends StatelessWidget {
  final Map<String, dynamic> result;

  const ResultsScreen({super.key, required this.result});

  Widget _buildScoreGauge(double score) {
    final color = RetroTheme.scoreColor(score);
    return SizedBox(
      height: 180,
      width: 180,
      child: Stack(
        children: [
          CustomPaint(
            size: const Size(180, 180),
            painter: _ScoreGaugePainter(score: score, scoreColor: color),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${score.toInt()}',
                  style: const TextStyle(
                    fontSize: 44,
                    fontWeight: FontWeight.w900,
                    color: Colors.black,
                    height: 1.0,
                  ),
                ),
                const Text(
                  '/100',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreBreakdown(Map<String, dynamic> breakdown) {
    final dimensions = [
      {'key': 'pain_severity', 'label': 'Pain Severity', 'weight': '30%', 'color': RetroTheme.pink, 'icon': LucideIcons.flame},
      {'key': 'market_gap', 'label': 'Market Gap', 'weight': '25%', 'color': RetroTheme.blue, 'icon': LucideIcons.target},
      {'key': 'mvp_feasibility', 'label': 'MVP Feasibility', 'weight': '20%', 'color': RetroTheme.mint, 'icon': LucideIcons.wrench},
      {'key': 'competition_density', 'label': 'Competition', 'weight': '15%', 'color': RetroTheme.lavender, 'icon': LucideIcons.users},
      {'key': 'monetization_potential', 'label': 'Monetization', 'weight': '10%', 'color': RetroTheme.yellow, 'icon': LucideIcons.dollarSign},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: dimensions.map((dim) {
        final value = (breakdown[dim['key']] ?? 0).toDouble();
        return Padding(
          padding: const EdgeInsets.only(bottom: 14.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(dim['icon'] as IconData, size: 14, color: Colors.black),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      dim['label'] as String,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                    ),
                  ),
                  Text(
                    '${value.toInt()}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: RetroTheme.scoreColor(value) == RetroTheme.yellow ? Colors.black : RetroTheme.scoreColor(value),
                    ),
                  ),
                  Text(
                    '  (${dim['weight']})',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black38),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Container(
                height: 16,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.black, width: 2),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: (value / 100).clamp(0.0, 1.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: dim['color'] as Color,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildListSection(String title, IconData icon, List<dynamic> items, Color color) {
    if (items.isEmpty) return const SizedBox.shrink();

    return RetroCard(
      backgroundColor: color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 22, color: Colors.black),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...items.asMap().entries.map((entry) => Padding(
                padding: const EdgeInsets.only(bottom: 10.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Center(
                        child: Text(
                          '${entry.key + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        entry.value.toString(),
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, height: 1.5),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildTextSection(String title, IconData icon, String content, Color color) {
    if (content.isEmpty) return const SizedBox.shrink();

    return RetroCard(
      backgroundColor: color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 22, color: Colors.black),
              const SizedBox(width: 8),
              Text(
                title.toUpperCase(),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1.0),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, height: 1.6),
          ),
        ],
      ),
    );
  }

  Widget _buildCompetitorsSection(List<dynamic> competitors) {
    if (competitors.isEmpty) return const SizedBox.shrink();

    return RetroCard(
      backgroundColor: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(LucideIcons.search, size: 22, color: Colors.black),
              SizedBox(width: 8),
              Text(
                'COMPETITORS ANALYZED',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1.0),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: competitors.map((c) {
              final comp = c is Map ? c : {};
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: RetroTheme.background,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.black, width: 2),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      comp['title']?.toString() ?? comp['app_id']?.toString() ?? 'Unknown',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                    if (comp['platform'] != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: comp['platform'] == 'ios' ? RetroTheme.blue : RetroTheme.mint,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          comp['platform'].toString().toUpperCase(),
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double score = (result['opportunity_score'] ?? 0).toDouble();
    final Map<String, dynamic> breakdown = (result['score_breakdown'] is Map)
        ? Map<String, dynamic>.from(result['score_breakdown'])
        : {};
    final List<dynamic> loves = result['what_users_love'] ?? [];
    final List<dynamic> hates = result['what_users_hate'] ?? [];
    final List<dynamic> roadmap = result['mvp_roadmap'] ?? [];
    final String marketBreakdown = result['market_breakdown']?.toString() ?? '';
    final String pricing = result['pricing_suggestion']?.toString() ?? '';
    final String targetOs = result['target_os_recommendation']?.toString() ?? '';
    final List<dynamic> competitors = result['competitors_analyzed'] ?? [];

    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth > RetroTheme.tabletBreakpoint;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: RetroTheme.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black, size: 28),
        title: const Text(
          'RESULTS',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, letterSpacing: 1.5),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: isWide ? 40.0 : 20.0,
              vertical: 24.0,
            ),
            child: Column(
              children: [
                // Score + Breakdown row on desktop, column on mobile
                if (isWide && breakdown.isNotEmpty)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Score gauge card
                      Expanded(
                        flex: 2,
                        child: RetroCard(
                          backgroundColor: RetroTheme.yellow,
                          child: Column(
                            children: [
                              const Text(
                                'OPPORTUNITY SCORE',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1.0),
                              ),
                              const SizedBox(height: 20),
                              _buildScoreGauge(score),
                              if (targetOs.isNotEmpty) ...[
                                const SizedBox(height: 16),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: Colors.black, width: 2),
                                  ),
                                  child: Text(
                                    'Target: $targetOs',
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 20),
                      // Breakdown card
                      Expanded(
                        flex: 3,
                        child: RetroCard(
                          backgroundColor: Colors.white,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Row(
                                children: [
                                  Icon(LucideIcons.barChart3, size: 20, color: Colors.black),
                                  SizedBox(width: 8),
                                  Text(
                                    'SCORE BREAKDOWN',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1.0),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              _buildScoreBreakdown(breakdown),
                            ],
                          ),
                        ),
                      ),
                    ],
                  )
                else ...[
                  // Mobile: stacked
                  RetroCard(
                    backgroundColor: RetroTheme.yellow,
                    child: Column(
                      children: [
                        const Text(
                          'OPPORTUNITY SCORE',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1.0),
                        ),
                        const SizedBox(height: 20),
                        _buildScoreGauge(score),
                        if (targetOs.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.black, width: 2),
                            ),
                            child: Text(
                              'Target: $targetOs',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (breakdown.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    RetroCard(
                      backgroundColor: Colors.white,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Row(
                            children: [
                              Icon(LucideIcons.barChart3, size: 20, color: Colors.black),
                              SizedBox(width: 8),
                              Text(
                                'SCORE BREAKDOWN',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1.0),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildScoreBreakdown(breakdown),
                        ],
                      ),
                    ),
                  ],
                ],

                const SizedBox(height: 20),

                // Hate / Love — side by side on wide, stacked on mobile
                if (isWide)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _buildListSection('What Users Hate', LucideIcons.thumbsDown, hates, RetroTheme.pink)),
                      const SizedBox(width: 20),
                      Expanded(child: _buildListSection('What Users Love', LucideIcons.thumbsUp, loves, RetroTheme.mint)),
                    ],
                  )
                else ...[
                  _buildListSection('What Users Hate', LucideIcons.thumbsDown, hates, RetroTheme.pink),
                  const SizedBox(height: 20),
                  _buildListSection('What Users Love', LucideIcons.thumbsUp, loves, RetroTheme.mint),
                ],

                const SizedBox(height: 20),
                _buildListSection('Day-1 MVP Roadmap', LucideIcons.rocket, roadmap, RetroTheme.lavender),

                const SizedBox(height: 20),

                // Pricing + Market side by side on wide
                if (isWide && pricing.isNotEmpty && marketBreakdown.isNotEmpty)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _buildTextSection('Pricing Strategy', LucideIcons.tag, pricing, RetroTheme.yellow)),
                      const SizedBox(width: 20),
                      Expanded(child: _buildTextSection('Market Breakdown', LucideIcons.pieChart, marketBreakdown, RetroTheme.blue)),
                    ],
                  )
                else ...[
                  _buildTextSection('Pricing Strategy', LucideIcons.tag, pricing, RetroTheme.yellow),
                  if (marketBreakdown.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _buildTextSection('Market Breakdown', LucideIcons.pieChart, marketBreakdown, RetroTheme.blue),
                  ],
                ],

                if (competitors.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _buildCompetitorsSection(competitors),
                ],

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
