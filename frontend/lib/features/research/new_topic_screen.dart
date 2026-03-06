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
  bool _isSubmitting = false;

  final _domains = [
    {'id': 'apps', 'label': 'Apps', 'icon': LucideIcons.smartphone, 'color': RetroTheme.pink},
    {'id': 'saas', 'label': 'SaaS', 'icon': LucideIcons.globe, 'color': RetroTheme.blue},
    {'id': 'hardware', 'label': 'Hardware', 'icon': LucideIcons.cpu, 'color': RetroTheme.orange},
    {'id': 'fintech', 'label': 'FinTech', 'icon': LucideIcons.wallet, 'color': RetroTheme.mint},
    {'id': 'general', 'label': 'General', 'icon': LucideIcons.search, 'color': RetroTheme.lavender},
  ];

  Future<void> _submit() async {
    final keywords = _keywordsController.text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    if (keywords.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter at least one keyword')),
      );
      return;
    }

    final interests = _interestsController.text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    setState(() => _isSubmitting = true);

    try {
      await ResearchApiService.createTopic(
        domain: _selectedDomain,
        keywords: keywords,
        interests: interests,
        scheduleCron: _schedule == 'manual' ? null : _schedule,
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
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
    return Scaffold(
      backgroundColor: RetroTheme.background,
      appBar: AppBar(
        title: const Text(
          'NEW RESEARCH TOPIC',
          style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w900, fontSize: 20),
        ),
        backgroundColor: RetroTheme.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Domain', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _domains.map((d) {
                final isSelected = _selectedDomain == d['id'];
                return GestureDetector(
                  onTap: () => setState(() => _selectedDomain = d['id'] as String),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? (d['color'] as Color) : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.black, width: isSelected ? 3 : 2),
                      boxShadow: isSelected ? RetroTheme.sharpShadow : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(d['icon'] as IconData, size: 16),
                        const SizedBox(width: 6),
                        Text(d['label'] as String, style: TextStyle(fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500, fontSize: 14)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 24),

            const Text('Keywords', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 4),
            const Text('Comma-separated topics to research', style: TextStyle(fontSize: 12, color: Colors.black45)),
            const SizedBox(height: 8),
            RetroCard(
              padding: EdgeInsets.zero,
              child: TextField(
                controller: _keywordsController,
                decoration: const InputDecoration(
                  hintText: 'fitness, habit tracking, wellness',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(16),
                ),
              ),
            ),

            const SizedBox(height: 24),

            const Text('Focus Areas', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 4),
            const Text('Optional — narrow the research scope', style: TextStyle(fontSize: 12, color: Colors.black45)),
            const SizedBox(height: 8),
            RetroCard(
              padding: EdgeInsets.zero,
              child: TextField(
                controller: _interestsController,
                decoration: const InputDecoration(
                  hintText: 'gamification, social features, AI coaching',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(16),
                ),
              ),
            ),

            const SizedBox(height: 24),

            const Text('Schedule', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 8),
            RetroCard(
              child: Column(
                children: [
                  _buildRadio('daily', 'Daily', 'Run research every morning'),
                  _buildRadio('weekly', 'Weekly', 'Run research every Monday'),
                  _buildRadio('manual', 'Manual only', 'Run only when you trigger it'),
                ],
              ),
            ),

            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              child: RetroButton(
                text: 'START RESEARCH',
                icon: const Icon(LucideIcons.microscope, size: 18),
                onPressed: _submit,
                isLoading: _isSubmitting,
                color: RetroTheme.lavender,
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildRadio(String value, String label, String subtitle) {
    return RadioListTile<String>(
      value: value,
      groupValue: _schedule,
      onChanged: (v) => setState(() => _schedule = v ?? 'manual'),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.black45)),
      activeColor: Colors.black,
      contentPadding: EdgeInsets.zero,
      dense: true,
    );
  }
}
