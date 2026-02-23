import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/theme/custom_theme.dart';
import '../../shared_widgets/retro_card.dart';
import '../../shared_widgets/retro_button.dart';
import '../../services/supabase_service.dart';
import '../results/results_screen.dart';
import '../home/home_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final data = await SupabaseService.fetchHistory();
      setState(() {
        _items = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
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

  Future<void> _delete(String id) async {
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
        backgroundColor: RetroTheme.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black, size: 28),
        title: const Text('HISTORY',
            style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5)),
        actions: [
          if (_items.isNotEmpty)
            IconButton(
                icon: const Icon(LucideIcons.trash2, color: Colors.black),
                tooltip: 'Delete All',
                onPressed: _deleteAll),
          const SizedBox(width: 8),
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

    if (_items.isEmpty) {
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

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      itemCount: _items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (_, i) => _buildItem(_items[i]),
    );
  }

  Widget _buildItem(Map<String, dynamic> item) {
    final id = item['id'] as String? ?? '';
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
