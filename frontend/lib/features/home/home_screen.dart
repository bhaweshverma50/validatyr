import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/theme/custom_theme.dart';
import '../../shared_widgets/retro_card.dart';
import '../../shared_widgets/retro_button.dart';
import '../../services/api_service.dart';
import '../loading/loading_screen.dart';
import '../history/history_screen.dart';

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
          _transcribeError = null;
        });

        if (path != null) {
          setState(() => _isLoading = true);
          try {
            final transcript = await ApiService.transcribeAudio(path);
            if (transcript != null && transcript.isNotEmpty) {
              setState(() => _ideaController.text = transcript);
            } else {
              setState(() => _transcribeError =
                  'Could not transcribe audio. Please type your idea instead.');
            }
          } finally {
            setState(() => _isLoading = false);
          }
        }
      } else {
        if (await _audioRecorder.hasPermission()) {
          final dir = await getApplicationDocumentsDirectory();
          final path =
              '${dir.path}/idea_${DateTime.now().millisecondsSinceEpoch}.m4a';
          await _audioRecorder.start(
              const RecordConfig(encoder: AudioEncoder.aacLc),
              path: path);
          _pulseController?.repeat(reverse: true);
          setState(() {
            _isRecording = true;
            _transcribeError = null;
          });
        }
      }
    } catch (e) {
      setState(() => _transcribeError = 'Recording error: ${e.toString()}');
    }
  }

  void _validateIdea() {
    final text = _ideaController.text.trim();
    if (text.isEmpty) {
      setState(() =>
          _emptyInputError = 'Please enter your app idea before validating.');
      return;
    }
    setState(() => _emptyInputError = null);
    Navigator.push(
        context, MaterialPageRoute(builder: (_) => LoadingScreen(idea: text, category: _selectedCategory)));
  }

  static const _categories = [
    {'id': null, 'label': 'Auto', 'icon': LucideIcons.zap},
    {'id': 'mobile_app', 'label': 'Mobile', 'icon': LucideIcons.smartphone},
    {'id': 'hardware', 'label': 'Hardware', 'icon': LucideIcons.cpu},
    {'id': 'fintech', 'label': 'FinTech', 'icon': LucideIcons.creditCard},
    {'id': 'saas_web', 'label': 'SaaS/Web', 'icon': LucideIcons.monitor},
  ];

  Widget _buildCategorySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 10),
          child: Text('IDEA TYPE', style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w800,
            letterSpacing: 1.8, color: RetroTheme.textMuted,
          )),
        ),
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: _categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final cat = _categories[i];
              final isSelected = _selectedCategory == cat['id'];
              return GestureDetector(
                onTap: () => setState(() => _selectedCategory = cat['id'] as String?),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? RetroTheme.yellow : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? Colors.black : Colors.black38,
                      width: isSelected ? 2.5 : 1.5,
                    ),
                    boxShadow: isSelected
                        ? const [BoxShadow(color: Colors.black, offset: Offset(2, 2), blurRadius: 0)]
                        : null,
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(cat['icon'] as IconData, size: 13, color: Colors.black),
                    const SizedBox(width: 6),
                    Text(cat['label'] as String, style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    )),
                  ]),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 12),
          child: Row(
            children: [
              Container(
                width: 18,
                height: 2,
                color: RetroTheme.textMuted,
              ),
              const SizedBox(width: 8),
              Text(
                'OR TRY AN EXAMPLE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.8,
                  color: RetroTheme.textMuted,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.only(right: 8),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.black, width: 2),
                    boxShadow: const [
                      BoxShadow(
                          color: Colors.black,
                          offset: Offset(2, 2),
                          blurRadius: 0),
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
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isDesktop = screenWidth > RetroTheme.mobileBreakpoint;
    final horizontalPadding = isDesktop ? 48.0 : 24.0;

    return Scaffold(
      backgroundColor: RetroTheme.background,
      appBar: AppBar(
        backgroundColor: RetroTheme.background,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.history, color: Colors.black, size: 22),
            tooltip: 'History',
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const HistoryScreen())),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(maxWidth: RetroTheme.desktopMaxWidth),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding, vertical: 0),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: screenHeight - kToolbarHeight - 80,
                ),
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

                    // ── Footer ────────────────────────────────────────
                    _buildFooter(context),

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
    return Column(
      children: [
        // Badge
        Center(
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: RetroTheme.yellow,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.black, width: 2),
              boxShadow: const [
                BoxShadow(
                    color: Colors.black,
                    offset: Offset(2, 2),
                    blurRadius: 0),
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
              shadows: const [
                Shadow(color: Colors.black, offset: Offset(1, 1), blurRadius: 0),
                Shadow(color: Colors.black, offset: Offset(2, 2), blurRadius: 0),
                Shadow(color: Colors.black, offset: Offset(3, 3), blurRadius: 0),
              ],
              fontSize: isDesktop ? 56 : 44,
              height: 1.0),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 12),

        // Subtitle
        Text(
          'Describe your app idea.\nGet a data-backed market report in 60 seconds.',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontSize: isDesktop ? 17 : 15,
              height: 1.55,
              color: RetroTheme.textMuted),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildInputCard() {
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Color.lerp(RetroTheme.pink,
                      RetroTheme.pink.withAlpha(150), _pulseController!.value),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.black, width: 2),
                ),
                child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.circle, color: Colors.red, size: 10),
                      SizedBox(width: 8),
                      Text('Recording... Tap mic to stop',
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 13)),
                    ]),
              ),
            ),

          // Text field + mic
          Stack(children: [
            TextField(
              controller: _ideaController,
              maxLines: 5,
              enabled: !_isRecording,
              style:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              onChanged: (_) {
                if (_emptyInputError != null) {
                  setState(() => _emptyInputError = null);
                }
              },
              decoration: InputDecoration(
                hintText: 'e.g. A social network for dog owners...',
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.only(
                    left: 16, right: 56, top: 16, bottom: 16),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                      color: _emptyInputError != null
                          ? Colors.red
                          : Colors.black,
                      width: 2.5),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      const BorderSide(color: Colors.black, width: 3),
                ),
                disabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      const BorderSide(color: Colors.black38, width: 2),
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
                      border: Border.all(color: Colors.black, width: 2.5),
                      boxShadow: _isRecording
                          ? []
                          : const [
                              BoxShadow(
                                  color: Colors.black,
                                  offset: Offset(2, 2),
                                  blurRadius: 0)
                            ],
                    ),
                    child: Icon(
                        _isRecording ? LucideIcons.square : LucideIcons.mic,
                        color: Colors.black,
                        size: 20),
                  ),
                ),
              ),
            ),
          ]),

          // Empty input error
          if (_emptyInputError != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(children: [
                const Icon(LucideIcons.alertCircle,
                    size: 13, color: Colors.red),
                const SizedBox(width: 6),
                Text(_emptyInputError!,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.red)),
              ]),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: RetroTheme.pink.withAlpha(180),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.red, width: 2),
                ),
                child: Row(children: [
                  const Icon(LucideIcons.alertTriangle,
                      size: 13, color: Colors.red),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(_transcribeError!,
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.red))),
                ]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildFooterPill(LucideIcons.searchCode, 'Scrapes real reviews'),
        const SizedBox(width: 8),
        _buildFooterPill(LucideIcons.bot, '4 AI agents'),
        const SizedBox(width: 8),
        _buildFooterPill(LucideIcons.barChart2, 'Market score'),
      ],
    );
  }

  Widget _buildFooterPill(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black26, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: RetroTheme.textMuted),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: RetroTheme.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
