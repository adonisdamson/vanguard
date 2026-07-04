import 'package:flutter_dotenv/flutter_dotenv.dart';
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

  // serverClientId must be the Web OAuth client ID from Google Cloud Console
  // (same one configured in Supabase → Auth → Providers → Google).
  // Set GOOGLE_WEB_CLIENT_ID in .env — see .env.example.
  GoogleSignIn get _googleSignIn => GoogleSignIn(
    serverClientId: dotenv.env['GOOGLE_WEB_CLIENT_ID'],
  );

  Future<void> signInWithEmail(String email, String password) async {
    await _supabase.auth.signInWithPassword(email: email, password: password);
  }

  // Returns true when a live session exists (email confirmation OFF),
  // false when the user must confirm their email first.
  Future<bool> signUp({
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
        'requested_role': ?requestedRole,
      },
    );
    if (res.user == null) throw Exception('Sign-up failed. Please try again.');
    // handle_new_user trigger auto-creates the app_users row (pending, roleless).
    // Do NOT insert into app_users here — the trigger owns that row creation.
    return res.session != null;
  }

  Future<void> signInWithGoogle() async {
    final gs = _googleSignIn;
    final googleUser = await gs.signIn();
    if (googleUser == null) return; // user cancelled — not an error

    final googleAuth = await googleUser.authentication;
    if (googleAuth.idToken == null) {
      throw Exception('Google did not return an ID token. Check serverClientId in .env.');
    }

    // Exchange Google token for Firebase credential
    await _firebase.signInWithCredential(
      GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      ),
    );

    // Exchange Google ID token for a Supabase session (drives RLS / auth.uid())
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
