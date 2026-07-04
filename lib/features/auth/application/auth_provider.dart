import 'package:flutter_riverpod/flutter_riverpod.dart';
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
        if (requestedRole != null) 'requested_role': requestedRole,
      },
    );
    if (res.user == null) throw Exception('Sign-up failed. Please try again.');
    // handle_new_user trigger auto-creates the app_users row (pending, roleless).
    return res.session != null;
  }

  Future<void> sendPasswordResetEmail(String email) async {
    await _supabase.auth.resetPasswordForEmail(email);
  }

  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }
}
