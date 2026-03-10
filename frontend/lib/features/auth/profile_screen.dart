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
    final textTheme = Theme.of(context).textTheme;
    final user = ref.watch(currentUserProvider);

    final email = user?.email ?? '';
    final fullName = user?.userMetadata?['full_name'] as String? ??
        user?.userMetadata?['name'] as String? ??
        '';
    final avatarUrl = user?.userMetadata?['avatar_url'] as String? ??
        user?.userMetadata?['picture'] as String? ??
        '';
    final provider = user?.appMetadata['provider'] as String? ?? 'email';

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
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: RetroTheme.contentPaddingMobile,
              vertical: RetroTheme.spacingLg,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                children: [
                  // Avatar
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: RetroTheme.lavender,
                      shape: BoxShape.circle,
                      border: RetroTheme.borderOf(context),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: avatarUrl.isNotEmpty
                        ? Image.network(
                            avatarUrl,
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Center(
                              child: Text(
                                displayInitial,
                                style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                          )
                        : Center(
                            child: Text(
                              displayInitial,
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                                color: Colors.black,
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(height: RetroTheme.spacingLg),

                  // Info card
                  RetroCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (fullName.isNotEmpty) ...[
                          Text(
                            'NAME',
                            style: RetroTheme.labelStyle.copyWith(
                              color: colors.textMuted,
                            ),
                          ),
                          const SizedBox(height: RetroTheme.spacingXs),
                          Text(
                            fullName,
                            style: textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: RetroTheme.spacingMd),
                        ],
                        Text(
                          'EMAIL',
                          style: RetroTheme.labelStyle.copyWith(
                            color: colors.textMuted,
                          ),
                        ),
                        const SizedBox(height: RetroTheme.spacingXs),
                        Text(
                          email,
                          style: textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: RetroTheme.spacingMd),
                        Text(
                          'SIGN-IN METHOD',
                          style: RetroTheme.labelStyle.copyWith(
                            color: colors.textMuted,
                          ),
                        ),
                        const SizedBox(height: RetroTheme.spacingSm),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: RetroTheme.spacingMd,
                            vertical: RetroTheme.spacingSm,
                          ),
                          decoration: RetroTheme.badgeDecoration(
                            _providerColor(provider),
                            borderColor: colors.border,
                          ),
                          child: Text(
                            provider.toUpperCase(),
                            style: RetroTheme.badgeStyle,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: RetroTheme.spacingLg),

                  // Sign out button
                  RetroButton(
                    text: 'Sign Out',
                    onPressed: () async {
                      await AuthService.signOut();
                    },
                    color: RetroTheme.orange,
                    icon: const Icon(LucideIcons.logOut),
                  ),
                  const SizedBox(height: RetroTheme.spacingLg),

                  // Delete account
                  GestureDetector(
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _providerColor(String provider) {
    switch (provider) {
      case 'google':
        return RetroTheme.blue;
      case 'apple':
        return RetroTheme.lavender;
      default:
        return RetroTheme.yellow;
    }
  }

  void _showDeleteConfirmation(BuildContext context) {
    final colors = RetroColors.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'DELETE ACCOUNT',
          style: TextStyle(
            fontFamily: 'Outfit',
            fontWeight: FontWeight.w900,
            fontSize: RetroTheme.fontXl,
            color: colors.text,
          ),
        ),
        content: Text(
          'Are you sure you want to delete your account? This action cannot be undone.',
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
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: colors.text,
              ),
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
