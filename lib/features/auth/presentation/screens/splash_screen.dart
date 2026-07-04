import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/assets.dart';
import '../../../../features/auth/application/auth_provider.dart';
import '../../../../features/auth/application/user_role_provider.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/theme/app_text_styles.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _textController;
  late AnimationController _stripeController;

  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<Offset> _wordmarkSlide;
  late Animation<double> _wordmarkOpacity;
  late Animation<double> _stripeWidth;

  @override
  void initState() {
    super.initState();

    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _stripeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _logoScale = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeOutBack),
    );
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeOut),
    );
    _wordmarkSlide = Tween<Offset>(
      begin: const Offset(0, 0.4),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _textController, curve: Curves.easeOut));
    _wordmarkOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeOut),
    );
    _stripeWidth = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _stripeController, curve: Curves.easeOut),
    );

    _runSequence();
  }

  Future<void> _runSequence() async {
    await Future.delayed(const Duration(milliseconds: 300));
    await _logoController.forward();
    await Future.delayed(const Duration(milliseconds: 100));
    await _textController.forward();
    await _stripeController.forward();
    await Future.delayed(const Duration(milliseconds: 600));
    _navigate();
  }

  void _navigate() {
    final session = ref.read(currentSessionProvider);
    if (session == null) {
      if (mounted) context.go('/login');
      return;
    }
    // Session exists — invalidate so we get a fresh lookup, not cached null
    ref.invalidate(appUserProvider);
    ref.read(appUserProvider.future).then((user) {
      if (!mounted) return;
      if (user == null) {
        context.go('/pending-approval');
      } else if (!user.isActive) {
        context.go('/pending-approval');
      } else {
        switch (user.role) {
          case AppUserRole.admin:
            context.go('/admin');
          case AppUserRole.higherAuthority:
            context.go('/dashboard');
          case AppUserRole.personnel:
            context.go('/home');
        }
      }
    }).catchError((_) {
      if (mounted) context.go('/login');
    });
  }

  @override
  void dispose() {
    _logoController.dispose();
    _textController.dispose();
    _stripeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ndcGreen,
      body: Stack(
        children: [
          // Background texture — subtle Ghana flag brushstroke
          Positioned.fill(
            child: Opacity(
              opacity: 0.04,
              child: Image.asset(
                Assets.ghanaFlag,
                fit: BoxFit.cover,
              ),
            ),
          ),

          // Center content
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // NDC Umbrella logo
                ScaleTransition(
                  scale: _logoScale,
                  child: FadeTransition(
                    opacity: _logoOpacity,
                    child: Image.asset(
                      Assets.ndcUmbrella,
                      width: 100,
                      height: 100,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // VANGUARD wordmark
                SlideTransition(
                  position: _wordmarkSlide,
                  child: FadeTransition(
                    opacity: _wordmarkOpacity,
                    child: Column(
                      children: [
                        Text(
                          'VANGUARD',
                          style: AppTextStyles.displayLarge(
                            color: AppColors.ndcWhite,
                          ).copyWith(letterSpacing: 6),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'NDC Member Registry',
                          style: AppTextStyles.bodyMedium(
                            color: AppColors.ndcWhite.withValues(alpha: 0.75),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // NDC flag stripe at the bottom
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: AnimatedBuilder(
              animation: _stripeWidth,
              builder: (_, __) => Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: _stripeWidth.value,
                  child: const _FlagStripeBar(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FlagStripeBar extends StatelessWidget {
  const _FlagStripeBar();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 6,
      child: Row(
        children: [
          Expanded(child: ColoredBox(color: AppColors.ndcBlack)),
          Expanded(child: ColoredBox(color: AppColors.ndcRed)),
          Expanded(child: ColoredBox(color: AppColors.ndcWhite)),
          Expanded(child: ColoredBox(color: AppColors.ndcGreen.withValues(alpha: 0.5))),
        ],
      ),
    );
  }
}
