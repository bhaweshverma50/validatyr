import 'dart:io';

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import '../../core/theme/custom_theme.dart';
import '../../services/api_service.dart';
import '../../shared_widgets/retro_card.dart';
import '../../shared_widgets/retro_button.dart';
import '../loading/loading_screen.dart';

typedef _CategoryEntry = ({String? id, String label, IconData icon});

class HomeScreen extends StatefulWidget {
  final String? initialIdea;
  const HomeScreen({super.key, this.initialIdea});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _ideaController = TextEditingController();
  final AudioRecorder _audioRecorder = AudioRecorder();

  bool _isLoading = false;
  bool _isRecording = false;
  AnimationController? _pulseController;
  String? _emptyInputError;
  String? _transcribeError;
  String? _selectedCategory; // null = Auto-detect

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    if (widget.initialIdea != null && widget.initialIdea!.isNotEmpty) {
      _ideaController.text = widget.initialIdea!;
    }
  }

  Future<String> _createRecordingPath() async {
    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '${tempDir.path}/validatyr-recording-$timestamp.m4a';
  }

  @override
  void dispose() {
    _ideaController.dispose();
    _audioRecorder.dispose();
    _pulseController?.dispose();
    super.dispose();
  }

  Future<void> _toggleRecording() async {
    try {
      if (_isRecording) {
        final path = await _audioRecorder.stop();
        _pulseController?.stop();
        setState(() {
          _isRecording = false;
        });

        if (path == null) {
          setState(
            () => _transcribeError =
                'No speech detected. Try recording again or type your idea.',
          );
          return;
        }

        final audioFile = File(path);
        final fileSize = await audioFile.length();
        if (fileSize < 10000) {
          setState(
            () => _transcribeError =
                'No speech detected. Try recording again or type your idea.',
          );
          return;
        }

        setState(() {
          _isLoading = true;
          _transcribeError = null;
        });

        try {
          final transcript = await ApiService.transcribeAudio(path);
          if (!mounted) return;

          setState(() {
            _isLoading = false;
            if (transcript != null && transcript.trim().isNotEmpty) {
              _ideaController.text = transcript.trim();
              _transcribeError = null;
            } else {
              _transcribeError =
                  'No speech detected. Try recording again or type your idea.';
            }
          });
        } finally {
          if (await audioFile.exists()) {
            await audioFile.delete();
          }
        }
      } else {
        final hasPermission = await _audioRecorder.hasPermission();
        if (!hasPermission) {
          setState(
            () => _transcribeError =
                'Microphone permission is required to record your idea.',
          );
          return;
        }

        final recordingPath = await _createRecordingPath();
        await _audioRecorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc, numChannels: 1),
          path: recordingPath,
        );

        setState(() {
          _transcribeError = null;
          _emptyInputError = null;
          _isRecording = true;
        });
        _pulseController?.repeat(reverse: true);
      }
    } catch (e) {
      _pulseController?.stop();
      setState(() {
        _isLoading = false;
        _isRecording = false;
        _transcribeError = 'Recording error: ${e.toString()}';
      });
    }
  }

  void _validateIdea() {
    final text = _ideaController.text.trim();
    if (text.isEmpty) {
      setState(
        () =>
            _emptyInputError = 'Please enter your app idea before validating.',
      );
      return;
    }
    setState(() => _emptyInputError = null);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LoadingScreen(idea: text, category: _selectedCategory),
      ),
    );
  }

  static const List<_CategoryEntry> _categories = [
    (id: null, label: 'Auto', icon: LucideIcons.zap),
    (id: 'mobile_app', label: 'Mobile', icon: LucideIcons.smartphone),
    (id: 'hardware', label: 'Hardware', icon: LucideIcons.cpu),
    (id: 'fintech', label: 'FinTech', icon: LucideIcons.creditCard),
    (id: 'saas_web', label: 'SaaS/Web', icon: LucideIcons.monitor),
  ];

  Widget _buildCategorySelector() {
    final colors = RetroColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 10),
          child: Text(
            'IDEA TYPE',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.8,
              color: colors.textMuted,
            ),
          ),
        ),
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 4, right: 4),
            itemCount: _categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final cat = _categories[i];
              final isSelected = _selectedCategory == cat.id;
              return GestureDetector(
                onTap: () => setState(() => _selectedCategory = cat.id),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected ? RetroTheme.yellow : colors.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? colors.border : colors.textSubtle,
                      width: isSelected ? 2.5 : 1.5,
                    ),
                    boxShadow: isSelected
                        ? RetroTheme.shadowSmOf(context)
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(cat.icon, size: 13,
                        color: isSelected ? Colors.black : colors.text,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        cat.label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected
                              ? FontWeight.w800
                              : FontWeight.w600,
                          color: isSelected ? Colors.black : colors.text,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  static const _samplePrompts = [
    '🐕 A social network for dog owners to arrange playdates',
    '💤 An app that detects and improves your sleep quality using mic',
    '🧾 AI receipt scanner that auto-splits bills between friends',
    '🌱 A habit tracker that donates to charity when you hit streaks',
    '🎙️ Podcast summariser that turns episodes into 60-second briefs',
    '🚗 An app to find and share cheap parking spots in real time',
  ];

  Widget _buildSamplePrompts() {
    final colors = RetroColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 12),
          child: Row(
            children: [
              Container(width: 18, height: 2, color: colors.textMuted),
              const SizedBox(width: 8),
              Text(
                'OR TRY AN EXAMPLE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.8,
                  color: colors.textMuted,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 4, right: 8),
            itemCount: _samplePrompts.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final prompt = _samplePrompts[i];
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _ideaController.text = prompt.substring(2).trim();
                    _emptyInputError = null;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: colors.border, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: colors.border,
                        offset: const Offset(2, 2),
                        blurRadius: 0,
                      ),
                    ],
                  ),
                  child: Text(
                    prompt,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = RetroColors.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isDesktop = screenWidth > RetroTheme.mobileBreakpoint;
    final horizontalPadding = isDesktop ? 48.0 : 24.0;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: RetroTheme.desktopMaxWidth,
            ),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: 0,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: screenHeight - 80),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(height: isDesktop ? 24 : 12),

                    // ── Hero section ──────────────────────────────────
                    _buildHero(context, isDesktop),

                    const SizedBox(height: 20),

                    // ── Category selector ─────────────────────────────
                    _buildCategorySelector(),

                    const SizedBox(height: 16),

                    // ── Input card ────────────────────────────────────
                    _buildInputCard(),

                    const SizedBox(height: 24),

                    // ── Sample prompts ────────────────────────────────
                    _buildSamplePrompts(),

                    const SizedBox(height: 32),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHero(BuildContext context, bool isDesktop) {
    final colors = RetroColors.of(context);
    return Column(
      children: [
        // Badge
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: RetroTheme.yellow,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: colors.border, width: 2),
              boxShadow: [
                BoxShadow(
                  color: colors.border,
                  offset: const Offset(2, 2),
                  blurRadius: 0,
                ),
              ],
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.zap, size: 12, color: Colors.black),
                SizedBox(width: 5),
                Text(
                  'AI-POWERED IDEA VALIDATION',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Title — multi-step extrusion shadow (no gap between text and shadow)
        Text(
          'VALIDATYR.',
          style: Theme.of(context).textTheme.displayLarge?.copyWith(
            color: RetroTheme.pink,
            shadows: [
              Shadow(color: colors.border, offset: const Offset(1, 1), blurRadius: 0),
              Shadow(color: colors.border, offset: const Offset(2, 2), blurRadius: 0),
              Shadow(color: colors.border, offset: const Offset(3, 3), blurRadius: 0),
            ],
            fontSize: isDesktop ? 56 : 44,
            height: 1.0,
          ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 12),

        // Subtitle
        Text(
          'Describe your app idea.\nGet a data-backed market report in 60 seconds.',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontSize: isDesktop ? 17 : 15,
            height: 1.55,
            color: colors.textMuted,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildInputCard() {
    final colors = RetroColors.of(context);
    return RetroCard(
      backgroundColor: RetroTheme.mint,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Recording indicator
          if (_isRecording && _pulseController != null)
            AnimatedBuilder(
              animation: _pulseController!,
              builder: (_, __) => Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Color.lerp(
                    RetroTheme.pink,
                    RetroTheme.pink.withAlpha(150),
                    _pulseController!.value,
                  ),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: colors.border, width: 2),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.circle, color: Colors.red, size: 10),
                    SizedBox(width: 8),
                    Text(
                      'Recording... Tap mic to stop',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Text field + mic
          Stack(
            children: [
              TextField(
                controller: _ideaController,
                maxLines: 5,
                enabled: !_isRecording,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  color: colors.text, // inside input with surface bg
                ),
                onTapOutside: (_) =>
                    FocusManager.instance.primaryFocus?.unfocus(),
                onChanged: (_) {
                  if (_emptyInputError != null) {
                    setState(() => _emptyInputError = null);
                  }
                },
                decoration: InputDecoration(
                  hintText: 'e.g. A social network for dog owners...',
                  fillColor: colors.surface,
                  contentPadding: const EdgeInsets.only(
                    left: 16,
                    right: 56,
                    top: 16,
                    bottom: 16,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: _emptyInputError != null
                          ? Colors.red
                          : colors.border,
                      width: 2.5,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: colors.border, width: 3),
                  ),
                  disabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: colors.textSubtle,
                      width: 2,
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 10,
                right: 10,
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: _isLoading ? null : _toggleRecording,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _isRecording
                            ? RetroTheme.pink
                            : RetroTheme.yellow,
                        shape: BoxShape.circle,
                        border: Border.all(color: colors.border, width: 2.5),
                        boxShadow: _isRecording
                            ? []
                            : [
                                BoxShadow(
                                  color: colors.border,
                                  offset: const Offset(2, 2),
                                  blurRadius: 0,
                                ),
                              ],
                      ),
                      child: const Icon(
                        LucideIcons.mic,
                        color: Colors.black,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Empty input error
          if (_emptyInputError != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  const Icon(
                    LucideIcons.alertCircle,
                    size: 13,
                    color: Colors.red,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _emptyInputError!,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.red,
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 16),

          // Validate button
          RetroButton(
            text: 'Validate My Idea',
            color: RetroTheme.yellow,
            isLoading: _isLoading,
            onPressed: _validateIdea,
            icon: _isLoading
                ? null
                : const Icon(LucideIcons.zap, color: Colors.black, size: 18),
          ),

          // Transcribe error
          if (_transcribeError != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: RetroTheme.pink.withAlpha(180),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.red, width: 2),
                ),
                child: Row(
                  children: [
                    const Icon(
                      LucideIcons.alertTriangle,
                      size: 13,
                      color: Colors.red,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _transcribeError!,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.red,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
