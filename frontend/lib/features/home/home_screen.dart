import 'dart:io';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../core/theme/custom_theme.dart';
import '../../shared_widgets/retro_card.dart';
import '../../shared_widgets/retro_button.dart';
import '../results/results_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _ideaController = TextEditingController();
  final AudioRecorder _audioRecorder = AudioRecorder();

  bool _isLoading = false;
  bool _isRecording = false;
  String? _audioPath;
  AnimationController? _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
  }

  @override
  void dispose() {
    _ideaController.dispose();
    _audioRecorder.dispose();
    _pulseController?.dispose();
    super.dispose();
  }

  Future<String?> _transcribeAudio(String filePath) async {
    try {
      final uri = Uri.parse('http://127.0.0.1:8000/api/v1/transcribe');
      final request = http.MultipartRequest('POST', uri);
      request.files.add(await http.MultipartFile.fromPath('file', filePath));

      final response = await request.send();
      if (response.statusCode == 200) {
        final responseData = await response.stream.bytesToString();
        final json = jsonDecode(responseData);
        return json['transcript'];
      } else {
        debugPrint('Transcription failed with status ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Transcription error: $e');
    }
    return null;
  }

  Future<void> _toggleRecording() async {
    try {
      if (_isRecording) {
        final path = await _audioRecorder.stop();
        _pulseController?.stop();
        setState(() {
          _isRecording = false;
          _audioPath = path;
        });

        if (path != null) {
          setState(() => _isLoading = true);
          try {
            final transcript = await _transcribeAudio(path);
            if (transcript != null && transcript.isNotEmpty) {
              setState(() {
                _ideaController.text = transcript;
              });
            } else {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Failed to transcribe audio. Please try again or type your idea.')),
                );
              }
            }
          } finally {
            setState(() => _isLoading = false);
          }
        }
      } else {
        if (await _audioRecorder.hasPermission()) {
          final dir = await getApplicationDocumentsDirectory();
          final path = '${dir.path}/idea_record_${DateTime.now().millisecondsSinceEpoch}.m4a';

          await _audioRecorder.start(
            const RecordConfig(encoder: AudioEncoder.aacLc),
            path: path,
          );

          _pulseController?.repeat(reverse: true);
          setState(() {
            _isRecording = true;
            _audioPath = null;
          });
        }
      }
    } catch (e) {
      debugPrint("Recording error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Recording error: ${e.toString()}')),
        );
      }
    }
  }

  void _validateIdea() async {
    final text = _ideaController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your app idea first.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('http://127.0.0.1:8000/api/v1/validate'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'idea': text}),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> result = jsonDecode(response.body);
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ResultsScreen(result: result),
            ),
          );
        }
      } else {
        String errorMsg = 'Validation failed.';
        try {
          final errorBody = jsonDecode(response.body);
          if (errorBody['detail'] != null) {
            errorMsg = errorBody['detail'].toString();
          }
        } catch (_) {}
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMsg)),
          );
        }
      }
    } catch (e) {
      debugPrint('API Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not reach backend. Make sure the server is running.')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > RetroTheme.mobileBreakpoint;
    final horizontalPadding = isDesktop ? 48.0 : 20.0;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: RetroTheme.desktopMaxWidth),
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 32.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(height: isDesktop ? 64 : 32),

                  // Logo
                  Text(
                    'VALIDATYR.',
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(
                      color: RetroTheme.pink,
                      shadows: RetroTheme.sharpShadow,
                      fontSize: isDesktop ? 56 : 42,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),

                  // Tagline
                  Text(
                    'Dump your app idea below.\nWe let AI analyze the market and tell you if it sucks.',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontSize: isDesktop ? 18 : 16,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),

                  // Input card
                  RetroCard(
                    backgroundColor: RetroTheme.mint,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Recording indicator
                        if (_isRecording && _pulseController != null)
                          AnimatedBuilder(
                            animation: _pulseController!,
                            builder: (context, child) {
                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Color.lerp(RetroTheme.pink, RetroTheme.pink.withAlpha(150), _pulseController!.value),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.black, width: 2),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 10,
                                      height: 10,
                                      decoration: const BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Recording... Tap mic to stop',
                                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),

                        // Text input with mic button
                        Stack(
                          children: [
                            TextField(
                              controller: _ideaController,
                              maxLines: 5,
                              enabled: !_isRecording,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                              decoration: const InputDecoration(
                                hintText: "e.g. A social network for dogs...",
                                contentPadding: EdgeInsets.only(
                                  left: 20, right: 60, top: 20, bottom: 20,
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 12,
                              right: 12,
                              child: MouseRegion(
                                cursor: SystemMouseCursors.click,
                                child: GestureDetector(
                                  onTap: _isLoading ? null : _toggleRecording,
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 150),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: _isRecording ? RetroTheme.pink : RetroTheme.yellow,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.black, width: 3.0),
                                      boxShadow: _isRecording
                                          ? []
                                          : const [
                                              BoxShadow(
                                                color: Colors.black,
                                                offset: Offset(2, 2),
                                                blurRadius: 0,
                                              )
                                            ],
                                    ),
                                    child: Icon(
                                      _isRecording ? LucideIcons.square : LucideIcons.mic,
                                      color: Colors.black,
                                      size: 24,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        RetroButton(
                          text: "Validate Idea",
                          color: RetroTheme.yellow,
                          isLoading: _isLoading,
                          onPressed: _validateIdea,
                          icon: _isLoading
                              ? null
                              : const Icon(LucideIcons.zap, color: Colors.black, size: 20),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Footer hint
                  Text(
                    'We scrape real competitor reviews, run 3 AI agents, and give you a data-backed score.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: RetroTheme.textMuted,
                      fontSize: 13,
                    ),
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
