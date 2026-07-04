import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../../core/constants/assets.dart';
import '../../../../features/auth/application/auth_provider.dart';
import '../../../../features/auth/application/user_role_provider.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/theme/app_text_styles.dart';
import '../../../../shared/widgets/ndc_button.dart';
import '../../../../shared/widgets/canopy_arc.dart';
import '../../../../shared/widgets/ndc_text_field.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();

  bool _loading = false;
  bool _googleLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _signInWithEmail() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      await ref.read(authServiceProvider).signInWithEmail(
        _emailCtrl.text.trim(),
        _passwordCtrl.text,
      );
      await _routeByRole();
    } catch (e) {
      setState(() => _errorMessage = _humanizeError(e.toString()));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _googleLoading = true;
      _errorMessage = null;
    });
    try {
      await ref.read(authServiceProvider).signInWithGoogle();
      await _routeByRole();
    } catch (e) {
      setState(() => _errorMessage = _humanizeError(e.toString()));
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
        case AppUserRole.admin:
          context.go('/admin');
        case AppUserRole.higherAuthority:
          context.go('/dashboard');
        case AppUserRole.personnel:
          context.go('/home');
      }
    }
  }

  String _humanizeError(String raw) {
    if (raw.contains('Invalid login credentials') ||
        raw.contains('invalid_credentials')) {
      return 'Incorrect email or password. Please try again.';
    }
    if (raw.contains('Email not confirmed')) {
      return 'Please verify your email address first.';
    }
    if (raw.contains('Too many requests')) {
      return 'Too many attempts. Please wait a moment and try again.';
    }
    if (raw.contains('network') || raw.contains('SocketException')) {
      return 'No internet connection. Please check your network.';
    }
    if (raw.contains('cancelled') || raw.contains('canceled')) {
      return 'Sign-in was cancelled.';
    }
    return 'Something went wrong. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: size.height - MediaQuery.of(context).padding.top),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Canopy arc — signature brand device
                const CanopyArc(height: 5),

                // Header block — deepCanopy, circular logo + title
                Container(
                  color: AppColors.deepCanopy,
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 36),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 48, height: 48,
                            decoration: const BoxDecoration(
                              color: AppColors.surface,
                              shape: BoxShape.circle,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(9),
                              child: Image.asset(Assets.ndcUmbrella),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'VANGUARD',
                                style: AppTextStyles.h1(color: AppColors.surface)
                                    .copyWith(letterSpacing: 3),
                              ),
                              Text(
                                'Membership Registry',
                                style: AppTextStyles.small(
                                  color: AppColors.surface.withValues(alpha: 0.65),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),
                      Text(
                        'Welcome back.',
                        style: AppTextStyles.displayLarge(color: AppColors.surface),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Sign in to access the member registry.',
                        style: AppTextStyles.bodyLarge(
                          color: AppColors.surface.withValues(alpha: 0.75),
                        ),
                      ),
                    ],
                  ),
                ),

                // Form block
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Error banner
                        if (_errorMessage != null) ...[
                          _ErrorBanner(message: _errorMessage!),
                          const SizedBox(height: 20),
                        ],

                        NdcTextField(
                          label: 'Email Address',
                          hint: 'you@ndc.org.gh',
                          icon: PhosphorIconsRegular.envelope,
                          controller: _emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          focusNode: _emailFocus,
                          textInputAction: TextInputAction.next,
                          onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Email is required';
                            }
                            if (!v.contains('@')) return 'Enter a valid email';
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),

                        NdcTextField(
                          label: 'Password',
                          hint: '••••••••',
                          icon: PhosphorIconsRegular.lock,
                          controller: _passwordCtrl,
                          obscureText: true,
                          focusNode: _passwordFocus,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _signInWithEmail(),
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Password is required';
                            if (v.length < 6) return 'Password is too short';
                            return null;
                          },
                        ),

                        // Forgot password
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => context.push('/forgot-password'),
                            child: Text(
                              'Forgot password?',
                              style: AppTextStyles.bodyMedium(
                                color: AppColors.canopyGreen,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Sign in button
                        NdcButton(
                          label: 'Sign In',
                          onPressed: _signInWithEmail,
                          loading: _loading,
                          icon: const PhosphorIcon(PhosphorIconsFill.signIn, size: 18, color: AppColors.surface),
                        ),
                        const SizedBox(height: 16),

                        // Divider
                        Row(
                          children: [
                            const Expanded(child: Divider()),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: Text('or', style: AppTextStyles.small()),
                            ),
                            const Expanded(child: Divider()),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Google Sign-In
                        _GoogleSignInButton(
                          loading: _googleLoading,
                          onPressed: _signInWithGoogle,
                        ),

                        const SizedBox(height: 28),

                        // Sign-up link
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('New here? ', style: AppTextStyles.small()),
                            GestureDetector(
                              onTap: () => context.push('/signup'),
                              child: Text(
                                'Request access →',
                                style: AppTextStyles.small(color: AppColors.canopyGreen)
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
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.redTint,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.umbrellaRed.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const PhosphorIcon(
            PhosphorIconsFill.warningCircle,
            size: 18,
            color: AppColors.umbrellaRed,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.body(color: AppColors.umbrellaRed),
            ),
          ),
        ],
      ),
    );
  }
}

class _GoogleSignInButton extends StatelessWidget {
  final bool loading;
  final VoidCallback onPressed;

  const _GoogleSignInButton({required this.loading, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: OutlinedButton(
        onPressed: loading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppColors.hairline, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          backgroundColor: AppColors.surface,
        ),
        child: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Google "G" logo in brand colors
                  _GoogleLogo(),
                  const SizedBox(width: 10),
                  Text(
                    'Continue with Google',
                    style: AppTextStyles.buttonText().copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _GoogleLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(20, 20),
      painter: _GoogleLogoPainter(),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;

    // Simple colored "G" using arcs
    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(Rect.fromCircle(center: center, radius: r), -0.3, 3.8, false, paint..style = PaintingStyle.stroke..strokeWidth = size.width * 0.25);

    paint.style = PaintingStyle.fill;
    paint.color = const Color(0xFF4285F4);
    canvas.drawRect(Rect.fromLTWH(center.dx, center.dy - r * 0.2, r * 0.9, r * 0.4), paint);
  }

  @override
  bool shouldRepaint(_) => false;
}
