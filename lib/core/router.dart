import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../features/auth/application/auth_provider.dart';
import '../features/auth/application/user_role_provider.dart';
import '../features/auth/presentation/screens/splash_screen.dart';
import '../features/auth/presentation/screens/auth_gate_screen.dart';
import '../features/auth/presentation/screens/login_screen.dart';
import '../features/auth/presentation/screens/signup_screen.dart';
import '../features/auth/presentation/screens/forgot_password_screen.dart';
import '../features/auth/presentation/screens/change_password_screen.dart';
import '../features/auth/presentation/screens/pending_approval_screen.dart';
import '../features/notifications/presentation/screens/notifications_screen.dart';
import '../features/members/presentation/screens/personnel_shell.dart';
import '../features/members/presentation/screens/registration_screen.dart';
import '../features/members/presentation/screens/my_submissions_screen.dart';
import '../features/members/presentation/screens/review_queue_screen.dart';
import '../features/members/presentation/screens/member_detail_screen.dart';
import '../features/members/presentation/screens/member_directory_screen.dart';
import '../features/dashboard/presentation/screens/higher_authority_shell.dart';
import '../features/tracker/presentation/screens/tracker_screen.dart';
import '../features/admin/presentation/screens/admin_shell.dart';
import '../features/admin/presentation/screens/operator_list_screen.dart';
import '../features/admin/presentation/screens/create_operator_screen.dart';
import '../features/admin/presentation/screens/lookup_tables_screen.dart';
import '../features/admin/presentation/screens/csv_import_screen.dart';
import '../features/admin/presentation/screens/audit_log_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = _AuthChangeNotifier(ref);

  final router = GoRouter(
    initialLocation: '/',
    refreshListenable: notifier,
    // SYNCHRONOUS on purpose. An async redirect that awaited appUserProvider
    // here raced the provider's own invalidation on the signedIn auth event,
    // so first-time logins never resolved (worked only after an app restart).
    // The redirect now only reads the synchronous session; role resolution
    // happens in exactly one place: AuthGateScreen at /resolving.
    redirect: (context, state) {
      final session = Supabase.instance.client.auth.currentSession;
      final location = state.matchedLocation;

      if (location == '/') return null;

      const publicRoutes = {'/login', '/signup', '/forgot-password'};

      if (session == null) {
        if (publicRoutes.contains(location)) return null;
        return '/login';
      }

      // Authenticated users don't belong on the auth entry screens.
      // (/forgot-password stays reachable — Profile uses it for password change.)
      if (location == '/login' || location == '/signup') return '/resolving';

      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (context, _) => const SplashScreen()),
      GoRoute(path: '/resolving', builder: (context, _) => const AuthGateScreen()),
      GoRoute(path: '/login', builder: (context, _) => const LoginScreen()),
      GoRoute(path: '/signup', builder: (context, _) => const SignUpScreen()),
      GoRoute(path: '/forgot-password', builder: (context, _) => const ForgotPasswordScreen()),
      GoRoute(path: '/pending-approval', builder: (context, _) => const PendingApprovalScreen()),
      GoRoute(
        path: '/change-password',
        builder: (context, state) =>
            ChangePasswordScreen(forced: state.uri.queryParameters['forced'] == '1'),
      ),
      GoRoute(path: '/notifications', builder: (context, _) => const NotificationsScreen()),

      // Personnel (shell provides bottom nav + IndexedStack)
      GoRoute(path: '/home', builder: (context, _) => const PersonnelShell()),
      GoRoute(path: '/register-member', builder: (context, _) => const RegistrationScreen()),
      GoRoute(path: '/my-submissions', builder: (context, _) => const MySubmissionsScreen()),

      // Higher Authority (shell provides bottom nav + IndexedStack)
      GoRoute(path: '/dashboard', builder: (context, _) => const HigherAuthorityShell()),
      GoRoute(path: '/review-queue', builder: (context, _) => const ReviewQueueScreen()),
      GoRoute(
        path: '/member/:id',
        builder: (context, state) => MemberDetailScreen(memberId: state.pathParameters['id']!),
      ),
      GoRoute(path: '/member-directory', builder: (context, _) => const MemberDirectoryScreen()),
      GoRoute(path: '/tracker', builder: (context, _) => const TrackerScreen()),

      // Admin (shell provides bottom nav + IndexedStack)
      GoRoute(path: '/admin', builder: (context, _) => const AdminShell()),
      GoRoute(path: '/admin/operators', builder: (context, _) => const OperatorListScreen()),
      GoRoute(path: '/admin/operators/create', builder: (context, _) => const CreateOperatorScreen()),
      GoRoute(path: '/admin/lookups', builder: (context, _) => const LookupTablesScreen()),
      GoRoute(path: '/admin/lookups/import-csv', builder: (context, _) => const CsvImportScreen()),
      GoRoute(path: '/admin/audit', builder: (context, _) => const AuditLogScreen()),
    ],
  );

  ref.onDispose(notifier.dispose);

  return router;
});

/// The single mapping from a resolved user to their home route. Used by
/// AuthGateScreen — nothing else should duplicate this switch.
String roleHomePath(AppUser? user) {
  if (user == null || !user.isActive) return '/pending-approval';
  // Admin-set password: force the operator to replace it before anything else.
  if (user.mustChangePassword) return '/change-password?forced=1';
  return switch (user.role) {
    AppUserRole.admin => '/admin',
    AppUserRole.higherAuthority => '/dashboard',
    AppUserRole.personnel => '/home',
  };
}

class _AuthChangeNotifier extends ChangeNotifier {
  _AuthChangeNotifier(Ref ref) {
    ref.listen(supabaseAuthProvider, (_, _) => notifyListeners());
  }
}
