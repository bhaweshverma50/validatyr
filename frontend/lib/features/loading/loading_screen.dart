import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/theme/custom_theme.dart';
import '../../shared_widgets/retro_card.dart';
import '../../shared_widgets/retro_button.dart';
import '../../services/api_service.dart';
import '../../services/supabase_service.dart';
import '../../services/validation_job_recovery.dart';
import '../results/results_screen.dart';

class _AgentStep {
  final String name;
  final String defaultMessage;
  final int stepNumber;
  _AgentStep({
    required this.name,
    required this.defaultMessage,
    required this.stepNumber,
  });
}

enum _StepState { pending, active, done }

class LoadingScreen extends StatefulWidget {
  final String idea;
  final String? category;
  final String? jobId;
  const LoadingScreen({
    super.key,
    required this.idea,
    this.category,
    this.jobId,
  });

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static const _categoryLabels = {
    'mobile_app': 'Mobile App',
    'hardware': 'Hardware',
    'fintech': 'FinTech',
    'saas_web': 'SaaS / Web',
  };

  final List<String> _stepNames = [];
  final List<String> _stepMessages = [];
  final List<_StepState> _stepStates = [];
  int _totalSteps = 6;
  String? _detectedCategoryLabel;

  StreamSubscription<SseEvent>? _sub;
  late final AnimationController _progressCtrl;
  late Animation<double> _progressAnim;
  bool _hasError = false;
  bool _hasResult = false;
  bool _wasBackgrounded = false;
  String _errorMessage = '';
  String? _jobId;
  Timer? _pollTimer;
  bool _isPolling = false;
  int _completedSyncAttempts = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _progressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _progressAnim = Tween<double>(
      begin: 0,
      end: 0,
    ).animate(CurvedAnimation(parent: _progressCtrl, curve: Curves.easeInOut));
    // Seed the first step: Category Detector
    _stepNames.add('Category Detector');
    _stepMessages.add(
      widget.category != null
          ? 'Category: ${_categoryLabels[widget.category] ?? widget.category}'
          : 'Classifying your idea...',
    );
    _stepStates.add(_StepState.active);
    _jobId = widget.jobId;
    if (_jobId != null) {
      _startPolling();
    } else {
      _startStream();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sub?.cancel();
    _pollTimer?.cancel();
    _progressCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _wasBackgrounded = true;
    }
    if (state == AppLifecycleState.resumed && _wasBackgrounded && !_hasResult) {
      _wasBackgrounded = false;
      if (!_hasError && !_isPolling && mounted) {
        _sub?.cancel();
        if (_jobId != null) {
          _startPolling();
        } else {
          _recoverActiveJob(startPolling: true);
        }
      }
    }
  }

  void _animateTo(double target) {
    final from = _progressAnim.value;
    _progressAnim = Tween<double>(
      begin: from,
      end: target,
    ).animate(CurvedAnimation(parent: _progressCtrl, curve: Curves.easeInOut));
    _progressCtrl
      ..reset()
      ..forward();
  }

  void _startStream() {
    _sub = ApiService.validateStream(widget.idea, category: widget.category).listen(
      _onEvent,
      onError: (e) {
        _handleStreamDisconnect(e.toString());
      },
      onDone: () {
        if (mounted && !_hasError && !_hasResult) {
          _handleStreamDisconnect(
            'Connection closed unexpectedly. '
            'If analysis was in progress, results may still be saved — check History.',
          );
        }
      },
      cancelOnError: true,
    );
  }

  void _startPolling() {
    if (_isPolling || _jobId == null) return;
    setState(() => _isPolling = true);
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) => _pollJob());
    _pollJob();
  }

  Future<void> _pollJob() async {
    if (!mounted || _hasResult || _hasError) {
      _pollTimer?.cancel();
      return;
    }
    final job = await ApiService.fetchValidationJob(_jobId!);
    if (job == null || !mounted) return;

    final status = job['status'] as String? ?? 'pending';

    if (status == 'completed') {
      final resultId = job['result_id'];
      _markAllStepsDone();

      if (resultId == null) {
        _completedSyncAttempts++;
        if (_completedSyncAttempts >= 8) {
          _pollTimer?.cancel();
          _setError(
            'Validation finished, but the result is still syncing. '
            'Please try History again in a few seconds.',
          );
        }
        return;
      }

      final result = await _waitForPersistedResult(resultId);
      if (result != null && mounted) {
        _pollTimer?.cancel();
        _hasResult = true;
        await Future.delayed(const Duration(milliseconds: 400));
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ResultsScreen(result: result, saveToHistory: false),
          ),
        );
        return;
      }

      _completedSyncAttempts++;
      if (_completedSyncAttempts >= 8) {
        _pollTimer?.cancel();
        _setError(
          'Validation finished, but the result is still syncing. '
          'Please try History again in a few seconds.',
        );
      }
      return;
    }

    if (status == 'failed' || status == 'cancelled') {
      _pollTimer?.cancel();
      if (status == 'cancelled') {
        if (mounted) Navigator.pop(context);
        return;
      }
      _setError(job['error'] as String? ?? 'Validation failed');
      return;
    }

    _syncUiFromJob(job);
  }

  void _onEvent(SseEvent event) {
    if (!mounted) return;
    if (event.event == 'job') {
      _jobId = event.data['job_id'] as String?;
      return;
    }
    if (event.event == 'category') {
      final label = event.data['label'] as String?;
      setState(() => _detectedCategoryLabel = label);
    } else if (event.event == 'status') {
      final stepIdx = ((event.data['step'] as int?) ?? 1) - 1;
      final total = (event.data['total'] as int?) ?? 5;
      final agentName = event.data['agent'] as String? ?? '';
      final msg = event.data['message'] as String? ?? '';
      setState(() {
        _totalSteps = total;
        // Grow lists dynamically to accommodate stepIdx
        while (_stepNames.length <= stepIdx) {
          _stepNames.add('');
          _stepMessages.add('');
          _stepStates.add(_StepState.pending);
        }
        _stepNames[stepIdx] = agentName;
        _stepMessages[stepIdx] = msg;
        // Mark previous steps done
        for (int i = 0; i < stepIdx; i++) {
          _stepStates[i] = _StepState.done;
        }
        _stepStates[stepIdx] = _StepState.active;
      });
      _animateTo((stepIdx + 0.5) / _totalSteps);
    } else if (event.event == 'result') {
      _hasResult = true;
      setState(() {
        for (int i = 0; i < _stepStates.length; i++) {
          _stepStates[i] = _StepState.done;
        }
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

  Future<void> _handleStreamDisconnect(String fallbackMessage) async {
    if (_hasResult || _hasError) return;
    if (_jobId != null) {
      _startPolling();
      return;
    }

    final recovered = await _recoverActiveJob(startPolling: true);
    if (!recovered && mounted) {
      _setError(fallbackMessage);
    }
  }

  Future<bool> _recoverActiveJob({required bool startPolling}) async {
    final jobs = await ApiService.fetchActiveJobs();
    if (!mounted) return false;

    final matchedJob = matchActiveValidationJob(
      jobs,
      idea: widget.idea,
      category: widget.category,
    );
    final matchedJobId = matchedJob?['id'] as String?;
    if (matchedJobId == null) return false;

    _jobId = matchedJobId;
    _syncUiFromJob(matchedJob!);
    if (startPolling) {
      _startPolling();
    }
    return true;
  }

  // Known pipeline steps so we can backfill completed ones when resuming.
  static const _pipelineSteps = [
    {'name': 'Category Detector', 'msg': 'Completed'},
    {'name': 'Discovery Agent', 'msg': 'Completed'},
    {'name': 'Community Scanner', 'msg': 'Completed'},
    {'name': 'Researcher Agent', 'msg': 'Completed'},
    {'name': 'PM Agent', 'msg': 'Completed'},
    {'name': 'Market Intelligence', 'msg': 'Completed'},
  ];

  void _syncUiFromJob(Map<String, dynamic> job) {
    final stepNum = (job['step_number'] as int?) ?? 0;
    final total = (job['total_steps'] as int?) ?? 6;
    final agent = job['current_step'] as String? ?? '';
    final msg = job['step_message'] as String? ?? '';

    if (stepNum <= 0 || agent.isEmpty || !mounted) return;

    final stepIdx = stepNum - 1;
    setState(() {
      _totalSteps = total;
      // Ensure lists are large enough
      while (_stepNames.length <= stepIdx) {
        _stepNames.add('');
        _stepMessages.add('');
        _stepStates.add(_StepState.pending);
      }
      // Backfill completed steps that are missing names
      for (int i = 0; i < stepIdx; i++) {
        if (_stepNames[i].isEmpty && i < _pipelineSteps.length) {
          _stepNames[i] = _pipelineSteps[i]['name']!;
          _stepMessages[i] = _pipelineSteps[i]['msg']!;
        }
        _stepStates[i] = _StepState.done;
      }
      _stepNames[stepIdx] = agent;
      _stepMessages[stepIdx] = msg;
      _stepStates[stepIdx] = _StepState.active;
    });
    _animateTo((stepIdx + 0.5) / _totalSteps);
  }

  void _markAllStepsDone() {
    if (!mounted) return;
    setState(() {
      for (int i = 0; i < _stepStates.length; i++) {
        _stepStates[i] = _StepState.done;
      }
    });
    _animateTo(1.0);
  }

  Future<Map<String, dynamic>?> _waitForPersistedResult(
    dynamic resultId,
  ) async {
    for (int attempt = 0; attempt < 4; attempt++) {
      final result = await SupabaseService.fetchById(resultId);
      if (result != null) {
        return result;
      }
      if (attempt < 3) {
        await Future.delayed(const Duration(seconds: 2));
      }
    }
    return null;
  }

  Future<void> _saveAndNavigate(Map<String, dynamic> data) async {
    // Brief delay so the progress bar animation reaches 100% visually
    await Future.delayed(const Duration(milliseconds: 400));
    // Backend now saves to Supabase before sending the result event,
    // so we skip the client-side save to avoid duplicates.
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
    final colors = RetroColors.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          tooltip: 'Back (job continues in background)',
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: RetroTheme.desktopMaxWidth,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ANALYSING heading — same style as VALIDATYR. on home
                  Text(
                    'ANALYSING...',
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(
                      color: RetroTheme.pink,
                      shadows: [
                        Shadow(color: colors.border, offset: const Offset(1, 1), blurRadius: 0),
                        Shadow(color: colors.border, offset: const Offset(2, 2), blurRadius: 0),
                        Shadow(color: colors.border, offset: const Offset(3, 3), blurRadius: 0),
                      ],
                      fontSize: 40,
                      height: 1.0,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    '"${widget.idea.length > 60 ? '${widget.idea.substring(0, 60)}...' : widget.idea}"',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors.textMuted,
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (_detectedCategoryLabel != null)
                    Center(
                      child: Container(
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: RetroTheme.mint,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: colors.border, width: 2),
                          boxShadow: RetroTheme.shadowSmOf(context),
                        ),
                        child: Text(
                          (_detectedCategoryLabel ?? '').toUpperCase(),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                            color: Colors.black, // on mint accent
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 32),
                  if (!_hasError) ...[
                    _buildProgressBar(),
                    const SizedBox(height: 28),
                    _buildStepsList(),
                    const SizedBox(height: 32),
                    RetroButton(
                      text: 'Cancel Job',
                      color: RetroTheme.pink,
                      onPressed: () {
                        _sub?.cancel();
                        _pollTimer?.cancel();
                        if (_jobId != null) {
                          ApiService.cancelValidationJob(_jobId!);
                        }
                        Navigator.pop(context);
                      },
                      icon: const Icon(
                        LucideIcons.x,
                        color: Colors.black,
                        size: 20,
                      ),
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
    final colors = RetroColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'PROGRESS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
              ),
            ),
            AnimatedBuilder(
              animation: _progressAnim,
              builder: (_, __) => Text(
                '${(_progressAnim.value * 100).toInt()}%',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          height: 18,
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: colors.border, width: 2),
          ),
          child: AnimatedBuilder(
            animation: _progressAnim,
            builder: (_, __) => FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: _progressAnim.value.clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  color: RetroTheme.mint,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStepsList() {
    final colors = RetroColors.of(context);
    return RetroCard(
      backgroundColor: colors.surface,
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (int i = 0; i < _stepNames.length; i++)
              if (_stepNames[i].isNotEmpty)
                _buildStepRow(
                  _AgentStep(
                    name: _stepNames[i],
                    defaultMessage: _stepMessages[i],
                    stepNumber: i + 1,
                  ),
                  _stepStates[i],
                  _stepMessages[i],
                  i < _stepNames.length - 1 &&
                      _stepNames.skip(i + 1).any((n) => n.isNotEmpty),
                ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepRow(
    _AgentStep step,
    _StepState state,
    String message,
    bool divider,
  ) {
    final colors = RetroColors.of(context);
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
            border: Border.all(color: colors.border, width: 2),
          ),
          child: const Icon(LucideIcons.check, size: 18, color: Colors.black),
        );
        bg = colors.surface;
      case _StepState.active:
        icon = const _PulsingIcon();
        bg = RetroTheme.yellow.withAlpha(80);
      case _StepState.pending:
        icon = Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: colors.background,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: colors.iconMuted, width: 2),
          ),
          child: Center(
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: colors.iconMuted,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        );
        bg = colors.surface;
    }
    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          color: bg,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          child: Row(
            children: [
              icon,
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      step.name,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: state == _StepState.pending
                            ? colors.textSubtle
                            : colors.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      message,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: state == _StepState.pending
                            ? colors.iconMuted
                            : colors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (divider)
          Divider(height: 1, thickness: 1.5, color: colors.borderSubtle),
      ],
    );
  }

  Widget _buildErrorCard() {
    return RetroCard(
      backgroundColor: RetroTheme.pink,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(LucideIcons.alertTriangle, size: 22, color: Colors.black),
              SizedBox(width: 8),
              Text(
                'SOMETHING WENT WRONG',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.0,
                  color: Colors.black,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _errorMessage,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              height: 1.5,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 20),
          RetroButton(
            text: 'Try Again',
            color: RetroTheme.yellow,
            onPressed: () => Navigator.pop(context),
            icon: const Icon(
              LucideIcons.refreshCw,
              color: Colors.black,
              size: 20,
            ),
          ),
          const SizedBox(height: 10),
          RetroButton(
            text: 'Check History',
            color: RetroTheme.mint,
            onPressed: () {
              // Pop back to AppShell — the History tab's auto-refresh
              // will pick up the result once the backend finishes saving.
              Navigator.popUntil(context, (route) => route.isFirst);
            },
            icon: const Icon(
              LucideIcons.history,
              color: Colors.black,
              size: 20,
            ),
          ),
        ],
      ),
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
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
    _opacity = Tween<double>(begin: 0.4, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = RetroColors.of(context);
    return FadeTransition(
      opacity: _opacity,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: RetroTheme.yellow,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: colors.border, width: 2),
        ),
        child: const Icon(LucideIcons.zap, size: 18, color: Colors.black),
      ),
    );
  }
}
