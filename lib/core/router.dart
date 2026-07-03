import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/auth/application/auth_provider.dart';
import '../features/auth/application/user_role_provider.dart';
import '../features/auth/presentation/screens/splash_screen.dart';
import '../features/auth/presentation/screens/login_screen.dart';
import '../features/auth/presentation/screens/forgot_password_screen.dart';
import '../features/auth/presentation/screens/pending_approval_screen.dart';
import '../features/members/presentation/screens/personnel_home_screen.dart';
import '../features/dashboard/presentation/screens/higher_authority_home_screen.dart';
import '../features/admin/presentation/screens/admin_home_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = _AuthChangeNotifier(ref);

  final router = GoRouter(
    initialLocation: '/',
    refreshListenable: notifier,
    redirect: (context, state) async {
      final session = ref.read(currentSessionProvider);
      final location = state.matchedLocation;

      // Splash handles its own navigation
      if (location == '/') return null;

      const publicRoutes = {'/login', '/forgot-password'};

      if (session == null) {
        if (publicRoutes.contains(location)) return null;
        return '/login';
      }

      // Logged in but explicitly on pending-approval is valid
      if (location == '/pending-approval') return null;

      // Redirect away from auth screens when logged in
      if (publicRoutes.contains(location)) {
        final user = await ref.read(appUserProvider.future);
        return _roleHome(user);
      }

      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/forgot-password', builder: (_, __) => const ForgotPasswordScreen()),
      GoRoute(path: '/pending-approval', builder: (_, __) => const PendingApprovalScreen()),
      GoRoute(path: '/home', builder: (_, __) => const PersonnelHomeScreen()),
      GoRoute(path: '/dashboard', builder: (_, __) => const HigherAuthorityHomeScreen()),
      GoRoute(path: '/admin', builder: (_, __) => const AdminHomeScreen()),
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
    ref.listen(supabaseAuthProvider, (_, __) {
      notifyListeners();
    });
  }
}
