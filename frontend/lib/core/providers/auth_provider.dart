import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

/// Exposes the current Supabase auth state as a stream.
final authStateProvider = StreamProvider<AuthState>((ref) {
  return Supabase.instance.client.auth.onAuthStateChange;
});

/// Exposes the current user (null if not logged in).
final currentUserProvider = Provider<User?>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.whenOrNull(data: (state) => state.session?.user);
});

/// Exposes the current session's access token for API calls.
final accessTokenProvider = Provider<String?>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.whenOrNull(data: (state) => state.session?.accessToken);
});

/// Auth service with sign-in/sign-up/sign-out methods.
class AuthService {
  static SupabaseClient get _client => Supabase.instance.client;

  /// Email + password sign up.
  static Future<AuthResponse> signUp({
    required String email,
    required String password,
  }) async {
    return await _client.auth.signUp(email: email, password: password);
  }

  /// Email + password sign in.
  static Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  /// Google Sign-In -> Supabase auth.
  /// Uses native flow on mobile, browser-based OAuth on desktop.
  static Future<AuthResponse?> signInWithGoogle() async {
    if (defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux) {
      // Desktop: use Supabase browser-based OAuth via external browser
      final res = await _client.auth.getOAuthSignInUrl(
        provider: OAuthProvider.google,
        redirectTo: 'com.validatyr.frontend://login-callback',
      );
      await launchUrl(
        Uri.parse(res.url!),
        mode: LaunchMode.externalApplication,
      );
      // Session will be picked up via deep link -> onAuthStateChange
      return null;
    }

    // Mobile: use native Google Sign-In
    const webClientId = '872879151769-aj472qg760uttmctm3rjo0i1i08daad5.apps.googleusercontent.com';
    const iosClientId = '872879151769-bh9hiebkp92jf5m09las0rlarke2uk40.apps.googleusercontent.com';

    final googleSignIn = GoogleSignIn(
      clientId: defaultTargetPlatform == TargetPlatform.iOS ? iosClientId : null,
      serverClientId: webClientId,
    );

    final googleUser = await googleSignIn.signIn();
    if (googleUser == null) throw Exception('Google sign-in cancelled');

    final googleAuth = await googleUser.authentication;
    final idToken = googleAuth.idToken;
    final accessToken = googleAuth.accessToken;

    if (idToken == null) throw Exception('No ID token from Google');

    return await _client.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: accessToken,
    );
  }

  /// Sign out.
  static Future<void> signOut() async {
    await _client.auth.signOut();
  }

  /// Delete account (signs out after).
  static Future<void> deleteAccount() async {
    await _client.auth.signOut();
  }
}
