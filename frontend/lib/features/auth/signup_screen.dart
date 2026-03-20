import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/providers/auth_provider.dart';
import '../../core/theme/custom_theme.dart';
import '../../shared_widgets/retro_button.dart';
import '../../shared_widgets/retro_card.dart';
import 'email_confirmation_screen.dart';

final _emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  bool _isGoogleLoading = false;
  String? _error;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String _friendlyError(Object e) {
    final msg = e.toString();
    // Check for known error codes/messages
    if (msg.contains('user_already_exists') || msg.contains('User already registered') || msg.contains('already been registered')) {
      return 'An account with this email already exists. Try signing in instead.';
    }
    if (msg.contains('Invalid login credentials') || msg.contains('invalid_credentials')) {
      return 'Incorrect email or password.';
    }
    if (msg.contains('Email not confirmed') || msg.contains('email_not_confirmed')) {
      return 'Please confirm your email before signing in. Check your inbox.';
    }
    if (msg.contains('rate limit') || msg.contains('over_request_rate_limit') || msg.contains('over_email_send_rate_limit')) {
      return 'Too many attempts. Please wait a moment and try again.';
    }
    if (msg.contains('Password should be at least') || msg.contains('weak_password')) {
      return 'Password must be at least 6 characters.';
    }
    if (msg.contains('Unable to validate email') || msg.contains('invalid_email')) {
      return 'Please enter a valid email address.';
    }
    if (msg.contains('Network') || msg.contains('SocketException') || msg.contains('Connection')) {
      return 'Network error. Check your connection and try again.';
    }
    // For AuthApiException, extract just the message
    if (e is AuthApiException) return e.message;
    if (e is AuthException) return e.message;
    // Strip common prefixes
    if (msg.startsWith('Exception: ')) return msg.substring(11);
    return 'Something went wrong. Please try again.';
  }

  Future<void> _handleSignUp() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final response = await AuthService.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (!mounted) return;

      // Supabase returns a user with identities == [] when the email already exists
      // but email confirmations are enabled (it doesn't throw an error)
      if (response.user != null &&
          response.user!.identities != null &&
          response.user!.identities!.isEmpty) {
        setState(() => _error = 'An account with this email already exists. Try signing in instead.');
        return;
      }

      // If session is returned, email confirmation is disabled — user is signed in
      if (response.session != null) {
        if (mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
        return;
      }

      // Otherwise, email confirmation is required
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => EmailConfirmationScreen(
            email: _emailController.text.trim(),
          ),
        ),
      );
    } on AuthException catch (e) {
      setState(() => _error = _friendlyError(e));
    } catch (e) {
      setState(() => _error = _friendlyError(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isGoogleLoading = true;
      _error = null;
    });
    try {
      await AuthService.signInWithGoogle();
    } on AuthException catch (e) {
      setState(() => _error = _friendlyError(e));
    } catch (e) {
      setState(() => _error = _friendlyError(e));
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = RetroColors.of(context);
    final password = _passwordController.text;
    final hasMinLength = password.length >= 6;
    final hasUppercase = password.contains(RegExp(r'[A-Z]'));
    final hasNumber = password.contains(RegExp(r'[0-9]'));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('SIGN UP'),
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
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Form card
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
                          const SizedBox(height: RetroTheme.spacingMd),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            onChanged: (_) => setState(() {}),
                            decoration: InputDecoration(
                              labelText: 'PASSWORD',
                              prefixIcon: const Icon(LucideIcons.lock),
                              suffixIcon: Padding(
                                padding: const EdgeInsets.only(right: 4),
                                child: IconButton(
                                  icon: Icon(
                                    _obscurePassword ? LucideIcons.eyeOff : LucideIcons.eye,
                                    size: 20,
                                  ),
                                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                ),
                              ),
                              suffixIconConstraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Password is required';
                              }
                              if (value.length < 6) {
                                return 'Password must be at least 6 characters';
                              }
                              return null;
                            },
                          ),
                          // Password requirements
                          if (password.isNotEmpty) ...[
                            const SizedBox(height: RetroTheme.spacingSm),
                            _PasswordRequirement(label: 'At least 6 characters', met: hasMinLength, colors: colors),
                            _PasswordRequirement(label: 'One uppercase letter', met: hasUppercase, colors: colors),
                            _PasswordRequirement(label: 'One number', met: hasNumber, colors: colors),
                          ],
                          const SizedBox(height: RetroTheme.spacingMd),
                          TextFormField(
                            controller: _confirmPasswordController,
                            obscureText: _obscureConfirm,
                            decoration: InputDecoration(
                              labelText: 'CONFIRM PASSWORD',
                              prefixIcon: const Icon(LucideIcons.lock),
                              suffixIcon: Padding(
                                padding: const EdgeInsets.only(right: 4),
                                child: IconButton(
                                  icon: Icon(
                                    _obscureConfirm ? LucideIcons.eyeOff : LucideIcons.eye,
                                    size: 20,
                                  ),
                                  onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                                ),
                              ),
                              suffixIconConstraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please confirm your password';
                              }
                              if (value != _passwordController.text) {
                                return 'Passwords do not match';
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
                            text: 'Create Account',
                            onPressed: _handleSignUp,
                            color: RetroTheme.mint,
                            isLoading: _isLoading,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: RetroTheme.spacingLg),

                  // OR divider
                  Row(
                    children: [
                      Expanded(child: Divider(color: colors.borderSubtle)),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: RetroTheme.spacingMd,
                        ),
                        child: Text(
                          'OR',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: RetroTheme.fontSm,
                            color: colors.textMuted,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                      Expanded(child: Divider(color: colors.borderSubtle)),
                    ],
                  ),
                  const SizedBox(height: RetroTheme.spacingLg),

                  // Social buttons
                  RetroButton(
                    text: 'Continue with Google',
                    onPressed: _handleGoogleSignIn,
                    color: RetroTheme.blue,
                    isLoading: _isGoogleLoading,
                    icon: const Text('G', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
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

class _PasswordRequirement extends StatelessWidget {
  final String label;
  final bool met;
  final RetroColors colors;

  const _PasswordRequirement({
    required this.label,
    required this.met,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(
            met ? LucideIcons.checkCircle2 : LucideIcons.circle,
            size: 14,
            color: met ? RetroTheme.mint : colors.textMuted,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: met ? colors.text : colors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
