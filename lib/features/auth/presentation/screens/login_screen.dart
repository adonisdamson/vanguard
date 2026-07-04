import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../../core/constants/assets.dart';
import '../../../../features/auth/application/auth_provider.dart';
import '../../../../features/auth/application/user_role_provider.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/theme/app_radii.dart';
import '../../../../shared/theme/app_spacing.dart';
import '../../../../shared/theme/app_text_styles.dart';
import '../../../../shared/widgets/canopy_arc.dart';
import '../../../../shared/widgets/ndc_button.dart';
import '../../../../shared/widgets/ndc_text_field.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey      = GlobalKey<FormState>();
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _emailFocus   = FocusNode();
  final _passwordFocus = FocusNode();

  bool _loading = false;
  bool _googleLoading = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      await ref.read(authServiceProvider).signInWithEmail(
        _emailCtrl.text.trim(), _passwordCtrl.text,
      );
      await _routeByRole();
    } catch (e, st) {
      debugPrint('[Login] error: $e\n$st');
      setState(() => _error = _humanize(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signInGoogle() async {
    setState(() { _googleLoading = true; _error = null; });
    try {
      await ref.read(authServiceProvider).signInWithGoogle();
      await _routeByRole();
    } catch (e, st) {
      debugPrint('[Login/Google] error: $e\n$st');
      setState(() => _error = _humanize(e));
    } finally {
      if (mounted) setState(() => _googleLoading = false);
    }
  }

  Future<void> _routeByRole() async {
    if (!mounted) return;
    ref.invalidate(appUserProvider);
    final user = await ref.read(appUserProvider.future);
    if (!mounted) return;
    if (user == null || !user.isActive) {
      context.go('/pending-approval');
    } else {
      switch (user.role) {
        case AppUserRole.admin:          context.go('/admin');
        case AppUserRole.higherAuthority: context.go('/dashboard');
        case AppUserRole.personnel:      context.go('/home');
      }
    }
  }

  String _humanize(Object e) {
    final s = e.toString();
    if (s.contains('Invalid login credentials') || s.contains('invalid_credentials')) {
      return 'Incorrect email or password. Please try again.';
    }
    if (s.contains('Email not confirmed')) {
      return 'Check your email and click the confirmation link first.';
    }
    if (s.contains('Too many requests')) {
      return 'Too many attempts. Wait a moment and try again.';
    }
    if (s.contains('SocketException') || s.contains('network') || s.contains('timeout')) {
      return 'You appear to be offline. Check your connection and try again.';
    }
    if (s.contains('cancelled') || s.contains('canceled')) return 'Sign-in was cancelled.';
    return 'Couldn\'t sign in: ${e.toString().split(']').last.trim()}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenH, AppSpacing.xl,
                    AppSpacing.screenH, AppSpacing.xxl),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_error != null) ...[
                        _ErrorBanner(
                          message: _error!,
                          onDismiss: () => setState(() => _error = null),
                        ),
                        const SizedBox(height: AppSpacing.base),
                      ],

                      NdcTextField(
                        label: 'Email address',
                        hint: 'you@ndc.org.gh',
                        icon: PhosphorIconsRegular.envelope,
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        focusNode: _emailFocus,
                        textInputAction: TextInputAction.next,
                        onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Email is required';
                          if (!v.contains('@')) return 'Enter a valid email address';
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSpacing.base),

                      NdcTextField(
                        label: 'Password',
                        hint: '••••••••',
                        icon: PhosphorIconsRegular.lock,
                        controller: _passwordCtrl,
                        obscureText: true,
                        focusNode: _passwordFocus,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _signIn(),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Password is required';
                          return null;
                        },
                      ),

                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => context.push('/forgot-password'),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 8),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text('Forgot password?',
                              style: AppTextStyles.label(
                                  color: AppColors.canopyGreen)),
                        ),
                      ),
                      const SizedBox(height: 4),

                      NdcButton(
                        label: 'Sign in',
                        onPressed: _signIn,
                        loading: _loading,
                        icon: const PhosphorIcon(
                            PhosphorIconsFill.signIn,
                            size: 18,
                            color: AppColors.surface),
                      ),
                      const SizedBox(height: AppSpacing.base),

                      Row(
                        children: [
                          const Expanded(child: Divider()),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text('or', style: AppTextStyles.caption()),
                          ),
                          const Expanded(child: Divider()),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.base),

                      _GoogleButton(
                          loading: _googleLoading, onPressed: _signInGoogle),
                      const SizedBox(height: AppSpacing.xl),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('New here? ', style: AppTextStyles.small()),
                          GestureDetector(
                            onTap: () => context.push('/signup'),
                            child: Text(
                              'Request access',
                              style: AppTextStyles.small(
                                      color: AppColors.canopyGreen)
                                  .copyWith(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Compact header band ≤ 180dp ───────────────────────────────────────────────

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const CanopyArc(height: 5),
        Container(
          color: AppColors.deepCanopy,
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenH, AppSpacing.xl,
              AppSpacing.screenH, AppSpacing.xxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Logo + wordmark row
              Row(
                children: [
                  Container(
                    width: 44, height: 44,
                    decoration: const BoxDecoration(
                      color: AppColors.surface,
                      shape: BoxShape.circle,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Image.asset(Assets.ndcUmbrella),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('VANGUARD',
                          style: AppTextStyles.h2(color: AppColors.surface)
                              .copyWith(letterSpacing: 3)),
                      Text('Membership Registry',
                          style: AppTextStyles.caption(
                              color: AppColors.surface
                                  .withValues(alpha: 0.65))),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              // H1, not Display — fits without scrolling
              Text('Welcome back.',
                  style: AppTextStyles.h1(color: AppColors.surface)),
              const SizedBox(height: 4),
              Text('Sign in to access the member registry.',
                  style: AppTextStyles.body(
                      color: AppColors.surface.withValues(alpha: 0.72))),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Google sign-in button with real multicolor G glyph ───────────────────────

class _GoogleButton extends StatelessWidget {
  final bool loading;
  final VoidCallback onPressed;
  const _GoogleButton({required this.loading, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: OutlinedButton(
        onPressed: loading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppColors.hairline, width: 1.5),
          shape: RoundedRectangleBorder(
              borderRadius: AppRadii.borderSm),
          backgroundColor: AppColors.surface,
        ),
        child: loading
            ? const SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2.5))
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _GoogleG(),
                  const SizedBox(width: 10),
                  Text('Continue with Google',
                      style: AppTextStyles.buttonText(
                          color: AppColors.ink)),
                ],
              ),
      ),
    );
  }
}

// Pixel-accurate Google G using the four canonical brand colors.
class _GoogleG extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: const Size(20, 20), painter: _GoogleGPainter());
}

class _GoogleGPainter extends CustomPainter {
  static const _blue   = Color(0xFF4285F4);
  static const _red    = Color(0xFFEA4335);
  static const _yellow = Color(0xFFFBBC05);
  static const _green  = Color(0xFF34A853);

  @override
  void paint(Canvas canvas, Size s) {
    final cx = s.width / 2;
    final cy = s.height / 2;
    final r  = s.width / 2;
    final paint = Paint()..style = PaintingStyle.stroke;

    // Blue top-right arc (0° → -180° counterclockwise, i.e. 0 → -π)
    paint.color = _blue;
    paint.strokeWidth = s.width * 0.22;
    paint.strokeCap = StrokeCap.butt;
    canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: r * 0.75),
        -0.5, 3.28, false, paint);

    // Horizontal G-bar (right side)
    paint.style = PaintingStyle.fill;
    paint.color = _blue;
    final barY = cy - r * 0.16;
    canvas.drawRect(
        Rect.fromLTWH(cx, barY, r * 0.85, r * 0.32), paint);

    // Color the four quadrant arcs
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = s.width * 0.22;

    // Red: top-left arc
    paint.color = _red;
    canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: r * 0.75),
        3.93, 1.05, false, paint);

    // Yellow: bottom-left
    paint.color = _yellow;
    canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: r * 0.75),
        2.62, 1.31, false, paint);

    // Green: bottom-right
    paint.color = _green;
    canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: r * 0.75),
        1.31, 1.31, false, paint);
  }

  @override
  bool shouldRepaint(_) => false;
}

// ── Error banner (dismissible) ────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onDismiss;
  const _ErrorBanner({required this.message, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: AppColors.redTint,
        borderRadius: AppRadii.borderSm,
        border: Border.all(
            color: AppColors.umbrellaRed.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const PhosphorIcon(PhosphorIconsFill.warningCircle,
              size: 16, color: AppColors.umbrellaRed),
          const SizedBox(width: 8),
          Expanded(
              child: Text(message,
                  style:
                      AppTextStyles.small(color: AppColors.umbrellaRed))),
          GestureDetector(
            onTap: onDismiss,
            child: const PhosphorIcon(PhosphorIconsRegular.x,
                size: 16, color: AppColors.umbrellaRed),
          ),
        ],
      ),
    );
  }
}
