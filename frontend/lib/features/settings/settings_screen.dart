import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/theme/custom_theme.dart';
import '../../core/providers/theme_provider.dart';
import '../../shared_widgets/retro_card.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = RetroColors.of(context);
    final currentMode = ref.watch(themeProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'SETTINGS',
          style: TextStyle(
            fontFamily: 'Outfit',
            color: colors.text,
            fontWeight: FontWeight.w900,
            fontSize: RetroTheme.fontDisplay,
            letterSpacing: -0.5,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: RetroTheme.contentPaddingMobile,
          vertical: RetroTheme.spacingMd,
        ),
        children: [
          // ── Theme Section ──
          Text(
            'APPEARANCE',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
              color: colors.textMuted,
            ),
          ),
          const SizedBox(height: RetroTheme.spacingSm),
          RetroCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(LucideIcons.palette, size: 20, color: colors.iconDefault),
                    const SizedBox(width: 10),
                    Text(
                      'Theme',
                      style: TextStyle(
                        fontSize: RetroTheme.fontLg,
                        fontWeight: FontWeight.w800,
                        color: colors.text,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _ThemeSelector(
                  current: currentMode,
                  onChanged: (mode) {
                    ref.read(themeProvider.notifier).setThemeMode(mode);
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: RetroTheme.spacingLg),

          // ── Profile Section ──
          Text(
            'PROFILE',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
              color: colors.textMuted,
            ),
          ),
          const SizedBox(height: RetroTheme.spacingSm),
          RetroCard(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: RetroTheme.lavender,
                    borderRadius: BorderRadius.circular(RetroTheme.radiusMd),
                    border: Border.all(color: colors.border, width: 2),
                  ),
                  child: const Icon(LucideIcons.user, size: 22, color: Colors.black),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sign In',
                        style: TextStyle(
                          fontSize: RetroTheme.fontLg,
                          fontWeight: FontWeight.w800,
                          color: colors.text,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Sync settings across devices',
                        style: TextStyle(
                          fontSize: RetroTheme.fontSm,
                          color: colors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(LucideIcons.chevronRight, size: 18, color: colors.iconMuted),
              ],
            ),
          ),

          const SizedBox(height: RetroTheme.spacingLg),

          // ── About Section ──
          Text(
            'ABOUT',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
              color: colors.textMuted,
            ),
          ),
          const SizedBox(height: RetroTheme.spacingSm),
          RetroCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _AboutRow(label: 'Version', value: '1.0.0', colors: colors),
                Divider(height: 24, color: colors.borderSubtle),
                _AboutRow(label: 'Built with', value: 'Flutter + Gemini', colors: colors),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeSelector extends StatelessWidget {
  final ThemeMode current;
  final ValueChanged<ThemeMode> onChanged;
  const _ThemeSelector({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final colors = RetroColors.of(context);
    const modes = [
      (mode: ThemeMode.light, icon: LucideIcons.sun, label: 'Light'),
      (mode: ThemeMode.dark, icon: LucideIcons.moon, label: 'Dark'),
      (mode: ThemeMode.system, icon: LucideIcons.monitor, label: 'System'),
    ];

    return Row(
      children: modes.map((m) {
        final isSelected = current == m.mode;
        return Expanded(
          child: GestureDetector(
            onTap: () => onChanged(m.mode),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? RetroTheme.yellow : colors.background,
                borderRadius: BorderRadius.circular(RetroTheme.radiusMd),
                border: Border.all(
                  color: isSelected ? colors.border : colors.borderSubtle,
                  width: isSelected ? 2.5 : 1.5,
                ),
                boxShadow: isSelected ? RetroTheme.shadowSmOf(context) : null,
              ),
              child: Column(
                children: [
                  Icon(m.icon, size: 20, color: isSelected ? Colors.black : colors.iconMuted),
                  const SizedBox(height: 4),
                  Text(
                    m.label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                      color: isSelected ? Colors.black : colors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _AboutRow extends StatelessWidget {
  final String label;
  final String value;
  final RetroColors colors;
  const _AboutRow({required this.label, required this.value, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: RetroTheme.fontMd, fontWeight: FontWeight.w600, color: colors.textMuted)),
        Text(value, style: TextStyle(fontSize: RetroTheme.fontMd, fontWeight: FontWeight.w700, color: colors.text)),
      ],
    );
  }
}
