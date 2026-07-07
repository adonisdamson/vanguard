import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../../core/errors/app_error_mapper.dart';
import '../../application/auth_provider.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/theme/app_radii.dart';
import '../../../../shared/theme/app_spacing.dart';
import '../../../../shared/theme/app_text_styles.dart';
import '../../../../shared/widgets/form_scaffold.dart';
import '../../../../shared/widgets/ndc_button.dart';
import '../../../../shared/widgets/ndc_text_field.dart';
import '../widgets/auth_hero.dart';

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _formKey     = GlobalKey<FormState>();
  final _nameCtrl    = TextEditingController();
  final _emailCtrl   = TextEditingController();
  final _passCtrl    = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _loading = false;
  String? _error;
  String? _requestedRole;

  // Inline live-validation state
  bool _passLengthOk = false;
  bool _passMatch    = false;

  // After success: email confirmation needed?
  bool _awaitingEmailConfirm = false;

  @override
  void initState() {
    super.initState();
    _passCtrl.addListener(_onPassChanged);
    _confirmCtrl.addListener(_onPassChanged);
  }

  void _onPassChanged() {
    final pw = _passCtrl.text;
    final cf = _confirmCtrl.text;
    setState(() {
      _passLengthOk = pw.length >= 8;
      _passMatch    = pw.isNotEmpty && pw == cf;
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      final hasSession = await ref.read(authServiceProvider).signUp(
        fullName:      _nameCtrl.text.trim(),
        email:         _emailCtrl.text.trim(),
        password:      _passCtrl.text,
        requestedRole: _requestedRole,
      );
      if (!mounted) return;
      if (hasSession) {
        context.go('/pending-approval');
      } else {
        // Email confirmation is required — show inline confirmation state
        setState(() { _awaitingEmailConfirm = true; _loading = false; });
      }
    } catch (e, st) {
      if (mounted) {
        setState(() {
          _error = AppErrorMapper.forAuth(e, st) ??
              "Something didn't work. Please try again.";
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_awaitingEmailConfirm) return _EmailSentScreen(email: _emailCtrl.text.trim());

    return FormScaffold(
      actionBar: FormActionBar(
        primaryLabel: 'Request access',
        onPrimary: _submit,
        loading: _loading,
        primaryIcon: const PhosphorIcon(PhosphorIconsFill.paperPlaneRight,
            size: 18, color: AppColors.surface),
        secondaryAction: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Already have access? ', style: AppTextStyles.small()),
            GestureDetector(
              onTap: () => context.pop(),
              child: Text(
                'Sign in',
                style: AppTextStyles.small(color: AppColors.canopyGreen)
                    .copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ],
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
                    AppSpacing.screenH, AppSpacing.h2),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_error != null) ...[
                        _ErrorBanner(
                          message: _error!,
                          // If already-registered, show Sign in link
                          showSignInLink:
                              _error!.contains('already has an account'),
                          onSignIn: () => context.go('/login'),
                          onDismiss: () =>
                              setState(() => _error = null),
                        ),
                        const SizedBox(height: AppSpacing.base),
                      ],

                      NdcTextField(
                        label: 'Full name',
                        hint: 'Kwame Mensah',
                        icon: PhosphorIconsRegular.person,
                        controller: _nameCtrl,
                        textInputAction: TextInputAction.next,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Full name is required';
                          }
                          if (v.trim().split(' ').length < 2) {
                            return 'Enter first and last name';
                          }
                          return null;
                        },
                        onChanged: (_) {},
                      ),
                      const SizedBox(height: AppSpacing.base),

                      NdcTextField(
                        label: 'Email address',
                        hint: 'you@ndc.org.gh',
                        icon: PhosphorIconsRegular.envelope,
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Email is required';
                          }
                          if (!v.contains('@')) {
                            return 'Enter a valid email address';
                          }
                          return null;
                        },
                        onChanged: (_) {},
                      ),
                      const SizedBox(height: AppSpacing.base),

                      NdcTextField(
                        label: 'Password',
                        hint: '••••••••',
                        icon: PhosphorIconsRegular.lock,
                        controller: _passCtrl,
                        obscureText: true,
                        textInputAction: TextInputAction.next,
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return 'Password is required';
                          }
                          if (v.length < 8) {
                            return 'Use at least 8 characters';
                          }
                          return null;
                        },
                        onChanged: (_) {},
                      ),
                      const SizedBox(height: AppSpacing.base),

                      NdcTextField(
                        label: 'Confirm password',
                        hint: '••••••••',
                        icon: PhosphorIconsRegular.lockKey,
                        controller: _confirmCtrl,
                        obscureText: true,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _submit(),
                        validator: (v) {
                          if (v != _passCtrl.text) {
                            return 'Passwords don\'t match';
                          }
                          return null;
                        },
                        onChanged: (_) {},
                      ),

                      // Live password feedback
                      const SizedBox(height: AppSpacing.sm),
                      _PassFeedback(
                          lengthOk: _passLengthOk, matchOk: _passMatch),

                      const SizedBox(height: AppSpacing.lg),

                      _RolePicker(
                        value: _requestedRole,
                        onChanged: (v) =>
                            setState(() => _requestedRole = v),
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

// ── Compact header (same pattern as login) ────────────────────────────────────

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const AuthHero(
      title: 'Request access.',
      subtitle:
          'Create your account — an administrator activates it and assigns your role.',
    );
  }
}

// ── Live password feedback pills ──────────────────────────────────────────────

class _PassFeedback extends StatelessWidget {
  final bool lengthOk;
  final bool matchOk;
  const _PassFeedback({required this.lengthOk, required this.matchOk});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _Pill('8+ characters', lengthOk),
        const SizedBox(width: 8),
        _Pill('Passwords match', matchOk),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final bool ok;
  const _Pill(this.label, this.ok);

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: ok ? AppColors.greenTint : AppColors.fillMuted,
        borderRadius: AppRadii.borderPill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PhosphorIcon(
            ok ? PhosphorIconsFill.checkCircle : PhosphorIconsRegular.circle,
            size: 12,
            color: ok ? AppColors.canopyGreen : AppColors.mist,
          ),
          const SizedBox(width: 4),
          Text(label,
              style: AppTextStyles.caption(
                  color: ok ? AppColors.canopyGreen : AppColors.mist)),
        ],
      ),
    );
  }
}

// ── Compact role picker (56dp rows) ──────────────────────────────────────────

class _RolePicker extends StatelessWidget {
  final String? value;
  final void Function(String?) onChanged;
  const _RolePicker({required this.value, required this.onChanged});

  static const _opts = [
    ('personnel',        PhosphorIconsRegular.pencilSimple,
     'Personnel',       'Register and manage members'),
    ('higher_authority', PhosphorIconsRegular.chartBar,
     'Coordinator',     'Review registrations & view reports'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Intended role', style: AppTextStyles.label()),
        const SizedBox(height: 2),
        Text('Optional — helps your admin assign the right role quickly.',
            style: AppTextStyles.small()),
        const SizedBox(height: AppSpacing.sm),
        ..._opts.map((o) {
          final (key, icon, label, desc) = o;
          final sel = value == key;
          return GestureDetector(
            onTap: () => onChanged(sel ? null : key),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.only(bottom: AppSpacing.sm),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: sel ? AppColors.greenTint : AppColors.surface,
                borderRadius: AppRadii.borderMd,
                border: Border.all(
                    color: sel ? AppColors.canopyGreen : AppColors.hairline,
                    width: sel ? 1.5 : 1),
              ),
              child: Row(
                children: [
                  Container(
                    width: 34, height: 34,
                    decoration: BoxDecoration(
                      color: sel
                          ? AppColors.canopyGreen
                          : AppColors.fillMuted,
                      borderRadius: AppRadii.borderSm,
                    ),
                    child: Center(
                      child: PhosphorIcon(icon,
                          size: 16,
                          color: sel
                              ? AppColors.surface
                              : AppColors.mist),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label, style: AppTextStyles.bodyMedium()),
                        Text(desc, style: AppTextStyles.small()),
                      ],
                    ),
                  ),
                  Container(
                    width: 18, height: 18,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: sel
                          ? AppColors.canopyGreen
                          : AppColors.fillMuted,
                      border: Border.all(
                          color: sel
                              ? AppColors.canopyGreen
                              : AppColors.hairline),
                    ),
                    child: sel
                        ? const PhosphorIcon(PhosphorIconsFill.check,
                            size: 11, color: AppColors.surface)
                        : null,
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

// ── Error banner (with optional "Sign in" link) ───────────────────────────────

class _ErrorBanner extends StatelessWidget {
  final String message;
  final bool showSignInLink;
  final VoidCallback onSignIn;
  final VoidCallback onDismiss;

  const _ErrorBanner({
    required this.message,
    required this.showSignInLink,
    required this.onSignIn,
    required this.onDismiss,
  });

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1), // intentional: optical icon baseline nudge
            child: PhosphorIcon(PhosphorIconsFill.warningCircle,
                size: 16, color: AppColors.umbrellaRed),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(message,
                    style: AppTextStyles.small(
                        color: AppColors.umbrellaRed)),
                if (showSignInLink) ...[
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: onSignIn,
                    child: Text('Sign in instead →',
                        style: AppTextStyles.small(
                                color: AppColors.umbrellaRed)
                            .copyWith(
                                decoration: TextDecoration.underline,
                                fontWeight: FontWeight.w600)),
                  ),
                ],
              ],
            ),
          ),
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

// ── Email confirmation sent screen ────────────────────────────────────────────

class _EmailSentScreen extends StatelessWidget {
  final String email;
  const _EmailSentScreen({required this.email});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  color: AppColors.greenTint,
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: AppColors.canopyGreen.withValues(alpha: 0.3)),
                ),
                child: const Center(
                  child: PhosphorIcon(
                      PhosphorIconsFill.envelopeSimple,
                      size: 36,
                      color: AppColors.canopyGreen),
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              Text('Request sent.',
                  style: AppTextStyles.h1(),
                  textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'We\'ve sent a confirmation to $email.\n\n'
                'An administrator will review your request and assign your role. '
                'You\'ll receive an email once you\'re approved.',
                style: AppTextStyles.body(color: AppColors.mist),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.h1),
              NdcButton(
                label: 'Back to sign in',
                variant: NdcButtonVariant.secondary,
                onPressed: () => context.go('/login'),
                icon: const PhosphorIcon(
                    PhosphorIconsRegular.arrowLeft,
                    size: 16,
                    color: AppColors.canopyGreen),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
