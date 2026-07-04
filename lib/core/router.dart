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
import '../features/members/presentation/screens/personnel_home_screen.dart';
import '../features/members/presentation/screens/registration_screen.dart';
import '../features/members/presentation/screens/my_submissions_screen.dart';
import '../features/members/presentation/screens/review_queue_screen.dart';
import '../features/members/presentation/screens/member_detail_screen.dart';
import '../features/members/presentation/screens/member_directory_screen.dart';
import '../features/dashboard/presentation/screens/higher_authority_home_screen.dart';
import '../features/admin/presentation/screens/admin_home_screen.dart';
import '../features/admin/presentation/screens/operator_list_screen.dart';
import '../features/admin/presentation/screens/create_operator_screen.dart';
import '../features/admin/presentation/screens/lookup_tables_screen.dart';
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
      GoRoute(path: '/', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/signup', builder: (_, __) => const SignUpScreen()),
      GoRoute(path: '/forgot-password', builder: (_, __) => const ForgotPasswordScreen()),
      GoRoute(path: '/pending-approval', builder: (_, __) => const PendingApprovalScreen()),

      // Personnel
      GoRoute(path: '/home', builder: (_, __) => const PersonnelHomeScreen()),
      GoRoute(path: '/register-member', builder: (_, __) => const RegistrationScreen()),
      GoRoute(path: '/my-submissions', builder: (_, __) => const MySubmissionsScreen()),

      // Higher Authority
      GoRoute(path: '/dashboard', builder: (_, __) => const HigherAuthorityHomeScreen()),
      GoRoute(path: '/review-queue', builder: (_, __) => const ReviewQueueScreen()),
      GoRoute(
        path: '/member/:id',
        builder: (_, state) => MemberDetailScreen(memberId: state.pathParameters['id']!),
      ),
      GoRoute(path: '/member-directory', builder: (_, __) => const MemberDirectoryScreen()),

      // Admin
      GoRoute(path: '/admin', builder: (_, __) => const AdminHomeScreen()),
      GoRoute(path: '/admin/operators', builder: (_, __) => const OperatorListScreen()),
      GoRoute(path: '/admin/operators/create', builder: (_, __) => const CreateOperatorScreen()),
      GoRoute(path: '/admin/lookups', builder: (_, __) => const LookupTablesScreen()),
      GoRoute(path: '/admin/audit', builder: (_, __) => const AuditLogScreen()),
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
    ref.listen(supabaseAuthProvider, (_, __) => notifyListeners());
  }
}
