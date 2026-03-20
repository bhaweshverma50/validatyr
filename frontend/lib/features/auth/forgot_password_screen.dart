import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/custom_theme.dart';
import '../../shared_widgets/retro_button.dart';
import '../../shared_widgets/retro_card.dart';

final _emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  bool _emailSent = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleReset() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final email = _emailController.text.trim();

      // Check if the email exists by attempting a sign-in.
      // "Invalid login credentials" = user exists, "User not found" = doesn't.
      try {
        await Supabase.instance.client.auth.signInWithPassword(
          email: email,
          password: '__probe_only__',
        );
      } on AuthException catch (signInErr) {
        final msg = signInErr.message.toLowerCase();
        // "invalid login credentials" means user exists but wrong password — good
        if (msg.contains('invalid login credentials') || msg.contains('invalid_credentials')) {
          // User exists, proceed to send reset
        } else if (msg.contains('email not confirmed') || msg.contains('email_not_confirmed')) {
          // User exists but unconfirmed — still send reset
        } else {
          // User likely doesn't exist
          if (mounted) {
            setState(() => _error = 'No account found with this email. Please sign up first.');
          }
          return;
        }
      }

      await Supabase.instance.client.auth.resetPasswordForEmail(email);
      if (mounted) setState(() => _emailSent = true);
    } on AuthException catch (e) {
      if (e.message.contains('rate limit') || e.message.contains('over_email_send_rate_limit')) {
        setState(() => _error = 'Too many attempts. Please wait a moment and try again.');
      } else {
        setState(() => _error = e.message);
      }
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('rate limit')) {
        setState(() => _error = 'Too many attempts. Please wait a moment and try again.');
      } else {
        setState(() => _error = 'Something went wrong. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = RetroColors.of(context);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('RESET PASSWORD'),
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
              child: _emailSent ? _buildSuccess(colors, textTheme) : _buildForm(colors),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSuccess(RetroColors colors, TextTheme textTheme) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(LucideIcons.mailCheck, size: 64, color: colors.text),
        const SizedBox(height: RetroTheme.spacingLg),
        Text(
          'CHECK YOUR EMAIL',
          style: textTheme.displayLarge?.copyWith(
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
                "We've sent a password reset link to:",
                style: TextStyle(fontSize: RetroTheme.fontMd, color: colors.textMuted),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: RetroTheme.spacingSm),
              Text(
                _emailController.text.trim(),
                style: TextStyle(
                  fontSize: RetroTheme.fontLg,
                  fontWeight: FontWeight.w800,
                  color: colors.text,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: RetroTheme.spacingLg),
              Text(
                'Click the link in the email to reset your password. If you don\'t see it, check your spam folder.',
                style: TextStyle(fontSize: RetroTheme.fontMd, color: colors.textMuted),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: RetroTheme.spacingXl),
        RetroButton(
          text: 'Back to Sign In',
          onPressed: () => Navigator.of(context).pop(),
          color: RetroTheme.yellow,
        ),
      ],
    );
  }

  Widget _buildForm(RetroColors colors) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(LucideIcons.keyRound, size: 48, color: colors.text),
        const SizedBox(height: RetroTheme.spacingMd),
        Text(
          'Enter your email and we\'ll send you a link to reset your password.',
          style: TextStyle(
            fontSize: RetroTheme.fontMd,
            color: colors.textMuted,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: RetroTheme.spacingLg),
        RetroCard(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: 'EMAIL',
                    prefixIcon: Icon(LucideIcons.mail),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Email is required';
                    }
                    if (!_emailRegex.hasMatch(value.trim())) {
                      return 'Enter a valid email address';
                    }
                    return null;
                  },
                ),
                if (_error != null) ...[
                  const SizedBox(height: RetroTheme.spacingMd),
                  Container(
                    padding: const EdgeInsets.all(RetroTheme.spacingSm),
                    decoration: BoxDecoration(
                      color: RetroTheme.pink.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(RetroTheme.radiusMd),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.error.withValues(alpha: 0.4),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(LucideIcons.alertCircle, size: 18, color: Theme.of(context).colorScheme.error),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _error!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                              fontWeight: FontWeight.w700,
                              fontSize: RetroTheme.fontSm,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: RetroTheme.spacingLg),
                RetroButton(
                  text: 'Send Reset Link',
                  onPressed: _handleReset,
                  color: RetroTheme.yellow,
                  isLoading: _isLoading,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
