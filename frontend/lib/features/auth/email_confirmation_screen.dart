import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/theme/custom_theme.dart';
import '../../shared_widgets/retro_button.dart';
import '../../shared_widgets/retro_card.dart';

class EmailConfirmationScreen extends StatelessWidget {
  final String email;

  const EmailConfirmationScreen({super.key, required this.email});

  @override
  Widget build(BuildContext context) {
    final colors = RetroColors.of(context);

    return Scaffold(
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
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    LucideIcons.mailCheck,
                    size: 64,
                    color: colors.text,
                  ),
                  const SizedBox(height: RetroTheme.spacingLg),
                  Text(
                    'CHECK YOUR EMAIL',
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(
                          fontSize: 28,
                          letterSpacing: 2.0,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: RetroTheme.spacingLg),
                  RetroCard(
                    child: Column(
                      children: [
                        Text(
                          "We've sent a confirmation link to:",
                          style: TextStyle(
                            fontSize: RetroTheme.fontMd,
                            color: colors.textMuted,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: RetroTheme.spacingSm),
                        Text(
                          email,
                          style: TextStyle(
                            fontSize: RetroTheme.fontLg,
                            fontWeight: FontWeight.w800,
                            color: colors.text,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: RetroTheme.spacingLg),
                        Text(
                          'Click the link in the email to activate your account, then come back here to sign in.',
                          style: TextStyle(
                            fontSize: RetroTheme.fontMd,
                            color: colors.textMuted,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: RetroTheme.spacingXl),
                  RetroButton(
                    text: 'Back to Sign In',
                    onPressed: () {
                      // Pop back to login screen (pop signup + this screen)
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    },
                    color: RetroTheme.yellow,
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
