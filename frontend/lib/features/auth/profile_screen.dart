import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/providers/auth_provider.dart';
import '../../core/theme/custom_theme.dart';
import '../../shared_widgets/retro_button.dart';
import '../../shared_widgets/retro_card.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = RetroColors.of(context);
    final user = ref.watch(currentUserProvider);

    final email = user?.email ?? '';
    final fullName = user?.userMetadata?['full_name'] as String? ??
        user?.userMetadata?['name'] as String? ??
        '';
    final avatarUrl = user?.userMetadata?['avatar_url'] as String? ??
        user?.userMetadata?['picture'] as String? ??
        '';
    final provider = user?.appMetadata['provider'] as String? ?? 'email';
    final createdAt = user?.createdAt;
    final memberSince = createdAt != null
        ? _formatDate(DateTime.parse(createdAt))
        : '';

    final displayInitial = fullName.isNotEmpty
        ? fullName[0].toUpperCase()
        : (email.isNotEmpty ? email[0].toUpperCase() : '?');

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('PROFILE'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(
            horizontal: RetroTheme.contentPaddingMobile,
            vertical: RetroTheme.spacingMd,
          ),
          children: [
            const SizedBox(height: RetroTheme.spacingMd),

            // ── Avatar + Name Header ──
            Center(
              child: Column(
                children: [
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: RetroTheme.lavender,
                      shape: BoxShape.circle,
                      border: Border.all(color: colors.border, width: 3),
                      boxShadow: RetroTheme.shadowSmOf(context),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: avatarUrl.isNotEmpty
                        ? Image.network(
                            avatarUrl,
                            width: 96,
                            height: 96,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _AvatarInitial(displayInitial),
                          )
                        : _AvatarInitial(displayInitial),
                  ),
                  if (fullName.isNotEmpty) ...[
                    const SizedBox(height: RetroTheme.spacingMd),
                    Text(
                      fullName,
                      style: TextStyle(
                        fontSize: RetroTheme.fontXl,
                        fontWeight: FontWeight.w900,
                        color: colors.text,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    email,
                    style: TextStyle(
                      fontSize: RetroTheme.fontMd,
                      color: colors.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: RetroTheme.spacingLg),

            // ── Account Details ──
            Text(
              'ACCOUNT',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
                color: colors.textMuted,
              ),
            ),
            const SizedBox(height: RetroTheme.spacingSm),
            RetroCard(
              padding: const EdgeInsets.all(0),
              child: Column(
                children: [
                  _ProfileRow(
                    icon: LucideIcons.mail,
                    label: 'Email',
                    value: email,
                    colors: colors,
                  ),
                  Divider(height: 1, color: colors.borderSubtle),
                  _ProfileRow(
                    icon: _providerIcon(provider),
                    label: 'Sign-in method',
                    value: _providerLabel(provider),
                    colors: colors,
                    badge: true,
                    badgeColor: _providerColor(provider),
                  ),
                  if (memberSince.isNotEmpty) ...[
                    Divider(height: 1, color: colors.borderSubtle),
                    _ProfileRow(
                      icon: LucideIcons.calendar,
                      label: 'Member since',
                      value: memberSince,
                      colors: colors,
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: RetroTheme.spacingXl),

            // ── Actions ──
            Text(
              'ACTIONS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
                color: colors.textMuted,
              ),
            ),
            const SizedBox(height: RetroTheme.spacingSm),
            RetroButton(
              text: 'Sign Out',
              onPressed: () async {
                await AuthService.signOut();
                if (context.mounted) {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                }
              },
              color: RetroTheme.orange,
              icon: const Icon(LucideIcons.logOut),
            ),
            const SizedBox(height: RetroTheme.spacingLg),
            Center(
              child: GestureDetector(
                onTap: () => _showDeleteConfirmation(context),
                child: Text(
                  'Delete Account',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontWeight: FontWeight.w700,
                    fontSize: RetroTheme.fontMd,
                    decoration: TextDecoration.underline,
                    decorationColor: Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
            ),
            const SizedBox(height: RetroTheme.spacingXl),
          ],
        ),
      ),
    );
  }

  static String _formatDate(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  static IconData _providerIcon(String provider) {
    switch (provider) {
      case 'google':
        return LucideIcons.globe;
      default:
        return LucideIcons.keyRound;
    }
  }

  static String _providerLabel(String provider) {
    switch (provider) {
      case 'google':
        return 'Google';
      case 'apple':
        return 'Apple';
      default:
        return 'Email';
    }
  }

  static Color _providerColor(String provider) {
    switch (provider) {
      case 'google':
        return RetroTheme.blue;
      default:
        return RetroTheme.yellow;
    }
  }

  void _showDeleteConfirmation(BuildContext context) {
    final colors = RetroColors.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(RetroTheme.radiusMd),
          side: BorderSide(color: colors.border, width: 3),
        ),
        title: Row(
          children: [
            Icon(LucideIcons.alertTriangle, color: Theme.of(context).colorScheme.error, size: 24),
            const SizedBox(width: 10),
            Text(
              'DELETE ACCOUNT',
              style: TextStyle(
                fontFamily: 'Outfit',
                fontWeight: FontWeight.w900,
                fontSize: RetroTheme.fontLg,
                color: colors.text,
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure? This will permanently delete your account and all your data. This cannot be undone.',
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: colors.textMuted,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'CANCEL',
              style: TextStyle(fontWeight: FontWeight.w800, color: colors.text),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await AuthService.deleteAccount();
            },
            child: Text(
              'DELETE',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AvatarInitial extends StatelessWidget {
  final String initial;
  const _AvatarInitial(this.initial);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        initial,
        style: const TextStyle(
          fontSize: 36,
          fontWeight: FontWeight.w900,
          color: Colors.black,
        ),
      ),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final RetroColors colors;
  final bool badge;
  final Color? badgeColor;

  const _ProfileRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.colors,
    this.badge = false,
    this.badgeColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, size: 18, color: colors.iconMuted),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: RetroTheme.fontMd,
                fontWeight: FontWeight.w600,
                color: colors.textMuted,
              ),
            ),
          ),
          if (badge)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: RetroTheme.badgeDecoration(
                badgeColor ?? RetroTheme.yellow,
                borderColor: colors.border,
              ),
              child: Text(
                value.toUpperCase(),
                style: RetroTheme.badgeStyle,
              ),
            )
          else
            Flexible(
              child: Text(
                value,
                style: TextStyle(
                  fontSize: RetroTheme.fontMd,
                  fontWeight: FontWeight.w700,
                  color: colors.text,
                ),
                textAlign: TextAlign.right,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }
}
