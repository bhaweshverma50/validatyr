import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/theme/custom_theme.dart';
import '../../shared_widgets/retro_card.dart';
import '../../shared_widgets/retro_button.dart';
import '../../services/api_service.dart';
import '../../services/supabase_service.dart';
import '../results/results_screen.dart';

class _AgentStep {
  final String name;
  final String defaultMessage;
  final int stepNumber;
  _AgentStep(
      {required this.name,
      required this.defaultMessage,
      required this.stepNumber});
}

enum _StepState { pending, active, done }

class LoadingScreen extends StatefulWidget {
  final String idea;
  final String? category;
  const LoadingScreen({super.key, required this.idea, this.category});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen>
    with SingleTickerProviderStateMixin {
  final List<_AgentStep> _steps = [
    _AgentStep(
        name: 'Discovery Agent',
        defaultMessage: 'Finding competitors...',
        stepNumber: 1),
    _AgentStep(
        name: 'Researcher Agent',
        defaultMessage: 'Analyzing reviews & community...',
        stepNumber: 2),
    _AgentStep(
        name: 'PM Agent',
        defaultMessage: 'Building MVP roadmap...',
        stepNumber: 3),
    _AgentStep(
        name: 'Analyst Agent',
        defaultMessage: 'Scoring opportunity...',
        stepNumber: 4),
  ];

  late List<_StepState> _stepStates;
  late List<String> _stepMessages;

  StreamSubscription<SseEvent>? _sub;
  late final AnimationController _progressCtrl;
  late Animation<double> _progressAnim;
  bool _hasError = false;
  bool _hasResult = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _stepStates = List.filled(_steps.length, _StepState.pending);
    _stepMessages = _steps.map((s) => s.defaultMessage).toList();
    _progressCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _progressAnim = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(parent: _progressCtrl, curve: Curves.easeInOut),
    );
    _startStream();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _progressCtrl.dispose();
    super.dispose();
  }

  void _animateTo(double target) {
    final from = _progressAnim.value;
    _progressAnim = Tween<double>(begin: from, end: target).animate(
      CurvedAnimation(parent: _progressCtrl, curve: Curves.easeInOut),
    );
    _progressCtrl
      ..reset()
      ..forward();
  }

  void _startStream() {
    _sub = ApiService.validateStream(widget.idea).listen(
      _onEvent,
      onError: (e) => _setError(e.toString()),
      onDone: () {
        if (mounted && !_hasError && !_hasResult) {
          _setError(
              'Connection closed unexpectedly. Please try again.');
        }
      },
      cancelOnError: true,
    );
  }

  void _onEvent(SseEvent event) {
    if (!mounted) return;
    if (event.event == 'status') {
      final step = ((event.data['step'] as int?) ?? 1) - 1;
      final msg = event.data['message'] as String? ?? '';
      setState(() {
        for (int i = 0; i < step; i++) {
          _stepStates[i] = _StepState.done;
        }
        if (step < _steps.length) {
          _stepStates[step] = _StepState.active;
          _stepMessages[step] = msg;
        }
      });
      _animateTo((step + 0.5) / _steps.length);
    } else if (event.event == 'result') {
      setState(() {
        for (int i = 0; i < _stepStates.length; i++) {
          _stepStates[i] = _StepState.done;
        }
        _hasResult = true;
      });
      _animateTo(1.0);
      _saveAndNavigate(event.data);
    } else if (event.event == 'error') {
      _setError(event.data['message'] as String? ?? 'Unknown error');
    }
  }

  void _setError(String msg) {
    if (!mounted) return;
    setState(() {
      _hasError = true;
      _errorMessage = msg;
    });
  }

  Future<void> _saveAndNavigate(Map<String, dynamic> data) async {
    // Brief delay so the progress bar animation reaches 100% visually
    await Future.delayed(const Duration(milliseconds: 400));
    try {
      await SupabaseService.insert(widget.idea, data);
    } catch (e) {
      debugPrint('Supabase save error (non-fatal): $e');
    }
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ResultsScreen(result: data, saveToHistory: false),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(maxWidth: RetroTheme.desktopMaxWidth),
            child: SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 24),
                  Text(
                    'ANALYSING...',
                    style: Theme.of(context)
                        .textTheme
                        .displayLarge
                        ?.copyWith(
                            color: RetroTheme.pink,
                            shadows: RetroTheme.sharpShadow,
                            fontSize: 38),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '"${widget.idea.length > 60 ? '${widget.idea.substring(0, 60)}...' : widget.idea}"',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: RetroTheme.textMuted,
                        fontStyle: FontStyle.italic),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  if (!_hasError) ...[
                    _buildProgressBar(),
                    const SizedBox(height: 28),
                    _buildStepsList(),
                    const SizedBox(height: 32),
                    RetroButton(
                      text: 'Cancel',
                      color: RetroTheme.lavender,
                      onPressed: () {
                        _sub?.cancel();
                        Navigator.pop(context);
                      },
                      icon: const Icon(LucideIcons.x,
                          color: Colors.black, size: 20),
                    ),
                  ] else
                    _buildErrorCard(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('PROGRESS',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5)),
            AnimatedBuilder(
              animation: _progressAnim,
              builder: (_, __) => Text(
                '${(_progressAnim.value * 100).toInt()}%',
                style: const TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          height: 18,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.black, width: 2),
          ),
          child: AnimatedBuilder(
            animation: _progressAnim,
            builder: (_, __) => FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: _progressAnim.value.clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                    color: RetroTheme.mint,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStepsList() {
    return RetroCard(
      backgroundColor: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _steps.asMap().entries.map((e) {
          return _buildStepRow(
            e.value,
            _stepStates[e.key],
            _stepMessages[e.key],
            e.key < _steps.length - 1,
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStepRow(
      _AgentStep step, _StepState state, String message, bool divider) {
    Widget icon;
    Color bg;
    switch (state) {
      case _StepState.done:
        icon = Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
              color: RetroTheme.mint,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.black, width: 2)),
          child:
              const Icon(LucideIcons.check, size: 18, color: Colors.black),
        );
        bg = Colors.white;
      case _StepState.active:
        icon = const _PulsingIcon();
        bg = RetroTheme.yellow.withAlpha(80);
      case _StepState.pending:
        icon = Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
              color: RetroTheme.background,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.black38, width: 2)),
          child: Center(
              child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(3)))),
        );
        bg = Colors.white;
    }
    return Column(children: [
      AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        color: bg,
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(children: [
          icon,
          const SizedBox(width: 14),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(step.name,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: state == _StepState.pending
                            ? Colors.black38
                            : Colors.black)),
                const SizedBox(height: 2),
                Text(message,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: state == _StepState.pending
                            ? Colors.black26
                            : RetroTheme.textMuted)),
              ])),
        ]),
      ),
      if (divider)
        const Divider(height: 1, thickness: 1.5, color: Colors.black12),
    ]);
  }

  Widget _buildErrorCard() {
    return RetroCard(
      backgroundColor: RetroTheme.pink,
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(children: [
              Icon(LucideIcons.alertTriangle, size: 22, color: Colors.black),
              SizedBox(width: 8),
              Text('SOMETHING WENT WRONG',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.0)),
            ]),
            const SizedBox(height: 12),
            Text(_errorMessage,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    height: 1.5)),
            const SizedBox(height: 20),
            RetroButton(
              text: 'Try Again',
              color: RetroTheme.yellow,
              onPressed: () => Navigator.pop(context),
              icon: const Icon(LucideIcons.refreshCw,
                  color: Colors.black, size: 20),
            ),
          ]),
    );
  }
}

class _PulsingIcon extends StatefulWidget {
  const _PulsingIcon();

  @override
  State<_PulsingIcon> createState() => _PulsingIconState();
}

class _PulsingIconState extends State<_PulsingIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700))
      ..repeat(reverse: true);
    _opacity = Tween<double>(begin: 0.4, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
            color: RetroTheme.yellow,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.black, width: 2)),
        child: const Icon(LucideIcons.zap, size: 18, color: Colors.black),
      ),
    );
  }
}
