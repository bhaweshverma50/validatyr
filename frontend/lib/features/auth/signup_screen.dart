import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/providers/auth_provider.dart';
import '../../core/theme/custom_theme.dart';
import '../../shared_widgets/retro_button.dart';
import '../../shared_widgets/retro_card.dart';

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
  bool _showSuccess = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignUp() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _error = null;
      _showSuccess = false;
    });
    try {
      await AuthService.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (mounted) {
        setState(() => _showSuccess = true);
      }
    } catch (e) {
      setState(() => _error = e.toString());
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
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = RetroColors.of(context);

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
                            decoration: const InputDecoration(
                              labelText: 'EMAIL',
                              prefixIcon: Icon(LucideIcons.mail),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Email is required';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: RetroTheme.spacingMd),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText: 'PASSWORD',
                              prefixIcon: Icon(LucideIcons.lock),
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
                          const SizedBox(height: RetroTheme.spacingMd),
                          TextFormField(
                            controller: _confirmPasswordController,
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText: 'CONFIRM PASSWORD',
                              prefixIcon: Icon(LucideIcons.lock),
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
                            Text(
                              _error!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                                fontWeight: FontWeight.w600,
                                fontSize: RetroTheme.fontSm,
                              ),
                            ),
                          ],
                          if (_showSuccess) ...[
                            const SizedBox(height: RetroTheme.spacingMd),
                            Container(
                              padding: const EdgeInsets.all(RetroTheme.spacingMd),
                              decoration: RetroTheme.badgeDecoration(
                                RetroTheme.mint,
                                borderColor: colors.border,
                              ),
                              child: const Text(
                                'Check your email to confirm your account.',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: RetroTheme.fontMd,
                                  color: Colors.black,
                                ),
                                textAlign: TextAlign.center,
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
                    icon: const Icon(LucideIcons.chrome),
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
