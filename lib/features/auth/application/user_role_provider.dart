import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_provider.dart';

enum AppUserRole { admin, higherAuthority, personnel }

enum UserLookupStatus { loading, noRow, active, suspended }

class AppUser {
  final String id;
  final String fullName;
  final String email;
  final AppUserRole role;
  final bool isActive;

  const AppUser({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    required this.isActive,
  });

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      id: map['id'] as String,
      fullName: map['full_name'] as String,
      email: map['email'] as String,
      role: _parseRole(map['role'] as String),
      isActive: map['is_active'] as bool,
    );
  }

  static AppUserRole _parseRole(String role) {
    switch (role) {
      case 'admin':
        return AppUserRole.admin;
      case 'higher_authority':
        return AppUserRole.higherAuthority;
      default:
        return AppUserRole.personnel;
    }
  }
}

final appUserProvider = FutureProvider<AppUser?>((ref) async {
  // Watch stream for reactivity (re-runs when auth state changes),
  // but read the synchronous session so we never see a stale null
  // right after signInWithPassword returns.
  ref.watch(supabaseAuthProvider);
  final session = Supabase.instance.client.auth.currentSession;
  if (session == null) return null;

  final supabase = Supabase.instance.client;
  final response = await supabase
      .from('app_users')
      .select('id, full_name, email, role, is_active')
      .eq('id', session.user.id)
      .maybeSingle();

  if (response == null) return null;
  return AppUser.fromMap(response);
});
