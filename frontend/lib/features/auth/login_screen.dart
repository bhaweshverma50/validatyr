import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/providers/auth_provider.dart';
import '../../core/theme/custom_theme.dart';
import '../../shared_widgets/retro_button.dart';
import '../../shared_widgets/retro_card.dart';
import 'signup_screen.dart';

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

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
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
                    icon: const Icon(LucideIcons.chrome),
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
