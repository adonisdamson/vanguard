import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_provider.dart';

enum AppUserRole { admin, manager, higherAuthority, personnel }

extension AppUserRoleLabel on AppUserRole {
  /// User-facing title (party-oriented wording).
  String get label {
    switch (this) {
      case AppUserRole.admin:
        return 'System Admin';
      case AppUserRole.manager:
        return 'Administrator';
      case AppUserRole.higherAuthority:
        return 'Coordinator';
      case AppUserRole.personnel:
        return 'Personnel';
    }
  }
}

enum UserLookupStatus { loading, noRow, active, suspended }

class AppUser {
  final String id;
  final String fullName;
  final String email;
  final AppUserRole role;
  final bool isActive;
  final String? avatarPath;
  final bool mustChangePassword;
  final String? partyPosition;
  final String? phone;
  final String? branch;

  const AppUser({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    required this.isActive,
    this.avatarPath,
    this.mustChangePassword = false,
    this.partyPosition,
    this.phone,
    this.branch,
  });

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      id: map['id'] as String,
      fullName: map['full_name'] as String,
      email: map['email'] as String,
      role: _parseRole(map['role'] as String?),
      isActive: map['is_active'] as bool? ?? false,
      avatarPath: map['avatar_path'] as String?,
      mustChangePassword: map['must_change_password'] as bool? ?? false,
      partyPosition: map['party_position'] as String?,
      phone: map['phone'] as String?,
      branch: map['branch'] as String?,
    );
  }

  // role is null for pending self-signup users — treat as personnel so the
  // router's isActive check still gates them to /pending-approval.
  static AppUserRole _parseRole(String? role) {
    switch (role) {
      case 'admin':
        return AppUserRole.admin;
      case 'manager':
        return AppUserRole.manager;
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
  // Hard timeout: a hung query must surface as a retryable error on the
  // gate screen, never as an indefinite loading state.
  final response = await supabase
      .from('app_users')
      .select('id, full_name, email, role, is_active, avatar_path, must_change_password, party_position, phone, branch')
      .eq('id', session.user.id)
      .maybeSingle()
      .timeout(const Duration(seconds: 10));

  if (response == null) return null;
  return AppUser.fromMap(response);
});
