import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/theme/custom_theme.dart';
import '../../shared_widgets/retro_card.dart';
import '../../shared_widgets/retro_button.dart';
import '../../services/research_api_service.dart';

class NewTopicScreen extends StatefulWidget {
  const NewTopicScreen({super.key});

  @override
  State<NewTopicScreen> createState() => _NewTopicScreenState();
}

class _NewTopicScreenState extends State<NewTopicScreen> {
  String _selectedDomain = 'apps';
  final _keywordsController = TextEditingController();
  final _interestsController = TextEditingController();
  String _schedule = 'manual';
  TimeOfDay _scheduleTime = const TimeOfDay(hour: 8, minute: 0);
  int _weekday = 1; // 1=Mon, 7=Sun
  bool _isSubmitting = false;

  static const _weekdays = [
    (value: 1, label: 'Mon'),
    (value: 2, label: 'Tue'),
    (value: 3, label: 'Wed'),
    (value: 4, label: 'Thu'),
    (value: 5, label: 'Fri'),
    (value: 6, label: 'Sat'),
    (value: 7, label: 'Sun'),
  ];

  static const _domains = [
    (id: 'apps', label: 'Apps', icon: LucideIcons.smartphone, color: RetroTheme.pink),
    (id: 'saas', label: 'SaaS', icon: LucideIcons.globe, color: RetroTheme.blue),
    (id: 'hardware', label: 'Hardware', icon: LucideIcons.cpu, color: RetroTheme.orange),
    (id: 'fintech', label: 'FinTech', icon: LucideIcons.wallet, color: RetroTheme.mint),
    (id: 'general', label: 'General', icon: LucideIcons.search, color: RetroTheme.lavender),
  ];

  Future<void> _submit() async {
    final keywords = _keywordsController.text
        .split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

    if (keywords.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter at least one keyword')),
      );
      return;
    }

    final interests = _interestsController.text
        .split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

    setState(() => _isSubmitting = true);

    String? scheduleCron;
    if (_schedule == 'daily') {
      final hh = _scheduleTime.hour.toString().padLeft(2, '0');
      final mm = _scheduleTime.minute.toString().padLeft(2, '0');
      scheduleCron = 'daily|$hh:$mm';
    } else if (_schedule == 'weekly') {
      final hh = _scheduleTime.hour.toString().padLeft(2, '0');
      final mm = _scheduleTime.minute.toString().padLeft(2, '0');
      scheduleCron = 'weekly|$_weekday|$hh:$mm';
    }

    try {
      await ResearchApiService.createTopic(
        domain: _selectedDomain,
        keywords: keywords,
        interests: interests,
        scheduleCron: scheduleCron,
        startImmediately: true,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Research topic created! First run starting...')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  void dispose() {
    _keywordsController.dispose();
    _interestsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = RetroColors.of(context);
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text(
          'NEW RESEARCH TOPIC',
          style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w900, fontSize: RetroTheme.fontXl),
        ),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: RetroTheme.contentPaddingMobile,
          vertical: RetroTheme.spacingMd,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionLabel('DOMAIN'),
            const SizedBox(height: RetroTheme.spacingSm),
            SizedBox(
              height: 42,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: _domains.length,
                separatorBuilder: (_, __) => const SizedBox(width: RetroTheme.spacingSm),
                itemBuilder: (_, i) {
                  final d = _domains[i];
                  final isSelected = _selectedDomain == d.id;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedDomain = d.id),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: RetroTheme.chipDecorationOf(context, selected: isSelected, color: d.color),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(d.icon, size: 15,
                            color: isSelected ? Colors.black : RetroColors.of(context).text,
                          ),
                          const SizedBox(width: 6),
                          Text(d.label, style: TextStyle(
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            fontSize: RetroTheme.fontMd,
                            color: isSelected ? Colors.black : RetroColors.of(context).text,
                          )),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: RetroTheme.spacingLg),

            _buildSectionLabel('KEYWORDS'),
            const SizedBox(height: RetroTheme.spacingXs),
            Text('Comma-separated topics to research', style: TextStyle(fontSize: RetroTheme.fontSm, color: colors.textSubtle)),
            const SizedBox(height: RetroTheme.spacingSm),
            TextField(
              controller: _keywordsController,
              decoration: const InputDecoration(
                hintText: 'fitness, habit tracking, wellness',
              ),
            ),

            const SizedBox(height: RetroTheme.spacingLg),

            _buildSectionLabel('FOCUS AREAS'),
            const SizedBox(height: RetroTheme.spacingXs),
            Text('Optional — narrow the research scope', style: TextStyle(fontSize: RetroTheme.fontSm, color: colors.textSubtle)),
            const SizedBox(height: RetroTheme.spacingSm),
            TextField(
              controller: _interestsController,
              decoration: const InputDecoration(
                hintText: 'gamification, social features, AI coaching',
              ),
            ),

            const SizedBox(height: RetroTheme.spacingLg),

            _buildSectionLabel('SCHEDULE'),
            const SizedBox(height: RetroTheme.spacingSm),
            RetroCard(
              padding: const EdgeInsets.symmetric(vertical: RetroTheme.spacingSm),
              child: Column(
                children: [
                  _buildRadio('daily', 'Daily', 'Run research every day'),
                  _buildRadio('weekly', 'Weekly', 'Run research once a week'),
                  _buildRadio('manual', 'Manual only', 'Run only when you trigger it'),
                ],
              ),
            ),

            if (_schedule == 'weekly') ...[
              const SizedBox(height: RetroTheme.spacingMd),
              _buildSectionLabel('DAY'),
              const SizedBox(height: RetroTheme.spacingSm),
              SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: _weekdays.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 6),
                  itemBuilder: (_, i) {
                    final d = _weekdays[i];
                    final isSelected = _weekday == d.value;
                    return GestureDetector(
                      onTap: () => setState(() => _weekday = d.value),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 48,
                        alignment: Alignment.center,
                        decoration: RetroTheme.chipDecorationOf(context, selected: isSelected, color: RetroTheme.blue),
                        child: Text(d.label, style: TextStyle(
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          fontSize: RetroTheme.fontSm,
                          color: isSelected ? Colors.black : RetroColors.of(context).text,
                        )),
                      ),
                    );
                  },
                ),
              ),
            ],

            if (_schedule == 'daily' || _schedule == 'weekly') ...[
              const SizedBox(height: RetroTheme.spacingMd),
              _buildSectionLabel('TIME'),
              const SizedBox(height: RetroTheme.spacingSm),
              GestureDetector(
                onTap: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: _scheduleTime,
                    builder: (context, child) => Theme(
                      data: Theme.of(context).copyWith(
                        timePickerTheme: TimePickerThemeData(
                          backgroundColor: colors.background,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(RetroTheme.radiusLg),
                            side: BorderSide(color: colors.border, width: RetroTheme.borderWidthThick),
                          ),
                        ),
                      ),
                      child: child!,
                    ),
                  );
                  if (picked != null) setState(() => _scheduleTime = picked);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(RetroTheme.radiusMd),
                    border: Border.all(color: colors.border, width: RetroTheme.borderWidthMedium),
                    boxShadow: RetroTheme.sharpShadowSm,
                  ),
                  child: Row(
                    children: [
                      const Icon(LucideIcons.clock, size: 18),
                      const SizedBox(width: 10),
                      Text(
                        _scheduleTime.format(context),
                        style: const TextStyle(fontSize: RetroTheme.fontLg, fontWeight: FontWeight.w700),
                      ),
                      const Spacer(),
                      Icon(LucideIcons.chevronDown, size: 16, color: colors.iconMuted),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: RetroTheme.spacingXl),

            RetroButton(
              text: 'START RESEARCH',
              icon: const Icon(LucideIcons.microscope, size: 18),
              onPressed: _submit,
              isLoading: _isSubmitting,
              color: RetroTheme.lavender,
            ),

            const SizedBox(height: RetroTheme.spacingXl),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Text(text, style: RetroTheme.sectionTitle);
  }

  Widget _buildRadio(String value, String label, String subtitle) {
    final colors = RetroColors.of(context);
    return RadioListTile<String>(
      value: value,
      groupValue: _schedule,
      onChanged: (v) => setState(() => _schedule = v ?? 'manual'),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: RetroTheme.fontMd)),
      subtitle: Text(subtitle, style: TextStyle(fontSize: RetroTheme.fontSm, color: colors.textSubtle)),
      activeColor: colors.text,
      contentPadding: const EdgeInsets.symmetric(horizontal: RetroTheme.spacingSm),
      dense: true,
    );
  }
}
