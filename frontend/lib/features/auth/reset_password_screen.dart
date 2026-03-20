import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/custom_theme.dart';
import '../../shared_widgets/retro_button.dart';
import '../../shared_widgets/retro_card.dart';

class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  ConsumerState<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  bool _success = false;
  String? _error;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _handleReset() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: _passwordController.text),
      );
      if (mounted) setState(() => _success = true);
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = RetroColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final password = _passwordController.text;
    final hasMinLength = password.length >= 6;
    final hasUppercase = password.contains(RegExp(r'[A-Z]'));
    final hasNumber = password.contains(RegExp(r'[0-9]'));

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
              child: _success ? _buildSuccess(colors, textTheme) : _buildForm(colors, textTheme, hasMinLength, hasUppercase, hasNumber),
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
        Icon(LucideIcons.shieldCheck, size: 64, color: colors.text),
        const SizedBox(height: RetroTheme.spacingLg),
        Text(
          'PASSWORD UPDATED',
          style: textTheme.displayLarge?.copyWith(fontSize: 28, letterSpacing: 2.0),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: RetroTheme.spacingMd),
        Text(
          'Your password has been changed successfully.',
          style: TextStyle(fontSize: RetroTheme.fontMd, color: colors.textMuted),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: RetroTheme.spacingXl),
        RetroButton(
          text: 'Continue',
          onPressed: () {
            Navigator.of(context).popUntil((route) => route.isFirst);
          },
          color: RetroTheme.mint,
        ),
      ],
    );
  }

  Widget _buildForm(RetroColors colors, TextTheme textTheme, bool hasMinLength, bool hasUppercase, bool hasNumber) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(LucideIcons.keyRound, size: 48, color: colors.text),
        const SizedBox(height: RetroTheme.spacingMd),
        Text(
          'SET NEW PASSWORD',
          style: textTheme.displayLarge?.copyWith(fontSize: 28, letterSpacing: 2.0),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: RetroTheme.spacingSm),
        Text(
          'Choose a strong password for your account.',
          style: TextStyle(fontSize: RetroTheme.fontMd, color: colors.textMuted),
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
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'NEW PASSWORD',
                    prefixIcon: const Icon(LucideIcons.lock),
                    suffixIcon: Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: IconButton(
                        icon: Icon(_obscurePassword ? LucideIcons.eyeOff : LucideIcons.eye, size: 20),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                    suffixIconConstraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Password is required';
                    if (value.length < 6) return 'Password must be at least 6 characters';
                    return null;
                  },
                ),
                if (_passwordController.text.isNotEmpty) ...[
                  const SizedBox(height: RetroTheme.spacingSm),
                  _Req(label: 'At least 6 characters', met: hasMinLength, colors: colors),
                  _Req(label: 'One uppercase letter', met: hasUppercase, colors: colors),
                  _Req(label: 'One number', met: hasNumber, colors: colors),
                ],
                const SizedBox(height: RetroTheme.spacingMd),
                TextFormField(
                  controller: _confirmController,
                  obscureText: _obscureConfirm,
                  decoration: InputDecoration(
                    labelText: 'CONFIRM PASSWORD',
                    prefixIcon: const Icon(LucideIcons.lock),
                    suffixIcon: Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: IconButton(
                        icon: Icon(_obscureConfirm ? LucideIcons.eyeOff : LucideIcons.eye, size: 20),
                        onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                      ),
                    ),
                    suffixIconConstraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Please confirm your password';
                    if (value != _passwordController.text) return 'Passwords do not match';
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
                      border: Border.all(color: Theme.of(context).colorScheme.error.withValues(alpha: 0.4), width: 1.5),
                    ),
                    child: Row(
                      children: [
                        Icon(LucideIcons.alertCircle, size: 18, color: Theme.of(context).colorScheme.error),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error, fontWeight: FontWeight.w700, fontSize: RetroTheme.fontSm)),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: RetroTheme.spacingLg),
                RetroButton(
                  text: 'Update Password',
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

class _Req extends StatelessWidget {
  final String label;
  final bool met;
  final RetroColors colors;
  const _Req({required this.label, required this.met, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(met ? LucideIcons.checkCircle2 : LucideIcons.circle, size: 14, color: met ? RetroTheme.mint : colors.textMuted),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: met ? colors.text : colors.textMuted)),
        ],
      ),
    );
  }
}
