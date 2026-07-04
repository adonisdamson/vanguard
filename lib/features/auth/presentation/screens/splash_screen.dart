import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/assets.dart';
import '../../../../features/auth/application/auth_provider.dart';
import '../../../../features/auth/application/user_role_provider.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/theme/app_text_styles.dart';
import '../../../../shared/widgets/canopy_arc.dart';
import '../../../../shared/widgets/lottie_loader.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _textController;
  late AnimationController _arcController;

  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<Offset> _wordmarkSlide;
  late Animation<double> _wordmarkOpacity;
  late Animation<double> _arcOpacity;

  @override
  void initState() {
    super.initState();

    _logoController = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _textController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _arcController  = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));

    _logoScale = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeOutBack),
    );
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeOut),
    );
    _wordmarkSlide = Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeOut),
    );
    _wordmarkOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeOut),
    );
    _arcOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _arcController, curve: Curves.easeOut),
    );

    _runSequence();
  }

  Future<void> _runSequence() async {
    await Future.delayed(const Duration(milliseconds: 200));
    _arcController.forward();
    await Future.delayed(const Duration(milliseconds: 150));
    await _logoController.forward();
    await Future.delayed(const Duration(milliseconds: 100));
    await _textController.forward();
    await Future.delayed(const Duration(milliseconds: 700));
    _navigate();
  }

  void _navigate() {
    final session = ref.read(currentSessionProvider);
    if (session == null) {
      if (mounted) context.go('/login');
      return;
    }
    ref.invalidate(appUserProvider);
    ref.read(appUserProvider.future).then((user) {
      if (!mounted) return;
      if (user == null || !user.isActive) {
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
    _arcController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canopyGreen,
      body: Stack(
        children: [
          // Canopy arc at top — the signature brand device
          Positioned(
            top: 0, left: 0, right: 0,
            child: FadeTransition(
              opacity: _arcOpacity,
              child: const CanopyArc(height: 6),
            ),
          ),

          // Center content
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // NDC Umbrella in a white circle
                ScaleTransition(
                  scale: _logoScale,
                  child: FadeTransition(
                    opacity: _logoOpacity,
                    child: Container(
                      width: 108,
                      height: 108,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(22),
                        child: Image.asset(Assets.ndcUmbrella),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                // Wordmark + Lottie loader
                SlideTransition(
                  position: _wordmarkSlide,
                  child: FadeTransition(
                    opacity: _wordmarkOpacity,
                    child: Column(
                      children: [
                        Text(
                          'VANGUARD',
                          style: AppTextStyles.displayLarge(color: AppColors.surface)
                              .copyWith(letterSpacing: 6),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Membership Registry',
                          style: AppTextStyles.body(
                            color: AppColors.surface.withValues(alpha: 0.70),
                          ),
                        ),
                        const SizedBox(height: 28),
                        // Lottie spinner recolored to surface via ColorFilter
                        ColorFiltered(
                          colorFilter: const ColorFilter.matrix([
                            // Swap canopyGreen to white (surface) for splash bg
                            0, 0, 0, 0, 1,
                            0, 0, 0, 0, 1,
                            0, 0, 0, 0, 1,
                            0, 0, 0, 1, 0,
                          ]),
                          child: const LottieLoader(size: 40),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
