import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/auth/application/auth_provider.dart';
import '../features/auth/application/user_role_provider.dart';
import '../features/auth/presentation/screens/splash_screen.dart';
import '../features/auth/presentation/screens/login_screen.dart';
import '../features/auth/presentation/screens/signup_screen.dart';
import '../features/auth/presentation/screens/forgot_password_screen.dart';
import '../features/auth/presentation/screens/pending_approval_screen.dart';
import '../features/members/presentation/screens/personnel_shell.dart';
import '../features/members/presentation/screens/registration_screen.dart';
import '../features/members/presentation/screens/my_submissions_screen.dart';
import '../features/members/presentation/screens/review_queue_screen.dart';
import '../features/members/presentation/screens/member_detail_screen.dart';
import '../features/members/presentation/screens/member_directory_screen.dart';
import '../features/dashboard/presentation/screens/higher_authority_shell.dart';
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
    redirect: (context, state) async {
      final session = ref.read(currentSessionProvider);
      final location = state.matchedLocation;

      if (location == '/') return null;

      const publicRoutes = {'/login', '/signup', '/forgot-password'};

      if (session == null) {
        if (publicRoutes.contains(location)) return null;
        return '/login';
      }

      if (location == '/pending-approval') return null;

      if (publicRoutes.contains(location)) {
        final user = await ref.read(appUserProvider.future);
        return _roleHome(user);
      }

      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (context, _) => const SplashScreen()),
      GoRoute(path: '/login', builder: (context, _) => const LoginScreen()),
      GoRoute(path: '/signup', builder: (context, _) => const SignUpScreen()),
      GoRoute(path: '/forgot-password', builder: (context, _) => const ForgotPasswordScreen()),
      GoRoute(path: '/pending-approval', builder: (context, _) => const PendingApprovalScreen()),

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

String _roleHome(AppUser? user) {
  if (user == null || !user.isActive) return '/pending-approval';
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
