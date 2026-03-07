import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/custom_theme.dart';
import '../../shared_widgets/retro_card.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  bool _validationComplete = true;
  bool _researchComplete = true;
  bool _highScoreAlert = true;
  bool _scheduleReminder = true;
  int _scoreThreshold = 75;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _validationComplete = prefs.getBool('notif_validation_complete') ?? true;
      _researchComplete = prefs.getBool('notif_research_complete') ?? true;
      _highScoreAlert = prefs.getBool('notif_high_score_alert') ?? true;
      _scheduleReminder = prefs.getBool('notif_schedule_reminder') ?? true;
      _scoreThreshold = prefs.getInt('notif_score_threshold') ?? 75;
      _loaded = true;
    });
  }

  Future<void> _saveBool(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  Future<void> _saveInt(String key, int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(key, value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RetroTheme.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'NOTIFICATION SETTINGS',
          style: TextStyle(
            fontFamily: 'Outfit',
            fontWeight: FontWeight.w900,
            fontSize: RetroTheme.fontXl,
          ),
        ),
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2.5))
          : ListView(
              padding: const EdgeInsets.symmetric(
                horizontal: RetroTheme.contentPaddingMobile,
                vertical: RetroTheme.spacingMd,
              ),
              children: [
                const Text('PUSH NOTIFICATIONS', style: RetroTheme.sectionTitle),
                const SizedBox(height: RetroTheme.spacingSm),
                const Text(
                  'Choose which events trigger local push notifications.',
                  style: TextStyle(fontSize: RetroTheme.fontSm, color: Colors.black54),
                ),
                const SizedBox(height: RetroTheme.spacingMd),
                _buildToggle(
                  icon: LucideIcons.checkCircle,
                  color: RetroTheme.mint,
                  title: 'Validation Complete',
                  subtitle: 'When an idea validation finishes',
                  value: _validationComplete,
                  onChanged: (v) {
                    setState(() => _validationComplete = v);
                    _saveBool('notif_validation_complete', v);
                  },
                ),
                const SizedBox(height: RetroTheme.spacingSm),
                _buildToggle(
                  icon: LucideIcons.microscope,
                  color: RetroTheme.lavender,
                  title: 'Research Complete',
                  subtitle: 'When a research report is generated',
                  value: _researchComplete,
                  onChanged: (v) {
                    setState(() => _researchComplete = v);
                    _saveBool('notif_research_complete', v);
                  },
                ),
                const SizedBox(height: RetroTheme.spacingSm),
                _buildToggle(
                  icon: LucideIcons.zap,
                  color: RetroTheme.yellow,
                  title: 'High-Score Ideas',
                  subtitle: 'When a research idea scores above threshold',
                  value: _highScoreAlert,
                  onChanged: (v) {
                    setState(() => _highScoreAlert = v);
                    _saveBool('notif_high_score_alert', v);
                  },
                ),
                if (_highScoreAlert) ...[
                  const SizedBox(height: RetroTheme.spacingSm),
                  RetroCard(
                    backgroundColor: const Color(0xFFFEF9C3),
                    padding: const EdgeInsets.all(RetroTheme.spacingMd),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SCORE THRESHOLD: $_scoreThreshold',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: RetroTheme.fontSm),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Only notify for ideas scoring at or above this value.',
                          style: TextStyle(fontSize: RetroTheme.fontSm, color: Colors.black54),
                        ),
                        Slider(
                          value: _scoreThreshold.toDouble(),
                          min: 50,
                          max: 95,
                          divisions: 9,
                          label: '$_scoreThreshold',
                          activeColor: Colors.black,
                          onChanged: (v) {
                            setState(() => _scoreThreshold = v.round());
                            _saveInt('notif_score_threshold', v.round());
                          },
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: RetroTheme.spacingSm),
                _buildToggle(
                  icon: LucideIcons.clock,
                  color: RetroTheme.blue,
                  title: 'Schedule Reminders',
                  subtitle: 'When scheduled research is about to run',
                  value: _scheduleReminder,
                  onChanged: (v) {
                    setState(() => _scheduleReminder = v);
                    _saveBool('notif_schedule_reminder', v);
                  },
                ),
              ],
            ),
    );
  }

  Widget _buildToggle({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return RetroCard(
      backgroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(RetroTheme.radiusSm),
              border: Border.all(color: RetroTheme.border, width: RetroTheme.borderWidthThin),
            ),
            child: Icon(icon, size: 16, color: Colors.black),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: RetroTheme.fontMd)),
                Text(subtitle, style: const TextStyle(fontSize: RetroTheme.fontSm, color: Colors.black54)),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeColor: Colors.black,
          ),
        ],
      ),
    );
  }
}
