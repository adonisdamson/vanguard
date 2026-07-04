import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart' hide OAuthProvider;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Supabase auth state stream
final supabaseAuthProvider = StreamProvider<Session?>((ref) {
  return Supabase.instance.client.auth.onAuthStateChange
      .map((event) => event.session);
});

// Current Supabase session (sync, derived from stream)
final currentSessionProvider = Provider<Session?>((ref) {
  return ref.watch(supabaseAuthProvider).valueOrNull;
});

// Auth service for login/logout actions
final authServiceProvider = Provider<AuthService>((ref) => AuthService());

class AuthService {
  final _supabase = Supabase.instance.client;
  final _firebase = FirebaseAuth.instance;
  final _googleSignIn = GoogleSignIn();

  Future<void> signInWithEmail(String email, String password) async {
    await _supabase.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signUp({
    required String fullName,
    required String email,
    required String password,
    String? requestedRole,
  }) async {
    final res = await _supabase.auth.signUp(
      email: email,
      password: password,
      data: {
        'full_name': fullName,
        if (requestedRole != null) 'requested_role': requestedRole,
      },
    );
    if (res.user == null) throw Exception('Sign-up failed. Please try again.');
    // handle_new_user trigger auto-creates the app_users row (pending, roleless)
  }

  Future<void> signInWithGoogle() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) throw Exception('Google sign-in cancelled');

    final googleAuth = await googleUser.authentication;
    if (googleAuth.idToken == null) {
      throw Exception('Failed to get Google ID token');
    }

    // Exchange Google token for Firebase credential (for Firebase session)
    await _firebase.signInWithCredential(
      GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      ),
    );

    // Exchange Google token for Supabase session (for RLS / auth.uid())
    await _supabase.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: googleAuth.idToken!,
      accessToken: googleAuth.accessToken,
    );
  }

  Future<void> sendPasswordResetEmail(String email) async {
    await _supabase.auth.resetPasswordForEmail(email);
  }

  Future<void> signOut() async {
    await Future.wait([
      _supabase.auth.signOut(),
      _firebase.signOut(),
      _googleSignIn.signOut(),
    ]);
  }
}
