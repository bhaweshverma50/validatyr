import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/custom_theme.dart';
import '../../shared_widgets/retro_card.dart';
import '../../services/notification_service.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
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
    final colors = RetroColors.of(context);
    return Scaffold(
      backgroundColor: colors.background,
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
            fontSize: RetroTheme.fontLg,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: !_loaded
          ? Center(
              child: CircularProgressIndicator(
                color: colors.text,
                strokeWidth: 2.5,
              ),
            )
          : ListView(
              padding: const EdgeInsets.symmetric(
                horizontal: RetroTheme.contentPaddingMobile,
                vertical: RetroTheme.spacingMd,
              ),
              children: [
                const Text('NOTIFICATIONS', style: RetroTheme.sectionTitle),
                const SizedBox(height: 6),
                Text(
                  'Choose which events trigger app alerts and local notifications.',
                  style: TextStyle(
                    fontSize: RetroTheme.fontSm,
                    color: colors.textMuted,
                  ),
                ),
                const SizedBox(height: RetroTheme.spacingLg),
                RetroCard(
                  backgroundColor: RetroTheme.mint.withAlpha(110),
                  padding: const EdgeInsets.all(RetroTheme.spacingMd),
                  child: Row(
                    children: [
                      Icon(LucideIcons.bellRing, color: colors.iconDefault),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Enable system notification permissions so completed jobs can alert you when the app is active or resumed.',
                          style: TextStyle(
                            fontSize: RetroTheme.fontSm,
                            fontWeight: FontWeight.w600,
                            color: colors.text,
                            height: 1.4,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      TextButton(
                        style: TextButton.styleFrom(
                          backgroundColor: RetroTheme.yellow,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              RetroTheme.radiusSm,
                            ),
                            side: BorderSide(
                              color: colors.border,
                              width: 2,
                            ),
                          ),
                        ),
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          final granted = await NotificationService.instance
                              .requestSystemPermissions();
                          if (!mounted) return;
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                granted
                                    ? 'Notifications enabled!'
                                    : 'Permission not granted. Enable in system Settings > Apps > Validatyr > Notifications.',
                              ),
                            ),
                          );
                        },
                        child: const Text(
                          'Enable',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ],
                  ),
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
                const SizedBox(height: RetroTheme.spacingMd),
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
                const SizedBox(height: RetroTheme.spacingMd),
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
                  const SizedBox(height: RetroTheme.spacingMd),
                  RetroCard(
                    backgroundColor: const Color(0xFFFEF9C3),
                    padding: const EdgeInsets.all(RetroTheme.spacingMd),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SCORE THRESHOLD: $_scoreThreshold',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: RetroTheme.fontSm,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Only notify for ideas scoring at or above this value.',
                          style: TextStyle(
                            fontSize: RetroTheme.fontSm,
                            color: Color(0xFF475569),
                          ),
                        ),
                        const SizedBox(height: 4),
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: Colors.black,
                            inactiveTrackColor: RetroTheme.textSubtle,
                            thumbColor: RetroTheme.yellow,
                            overlayColor: RetroTheme.yellow.withAlpha(60),
                            trackHeight: 6,
                          ),
                          child: Slider(
                            value: _scoreThreshold.toDouble(),
                            min: 50,
                            max: 95,
                            divisions: 9,
                            label: '$_scoreThreshold',
                            onChanged: (v) {
                              setState(() => _scoreThreshold = v.round());
                              _saveInt('notif_score_threshold', v.round());
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: RetroTheme.spacingMd),
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
    final colors = RetroColors.of(context);
    return RetroCard(
      backgroundColor: colors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(RetroTheme.radiusSm),
              border: Border.all(
                color: colors.border,
                width: RetroTheme.borderWidthThin,
              ),
            ),
            child: Icon(icon, size: 16, color: Colors.black),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: RetroTheme.fontMd,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: RetroTheme.fontSm,
                    color: colors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: RetroTheme.yellow,
            activeTrackColor: colors.border,
            inactiveThumbColor: colors.textMuted,
            inactiveTrackColor: colors.borderSubtle,
          ),
        ],
      ),
    );
  }
}
