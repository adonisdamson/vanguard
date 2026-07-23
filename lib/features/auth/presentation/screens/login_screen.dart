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
import '../../../../shared/widgets/ndc_text_field.dart';
import '../widgets/auth_hero.dart';
import '../../../../shared/widgets/ndc_button.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey      = GlobalKey<FormState>();
  final _phoneCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _phoneFocus   = FocusNode();
  final _passwordFocus = FocusNode();

  bool    _loading = false;
  String? _error;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    _phoneFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    final email = PhoneIdentity.resolveToEmail(_phoneCtrl.text);
    if (email == null) {
      setState(() => _error = 'Enter a valid phone number.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await ref.read(authServiceProvider).signInWithEmail(
        email, _passwordCtrl.text,
      );
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
    // Buttons live INSIDE the scroll view so they are never pushed up over the
    // phone field when the keyboard opens.  resizeToAvoidBottomInset shrinks
    // the Scaffold body and Flutter auto-scrolls the focused text field into
    // view, so the phone/password fields are always readable while typing.
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: AppColors.paper,
      body: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AuthHero(
              title: 'Welcome back.',
              subtitle: 'Sign in to access the member registry.',
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenH, AppSpacing.xl,
                  AppSpacing.screenH, AppSpacing.xl),
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
                      controller: _phoneCtrl,
                      keyboardType: TextInputType.phone,
                      focusNode: _phoneFocus,
                      textInputAction: TextInputAction.next,
                      onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
                      // Clear any stale error the moment the user starts typing.
                      onChanged: (_) {
                        if (_error != null) setState(() => _error = null);
                      },
                      validator: (v) {
                        final s = (v ?? '').trim();
                        if (s.isEmpty) return 'Phone number is required';
                        if (s.contains('@')) return null; // admin email
                        if (PhoneIdentity.normalize(s) == null) {
                          return 'Enter a valid 10-digit Ghana phone number';
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

                    const SizedBox(height: AppSpacing.xl),

                    // ── Action buttons ─────────────────────────────────────
                    // Placed INSIDE the scroll view so the keyboard never
                    // pushes them up over the input fields.
                    NdcButton(
                      label: 'Sign in',
                      onPressed: _loading ? null : _signIn,
                      loading: _loading,
                      icon: const PhosphorIcon(PhosphorIconsFill.arrowLineRight,
                          size: 18, color: AppColors.surface),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    NdcButton(
                      label: 'Request access',
                      variant: NdcButtonVariant.secondary,
                      icon: const PhosphorIcon(PhosphorIconsRegular.userPlus,
                          size: 18, color: AppColors.brand),
                      onPressed: _loading ? null : () => context.push('/signup'),
                    ),
                  ],
                ),
              ),
            ),
            // Bottom safe-area padding so the last button is never clipped by
            // the system gesture bar on phones without bezels.
            SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
          ],
        ),
      ),
    );
  }
}

// ── Error banner ──────────────────────────────────────────────────────────────

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
