import 'dart:math';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/theme/custom_theme.dart';
import '../../shared_widgets/retro_card.dart';
import '../../services/supabase_service.dart';

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

class ResultsScreen extends StatefulWidget {
  final Map<String, dynamic> result;
  final bool saveToHistory;

  const ResultsScreen({super.key, required this.result, this.saveToHistory = true});

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.saveToHistory) _save();
  }

  Future<void> _save() async {
    try {
      final idea = widget.result['idea'] as String? ?? '';
      await SupabaseService.insert(idea, widget.result);
    } catch (e) {
      debugPrint('ResultsScreen Supabase save error (non-fatal): $e');
    }
  }

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
      {'key': 'pain_severity',          'label': 'Pain Severity',      'weight': '25%', 'color': RetroTheme.pink,     'icon': LucideIcons.flame},
      {'key': 'market_gap',             'label': 'Market Gap',         'weight': '20%', 'color': RetroTheme.blue,     'icon': LucideIcons.target},
      {'key': 'mvp_feasibility',        'label': 'MVP Feasibility',    'weight': '15%', 'color': RetroTheme.mint,     'icon': LucideIcons.wrench},
      {'key': 'competition_density',    'label': 'Competition',        'weight': '15%', 'color': RetroTheme.lavender, 'icon': LucideIcons.users},
      {'key': 'monetization_potential', 'label': 'Monetization',       'weight': '10%', 'color': RetroTheme.yellow,   'icon': LucideIcons.dollarSign},
      {'key': 'community_demand',       'label': 'Community Demand',   'weight': '10%', 'color': RetroTheme.blue,     'icon': LucideIcons.messageSquare},
      {'key': 'startup_saturation',     'label': 'Startup Saturation', 'weight': '5%',  'color': RetroTheme.lavender, 'icon': LucideIcons.building},
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: dimensions.map((dim) {
          final value = (breakdown[dim['key']] ?? 0).toDouble();
          return Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
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
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: Colors.black,
                      ),
                    ),
                    Text(
                      '  (${dim['weight']})',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black54),
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
      ),
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

  Widget _sectionLabel(String text, IconData icon) {
    return Row(children: [
      Icon(icon, size: 14, color: Colors.black54),
      const SizedBox(width: 6),
      Text(text, style: const TextStyle(
          fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.5, color: Colors.black54)),
    ]);
  }

  Widget _buildMarketSizingSection() {
    final tam = widget.result['tam'] as String? ?? '';
    final sam = widget.result['sam'] as String? ?? '';
    final som = widget.result['som'] as String? ?? '';
    if (tam.isEmpty && sam.isEmpty && som.isEmpty) return const SizedBox.shrink();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionLabel('MARKET SIZING', LucideIcons.trendingUp),
      const SizedBox(height: 10),
      IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _buildMarketCard('TAM', tam, RetroTheme.yellow),
          const SizedBox(width: 8),
          _buildMarketCard('SAM', sam, RetroTheme.mint),
          const SizedBox(width: 8),
          _buildMarketCard('SOM', som, RetroTheme.blue),
        ]),
      ),
    ]);
  }

  Widget _buildMarketCard(String label, String value, Color color) {
    return Expanded(child: RetroCard(
      backgroundColor: color,
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
        const SizedBox(height: 6),
        Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, height: 1.4)),
      ]),
    ));
  }

  Widget _buildRevenueModelsSection() {
    final items = List<dynamic>.from(widget.result['revenue_model_options'] ?? []);
    if (items.isEmpty) return const SizedBox.shrink();
    return _buildListSection('Revenue Models', LucideIcons.dollarSign, items, RetroTheme.lavender);
  }

  Widget _buildFundedCompetitorsSection() {
    final items = List<dynamic>.from(widget.result['top_funded_competitors'] ?? []);
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionLabel('FUNDED COMPETITORS', LucideIcons.building2),
      const SizedBox(height: 10),
      RetroCard(
        backgroundColor: RetroTheme.pink,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: items.asMap().entries.map((e) {
          final c = e.value is Map ? Map<String, dynamic>.from(e.value as Map) : <String, dynamic>{};
          return Padding(
            padding: EdgeInsets.only(bottom: e.key < items.length - 1 ? 14 : 0),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 28, height: 28,
                decoration: BoxDecoration(color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.black, width: 2)),
                child: Center(child: Text('${e.key + 1}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900))),
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(c['name']?.toString() ?? '', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                if ((c['funding'] ?? '').toString().isNotEmpty || (c['investors'] ?? '').toString().isNotEmpty)
                  Text('${c['funding'] ?? ''}${(c['investors'] ?? '').toString().isNotEmpty ? ' · ${c['investors']}' : ''}',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: RetroTheme.textMuted)),
              ])),
            ]),
          );
        }).toList()),
      ),
    ]);
  }

  Widget _buildGTMSection() {
    final gtm = widget.result['go_to_market_strategy'] as String? ?? '';
    if (gtm.isEmpty) return const SizedBox.shrink();
    return _buildTextSection('Go-To-Market Strategy', LucideIcons.target, gtm, RetroTheme.orange);
  }

  Widget _buildFundingLandscapeSection() {
    final fl = widget.result['funding_landscape'] as String? ?? '';
    if (fl.isEmpty) return const SizedBox.shrink();
    return _buildTextSection('Funding Landscape', LucideIcons.trendingUp, fl, RetroTheme.blue);
  }

  static const _categoryLabels = {
    'mobile_app': 'Mobile App',
    'hardware':   'Hardware',
    'fintech':    'FinTech',
    'saas_web':   'SaaS / Web',
  };

  Widget _buildCategoryBadge(String category, String subcategory) {
    final label = _categoryLabels[category] ?? category;
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.black, width: 2),
          boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(2, 2), blurRadius: 0)],
        ),
        child: Text(
          subcategory.isNotEmpty ? '$label  ·  $subcategory' : label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _buildTag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800)),
    );
  }

  Color _sourceColor(String source) {
    switch (source) {
      case 'product_hunt': return RetroTheme.pink;
      case 'ycombinator': return const Color(0xFFFF6600);
      default: return RetroTheme.lavender;
    }
  }

  String _sourceBadgeLabel(String source) {
    switch (source) {
      case 'product_hunt': return 'PH';
      case 'ycombinator': return 'YC';
      case 'play_store': return 'AND';
      case 'app_store': return 'IOS';
      default: return 'WEB';
    }
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
                      _buildTag(
                        comp['platform'].toString().toUpperCase(),
                        comp['platform'] == 'ios' ? RetroTheme.blue : RetroTheme.mint,
                      ),
                    ],
                    // Only show source badge when it's a distinct origin (PH, YC)
                    // not when it merely repeats the platform (android/ios/web)
                    if (comp['source'] != null &&
                        !{'android', 'ios', 'web', 'hardware'}.contains(
                            comp['source'].toString().toLowerCase())) ...[
                      const SizedBox(width: 4),
                      _buildTag(
                        _sourceBadgeLabel(comp['source'].toString()),
                        _sourceColor(comp['source'].toString()),
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
    final double score = (widget.result['opportunity_score'] ?? 0).toDouble();
    final Map<String, dynamic> breakdown = (widget.result['score_breakdown'] is Map)
        ? Map<String, dynamic>.from(widget.result['score_breakdown'])
        : {};
    final List<dynamic> loves = widget.result['what_users_love'] ?? [];
    final List<dynamic> hates = widget.result['what_users_hate'] ?? [];
    final List<dynamic> roadmap = widget.result['mvp_roadmap'] ?? [];
    final String marketBreakdown = widget.result['market_breakdown']?.toString() ?? '';
    final String pricing = widget.result['pricing_suggestion']?.toString() ?? '';
    final String targetOs = widget.result['target_os_recommendation']?.toString() ?? '';
    final List<dynamic> competitors = widget.result['competitors_analyzed'] ?? [];
    final List<dynamic> communitySignals = widget.result['community_signals'] ?? [];
    final String category = widget.result['category'] as String? ?? '';
    final String subcategory = widget.result['subcategory'] as String? ?? '';

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
                  IntrinsicHeight(
                    child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
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
                  ),
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

                if (category.isNotEmpty) _buildCategoryBadge(category, subcategory),

                // Hate / Love — side by side on wide, stacked on mobile
                if (isWide)
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: _buildListSection('What Users Hate', LucideIcons.thumbsDown, hates, RetroTheme.pink)),
                        const SizedBox(width: 20),
                        Expanded(child: _buildListSection('What Users Love', LucideIcons.thumbsUp, loves, RetroTheme.mint)),
                      ],
                    ),
                  )
                else ...[
                  _buildListSection('What Users Hate', LucideIcons.thumbsDown, hates, RetroTheme.pink),
                  const SizedBox(height: 20),
                  _buildListSection('What Users Love', LucideIcons.thumbsUp, loves, RetroTheme.mint),
                ],

                const SizedBox(height: 20),
                _buildListSection('Day-1 MVP Roadmap', LucideIcons.rocket, roadmap, RetroTheme.lavender),

                if (communitySignals.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _buildListSection(
                    'Community Signals',
                    LucideIcons.messageCircle,
                    communitySignals,
                    RetroTheme.orange,
                  ),
                ],

                if ((widget.result['tam'] as String? ?? '').isNotEmpty ||
                    (widget.result['sam'] as String? ?? '').isNotEmpty ||
                    (widget.result['som'] as String? ?? '').isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _buildMarketSizingSection(),
                ],
                if ((widget.result['revenue_model_options'] as List? ?? []).isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _buildRevenueModelsSection(),
                ],
                if ((widget.result['top_funded_competitors'] as List? ?? []).isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _buildFundedCompetitorsSection(),
                ],
                if ((widget.result['go_to_market_strategy'] as String? ?? '').isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _buildGTMSection(),
                ],
                if ((widget.result['funding_landscape'] as String? ?? '').isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _buildFundingLandscapeSection(),
                ],
                const SizedBox(height: 20),

                // Pricing + Market side by side on wide
                if (isWide && pricing.isNotEmpty && marketBreakdown.isNotEmpty)
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: _buildTextSection('Pricing Strategy', LucideIcons.tag, pricing, RetroTheme.yellow)),
                        const SizedBox(width: 20),
                        Expanded(child: _buildTextSection('Market Breakdown', LucideIcons.pieChart, marketBreakdown, RetroTheme.blue)),
                      ],
                    ),
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
