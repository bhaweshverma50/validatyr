import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/providers/auth_provider.dart';
import '../../core/theme/custom_theme.dart';
import '../../shared_widgets/retro_button.dart';
import '../../shared_widgets/retro_card.dart';
import 'signup_screen.dart';
import 'forgot_password_screen.dart';

final _emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  bool _isGoogleLoading = false;
  String? _error;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String _friendlyError(Object e) {
    final msg = e.toString();
    if (msg.contains('Invalid login credentials') || msg.contains('invalid_credentials')) {
      return 'Incorrect email or password. Please try again.';
    }
    if (msg.contains('Email not confirmed') || msg.contains('email_not_confirmed')) {
      return 'Please confirm your email before signing in. Check your inbox.';
    }
    if (msg.contains('rate limit') || msg.contains('over_request_rate_limit') || msg.contains('over_email_send_rate_limit')) {
      return 'Too many attempts. Please wait a moment and try again.';
    }
    if (msg.contains('User not found') || msg.contains('user_not_found')) {
      return 'No account found with this email. Sign up first.';
    }
    if (msg.contains('Network') || msg.contains('SocketException') || msg.contains('Connection')) {
      return 'Network error. Check your connection and try again.';
    }
    if (e is AuthApiException) return e.message;
    if (e is AuthException) return e.message;
    if (msg.startsWith('Exception: ')) return msg.substring(11);
    return 'Something went wrong. Please try again.';
  }

  Future<void> _handleSignIn() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await AuthService.signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text,
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
    final textTheme = Theme.of(context).textTheme;

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
                  // App title
                  Text(
                    'VALIDATYR',
                    style: textTheme.displayLarge?.copyWith(
                      fontSize: 36,
                      letterSpacing: 2.0,
                    ),
                  ),
                  const SizedBox(height: RetroTheme.spacingXs),
                  Text(
                    'AI-Powered Idea Validator',
                    style: textTheme.titleMedium?.copyWith(
                      color: colors.textMuted,
                    ),
                  ),
                  const SizedBox(height: RetroTheme.spacingXl),

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
                              return null;
                            },
                          ),
                          const SizedBox(height: RetroTheme.spacingSm),
                          Align(
                            alignment: Alignment.centerRight,
                            child: GestureDetector(
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
                                );
                              },
                              child: Text(
                                'Forgot password?',
                                style: TextStyle(
                                  color: colors.textMuted,
                                  fontWeight: FontWeight.w700,
                                  fontSize: RetroTheme.fontSm,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
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
                            text: 'Sign In',
                            onPressed: _handleSignIn,
                            color: RetroTheme.yellow,
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
                  const SizedBox(height: RetroTheme.spacingXl),

                  // Sign up link
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const SignUpScreen(),
                        ),
                      );
                    },
                    child: Text.rich(
                      TextSpan(
                        text: "Don't have an account? ",
                        style: TextStyle(
                          color: colors.textMuted,
                          fontSize: RetroTheme.fontMd,
                        ),
                        children: [
                          TextSpan(
                            text: 'Sign up',
                            style: TextStyle(
                              color: colors.text,
                              fontWeight: FontWeight.w800,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ],
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
}
