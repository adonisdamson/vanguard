import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../../core/errors/app_error_mapper.dart';
import '../../../../core/auth/phone_identity.dart';
import '../../../../features/auth/application/auth_provider.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/theme/app_radii.dart';
import '../../../../shared/theme/app_spacing.dart';
import '../../../../shared/theme/app_text_styles.dart';
import '../../../../shared/widgets/form_scaffold.dart';
import '../../../../shared/widgets/ndc_text_field.dart';
import '../widgets/auth_hero.dart';
import '../../../../shared/widgets/ndc_button.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey       = GlobalKey<FormState>();
  final _emailCtrl     = TextEditingController();
  final _passwordCtrl  = TextEditingController();
  final _emailFocus    = FocusNode();
  final _passwordFocus = FocusNode();

  bool    _loading = false;
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
    // Phone → synthetic email; real emails (admins) pass through unchanged.
    final email = PhoneIdentity.resolveToEmail(_emailCtrl.text);
    if (email == null) {
      setState(() => _error = 'Enter a valid phone number.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await ref.read(authServiceProvider).signInWithEmail(
        email, _passwordCtrl.text,
      );
      // Navigate explicitly — never wait for an auth-stream tick or a
      // provider rebuild to move the user. Role resolution happens on the
      // gate screen, which has its own timeout + retry.
      if (mounted) context.go('/resolving');
    } catch (e, st) {
      final msg = AppErrorMapper.forAuth(e, st) ??
          "Something didn't work. Please try again.";
      if (mounted) setState(() => _error = msg);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FormScaffold(
      // Inset above the keyboard so the password field + Sign in button stay
      // visible and the focused field auto-scrolls into view (the keyboard must
      // never cover the password).
      resizeToAvoidBottomInset: true,
      actionBar: FormActionBar(
        primaryLabel: 'Sign in',
        onPrimary: _signIn,
        loading: _loading,
        primaryIcon: const PhosphorIcon(PhosphorIconsFill.arrowLineRight,
            size: 18, color: AppColors.surface),
        secondaryAction: NdcButton(
          label: 'Request access',
          variant: NdcButtonVariant.secondary,
          icon: const PhosphorIcon(PhosphorIconsRegular.userPlus,
              size: 18, color: AppColors.brand),
          onPressed: () => context.push('/signup'),
        ),
      ),
      body: SingleChildScrollView(
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
                        label: 'Phone number',
                        hint: 'e.g. 0244123456',
                        icon: PhosphorIconsRegular.phone,
                        controller: _emailCtrl,
                        keyboardType: TextInputType.text,
                        focusNode: _emailFocus,
                        textInputAction: TextInputAction.next,
                        onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
                        validator: (v) {
                          final s = (v ?? '').trim();
                          if (s.isEmpty) return 'Phone number is required';
                          if (s.contains('@')) return null; // admin email
                          if (PhoneIdentity.normalize(s) == null) {
                            return 'Enter a valid phone number';
                          }
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
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Photo hero (login) ────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AuthHero(
      title: 'Welcome back.',
      subtitle: 'Sign in to access the member registry.',
    );
  }
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
                  style: AppTextStyles.small(color: AppColors.umbrellaRed))),
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
