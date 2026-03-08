import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/theme/custom_theme.dart';
import '../../shared_widgets/retro_card.dart';
import '../../shared_widgets/retro_button.dart';
import '../../services/api_service.dart';
import '../../services/supabase_service.dart';
import '../loading/loading_screen.dart';
import '../results/results_screen.dart';
import '../../shared_widgets/notification_bell.dart';
import '../home/home_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => HistoryScreenState();
}

class HistoryScreenState extends State<HistoryScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _runningJobs = [];
  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  /// Called by AppShell when the History tab becomes active or app resumes.
  void refresh() => _load(silent: true);

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }
    try {
      final results = await Future.wait([
        ApiService.fetchActiveJobs(),
        SupabaseService.fetchHistory(),
      ]);
      if (mounted) {
        setState(() {
          _runningJobs = results[0];
          _items = results[1];
          _isLoading = false;
          _errorMessage = null;
        });
        _manageAutoRefresh();
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

  void _manageAutoRefresh() {
    if (_runningJobs.isNotEmpty) {
      _autoRefreshTimer ??= Timer.periodic(
        const Duration(seconds: 5),
        (_) => _load(silent: true),
      );
    } else {
      _autoRefreshTimer?.cancel();
      _autoRefreshTimer = null;
    }
  }

  Future<bool> _confirm(
      {required String title, required String message}) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: RetroTheme.background,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Colors.black, width: 3)),
        title:
            Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        content: Text(message),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel',
                  style: TextStyle(fontWeight: FontWeight.w700))),
          TextButton(
            style: TextButton.styleFrom(
                backgroundColor: RetroTheme.pink,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                    side:
                        const BorderSide(color: Colors.black, width: 2))),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete',
                style: TextStyle(
                    color: Colors.black, fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _delete(dynamic id) async {
    if (!await _confirm(
        title: 'Delete Validation',
        message: 'Permanently delete this result?')) {
      return;
    }
    try {
      await SupabaseService.delete(id);
      setState(() => _items.removeWhere((i) => i['id'] == id));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Delete failed: $e')));
      }
    }
  }

  Future<void> _deleteAll() async {
    if (!await _confirm(
        title: 'Delete All History',
        message:
            'Permanently delete all ${_items.length} validations?')) {
      return;
    }
    try {
      await SupabaseService.deleteAll();
      setState(() => _items.clear());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Delete all failed: $e')));
      }
    }
  }

  String _fmtDate(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      const m = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return '${m[dt.month - 1]} ${dt.day}, ${dt.year}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('HISTORY',
            style: TextStyle(
                fontFamily: 'Outfit',
                color: Colors.black,
                fontWeight: FontWeight.w900,
                fontSize: RetroTheme.fontDisplay,
                letterSpacing: -0.5)),
        actions: [
          if (_items.isNotEmpty)
            IconButton(
                icon: const Icon(LucideIcons.trash2),
                tooltip: 'Delete All',
                onPressed: _deleteAll),
          NotificationBell.appBarIcon(context),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
          child: CircularProgressIndicator(
              color: Colors.black, strokeWidth: 3));
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: RetroCard(
            backgroundColor: RetroTheme.pink,
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Row(children: [
                    Icon(LucideIcons.alertTriangle, size: 20),
                    SizedBox(width: 8),
                    Text('FAILED TO LOAD',
                        style: TextStyle(
                            fontWeight: FontWeight.w900, fontSize: 16))
                  ]),
                  const SizedBox(height: 10),
                  Text(_errorMessage!,
                      style: const TextStyle(fontSize: 13)),
                  const SizedBox(height: 16),
                  RetroButton(
                      text: 'Retry',
                      color: RetroTheme.yellow,
                      onPressed: _load,
                      icon: const Icon(LucideIcons.refreshCw,
                          size: 18, color: Colors.black)),
                ]),
          ),
        ),
      );
    }

    if (_items.isEmpty && _runningJobs.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(LucideIcons.inbox, size: 56, color: Colors.black26),
          const SizedBox(height: 16),
          Text('No validations yet.',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(color: RetroTheme.textMuted)),
        ]),
      );
    }

    return RefreshIndicator(
      color: Colors.black,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: RetroTheme.contentPaddingMobile,
          vertical: RetroTheme.spacingMd,
        ),
        children: [
          if (_runningJobs.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text('RUNNING',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                      color: Colors.black54)),
            ),
            ..._runningJobs.map((job) => Padding(
              padding: const EdgeInsets.only(bottom: RetroTheme.spacingMd),
              child: _buildRunningJobCard(job),
            )),
            if (_items.isNotEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 4, bottom: 8),
                child: Text('COMPLETED',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                        color: Colors.black54)),
              ),
          ],
          ..._items.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: RetroTheme.spacingMd),
            child: _buildItem(item),
          )),
        ],
      ),
    );
  }

  Widget _buildItem(Map<String, dynamic> item) {
    final id = item['id'];  // raw value (int from Supabase bigserial)
    final idea = item['idea'] as String? ?? '';
    final score = (item['opportunity_score'] as num?)?.toDouble() ?? 0;
    final scoreColor = RetroTheme.scoreColor(score);
    final displayIdea =
        idea.length > 80 ? '${idea.substring(0, 80)}...' : idea;

    return RetroCard(
      backgroundColor: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
                color: scoreColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.black, width: 2.5)),
            child: Center(
                child: Text('${score.toInt()}',
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Colors.black))),
          ),
          const SizedBox(width: 14),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(displayIdea,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        height: 1.4)),
                const SizedBox(height: 4),
                Text(_fmtDate(item['created_at'] as String?),
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.black38)),
              ])),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
              child: _SmallBtn(
                  label: 'View',
                  color: RetroTheme.mint,
                  icon: LucideIcons.eye,
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => ResultsScreen(
                              result:
                                  Map<String, dynamic>.from(item)))))),
          const SizedBox(width: 8),
          Expanded(
              child: _SmallBtn(
                  label: 'Edit & Rerun',
                  color: RetroTheme.blue,
                  icon: LucideIcons.refreshCw,
                  onTap: () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => HomeScreen(initialIdea: idea)));
                  })),
          const SizedBox(width: 8),
          Expanded(
              child: _SmallBtn(
                  label: 'Delete',
                  color: RetroTheme.pink,
                  icon: LucideIcons.trash2,
                  onTap: () => _delete(id))),
        ]),
      ]),
    );
  }
  Widget _buildRunningJobCard(Map<String, dynamic> job) {
    final idea = job['idea'] as String? ?? '';
    final agent = job['current_step'] as String? ?? 'Starting...';
    final stepNum = (job['step_number'] as int?) ?? 0;
    final total = (job['total_steps'] as int?) ?? 6;
    final displayIdea = idea.length > 60 ? '${idea.substring(0, 60)}...' : idea;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => LoadingScreen(
              idea: idea,
              category: job['category'] as String?,
              jobId: job['id'] as String,
            ),
          ),
        ).then((_) => _load(silent: true));
      },
      child: RetroCard(
        backgroundColor: RetroTheme.yellow.withAlpha(60),
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          const _PulsingDot(),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(displayIdea,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      height: 1.3)),
              const SizedBox(height: 4),
              Text('$agent · Step $stepNum/$total',
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.black54)),
            ],
          )),
          const Icon(LucideIcons.chevronRight, size: 18, color: Colors.black38),
        ]),
      ),
    );
  }
}

class _SmallBtn extends StatefulWidget {
  final String label;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  const _SmallBtn(
      {required this.label,
      required this.color,
      required this.icon,
      required this.onTap});

  @override
  State<_SmallBtn> createState() => _SmallBtnState();
}

class _SmallBtnState extends State<_SmallBtn> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        transform:
            Matrix4.translationValues(_pressed ? 2 : 0, _pressed ? 2 : 0, 0),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: widget.color,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.black, width: 2),
          boxShadow: _pressed
              ? []
              : const [
                  BoxShadow(
                      color: Colors.black,
                      offset: Offset(2, 2),
                      blurRadius: 0)
                ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(widget.icon, size: 13, color: Colors.black),
            const SizedBox(width: 5),
            Text(widget.label,
                style: const TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  const _PulsingDot();
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.3, end: 1.0).animate(_ctrl),
      child: Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: RetroTheme.yellow,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.black, width: 1.5),
        ),
      ),
    );
  }
}
