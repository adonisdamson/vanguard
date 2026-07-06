import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../../core/router.dart';
import '../../application/auth_provider.dart';
import '../../application/user_role_provider.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/theme/app_spacing.dart';
import '../../../../shared/theme/app_text_styles.dart';
import '../../../../shared/widgets/lottie_loader.dart';
import '../../../../shared/widgets/ndc_button.dart';

/// Post-auth gate: the ONE place a signed-in user's role is resolved and
/// routed. Login and splash both land here; the router's redirect never
/// awaits anything. On failure/timeout this shows a real error with Retry
/// instead of an infinite spinner.
class AuthGateScreen extends ConsumerStatefulWidget {
  const AuthGateScreen({super.key});

  @override
  ConsumerState<AuthGateScreen> createState() => _AuthGateScreenState();
}

class _AuthGateScreenState extends ConsumerState<AuthGateScreen> {
  @override
  void initState() {
    super.initState();
    // Force a fresh fetch on every gate entry so we never navigate on a
    // stale cached row (e.g. an account approved since the last check).
    Future.microtask(() => ref.invalidate(appUserProvider));
  }

  void _retry() => ref.invalidate(appUserProvider);

  Future<void> _backToSignIn() async {
    await ref.read(authServiceProvider).signOut();
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<AppUser?>>(appUserProvider, (previous, next) {
      final user = next.valueOrNull;
      if (next is AsyncData<AppUser?> && context.mounted) {
        context.go(roleHomePath(user));
      }
    });

    final userAsync = ref.watch(appUserProvider);

    return Scaffold(
      backgroundColor: AppColors.paper,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
            child: userAsync.maybeWhen(
              error: (error, _) => _ErrorState(
                onRetry: _retry,
                onBackToSignIn: _backToSignIn,
              ),
              orElse: () => const _LoadingState(),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const LottieLoader(size: 56),
        const SizedBox(height: AppSpacing.base),
        Text('Signing you in…', style: AppTextStyles.body(color: AppColors.mist)),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  final VoidCallback onBackToSignIn;
  const _ErrorState({required this.onRetry, required this.onBackToSignIn});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const PhosphorIcon(PhosphorIconsRegular.wifiSlash,
            size: 48, color: AppColors.mist),
        const SizedBox(height: AppSpacing.base),
        Text("Couldn't load your account",
            style: AppTextStyles.h2(), textAlign: TextAlign.center),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Check your connection and try again.',
          style: AppTextStyles.body(color: AppColors.mist),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.xl),
        NdcButton(label: 'Retry', onPressed: onRetry),
        const SizedBox(height: AppSpacing.sm),
        TextButton(
          onPressed: onBackToSignIn,
          child: Text('Back to sign in',
              style: AppTextStyles.label(color: AppColors.canopyGreen)),
        ),
      ],
    );
  }
}
