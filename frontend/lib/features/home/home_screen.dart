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
      setState(
          () => _emptyInputError = 'Please enter your app idea before validating.');
      return;
    }
    setState(() => _emptyInputError = null);
    Navigator.push(
        context, MaterialPageRoute(builder: (_) => LoadingScreen(idea: text)));
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > RetroTheme.mobileBreakpoint;
    final horizontalPadding = isDesktop ? 48.0 : 20.0;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: RetroTheme.background,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.history, color: Colors.black, size: 26),
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
              padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding, vertical: 32.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(height: isDesktop ? 32 : 16),
                  Text(
                    'VALIDATYR.',
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(
                        color: RetroTheme.pink,
                        shadows: RetroTheme.sharpShadow,
                        fontSize: isDesktop ? 56 : 42),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Dump your app idea below.\nWe let AI analyze the market and tell you if it sucks.',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontSize: isDesktop ? 18 : 16, height: 1.5),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),
                  RetroCard(
                    backgroundColor: RetroTheme.mint,
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_isRecording && _pulseController != null)
                            AnimatedBuilder(
                              animation: _pulseController!,
                              builder: (_, __) => Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Color.lerp(
                                      RetroTheme.pink,
                                      RetroTheme.pink.withAlpha(150),
                                      _pulseController!.value),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                      color: Colors.black, width: 2),
                                ),
                                child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(LucideIcons.circle,
                                          color: Colors.red, size: 10),
                                      SizedBox(width: 8),
                                      Text('Recording... Tap mic to stop',
                                          style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 14)),
                                    ]),
                              ),
                            ),
                          Stack(children: [
                            TextField(
                              controller: _ideaController,
                              maxLines: 5,
                              enabled: !_isRecording,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 16),
                              onChanged: (_) {
                                if (_emptyInputError != null) {
                                  setState(() => _emptyInputError = null);
                                }
                              },
                              decoration: InputDecoration(
                                hintText: 'e.g. A social network for dogs...',
                                contentPadding: const EdgeInsets.only(
                                    left: 20, right: 60, top: 20, bottom: 20),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                      color: _emptyInputError != null
                                          ? Colors.red
                                          : Colors.black,
                                      width: 3),
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 12,
                              right: 12,
                              child: MouseRegion(
                                cursor: SystemMouseCursors.click,
                                child: GestureDetector(
                                  onTap:
                                      _isLoading ? null : _toggleRecording,
                                  child: AnimatedContainer(
                                    duration:
                                        const Duration(milliseconds: 150),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: _isRecording
                                          ? RetroTheme.pink
                                          : RetroTheme.yellow,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: Colors.black, width: 3),
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
                                        _isRecording
                                            ? LucideIcons.square
                                            : LucideIcons.mic,
                                        color: Colors.black,
                                        size: 24),
                                  ),
                                ),
                              ),
                            ),
                          ]),
                          if (_emptyInputError != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Row(children: [
                                const Icon(LucideIcons.alertCircle,
                                    size: 14, color: Colors.red),
                                const SizedBox(width: 6),
                                Text(_emptyInputError!,
                                    style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.red)),
                              ]),
                            ),
                          const SizedBox(height: 20),
                          RetroButton(
                            text: 'Validate Idea',
                            color: RetroTheme.yellow,
                            isLoading: _isLoading,
                            onPressed: _validateIdea,
                            icon: _isLoading
                                ? null
                                : const Icon(LucideIcons.zap,
                                    color: Colors.black, size: 20),
                          ),
                          if (_transcribeError != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: RetroTheme.pink.withAlpha(180),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                      color: Colors.red, width: 2),
                                ),
                                child: Row(children: [
                                  const Icon(LucideIcons.alertTriangle,
                                      size: 14, color: Colors.red),
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
                        ]),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'We scrape real competitor reviews, run 4 AI agents, and give you a data-backed score.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: RetroTheme.textMuted, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
