import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../../core/constants/assets.dart';
import '../../application/auth_provider.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/theme/app_radii.dart';
import '../../../../shared/theme/app_spacing.dart';
import '../../../../shared/theme/app_text_styles.dart';
import '../../../../shared/widgets/canopy_arc.dart';
import '../../../../shared/widgets/ndc_button.dart';
import '../../../../shared/widgets/ndc_text_field.dart';

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl     = TextEditingController();
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl  = TextEditingController();

  bool _loading = false;
  String? _error;
  String? _requestedRole;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      await ref.read(authServiceProvider).signUp(
        fullName:      _nameCtrl.text.trim(),
        email:         _emailCtrl.text.trim(),
        password:      _passwordCtrl.text,
        requestedRole: _requestedRole,
      );
      if (mounted) context.go('/pending-approval');
    } catch (e) {
      setState(() => _error = _humanize(e.toString()));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _humanize(String raw) {
    if (raw.contains('already registered') || raw.contains('already been registered')) {
      return 'An account with this email already exists. Try signing in.';
    }
    if (raw.contains('Password should be')) return 'Password must be at least 6 characters.';
    if (raw.contains('network') || raw.contains('SocketException')) {
      return 'No internet connection. Please check your network.';
    }
    return 'Something went wrong. Please try again.';
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
              const CanopyArc(height: 5),

              // Header
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
                      'Request access.',
                      style: AppTextStyles.displayLarge(color: AppColors.surface),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Create your account. An administrator will activate it and assign your role.',
                      style: AppTextStyles.bodyLarge(
                        color: AppColors.surface.withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                ),
              ),

              // Form
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_error != null) ...[
                        _ErrorBanner(message: _error!),
                        const SizedBox(height: 20),
                      ],

                      NdcTextField(
                        label: 'Full Name *',
                        hint: 'Kwame Mensah',
                        icon: PhosphorIconsRegular.person,
                        controller: _nameCtrl,
                        textInputAction: TextInputAction.next,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Full name is required';
                          if (v.trim().split(' ').length < 2) return 'Enter your first and last name';
                          return null;
                        },
                        onChanged: (_) {},
                      ),
                      const SizedBox(height: AppSpacing.base),

                      NdcTextField(
                        label: 'Email Address *',
                        hint: 'you@ndc.org.gh',
                        icon: PhosphorIconsRegular.envelope,
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Email is required';
                          if (!v.contains('@')) return 'Enter a valid email address';
                          return null;
                        },
                        onChanged: (_) {},
                      ),
                      const SizedBox(height: AppSpacing.base),

                      NdcTextField(
                        label: 'Password *',
                        hint: '••••••••',
                        icon: PhosphorIconsRegular.lock,
                        controller: _passwordCtrl,
                        obscureText: true,
                        textInputAction: TextInputAction.next,
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Password is required';
                          if (v.length < 6) return 'Password must be at least 6 characters';
                          return null;
                        },
                        onChanged: (_) {},
                      ),
                      const SizedBox(height: AppSpacing.base),

                      NdcTextField(
                        label: 'Confirm Password *',
                        hint: '••••••••',
                        icon: PhosphorIconsRegular.lockKey,
                        controller: _confirmCtrl,
                        obscureText: true,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _submit(),
                        validator: (v) {
                          if (v != _passwordCtrl.text) return 'Passwords do not match';
                          return null;
                        },
                        onChanged: (_) {},
                      ),
                      const SizedBox(height: AppSpacing.lg),

                      // Optional role hint
                      _RoleHintPicker(
                        value: _requestedRole,
                        onChanged: (v) => setState(() => _requestedRole = v),
                      ),
                      const SizedBox(height: AppSpacing.lg),

                      NdcButton(
                        label: 'Request Access',
                        onPressed: _submit,
                        loading: _loading,
                        icon: const PhosphorIcon(
                          PhosphorIconsFill.paperPlaneRight,
                          size: 18,
                          color: AppColors.surface,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),

                      // Back to login
                      Row(
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

// ── Role hint picker ──────────────────────────────────────────────────────────

class _RoleHintPicker extends StatelessWidget {
  final String? value;
  final void Function(String?) onChanged;
  const _RoleHintPicker({required this.value, required this.onChanged});

  static const _options = [
    ('personnel',       'Personnel',         'Register and manage members'),
    ('higher_authority','Coordinator',       'Review registrations & view reports'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Intended role (optional)', style: AppTextStyles.label()),
        const SizedBox(height: 4),
        Text(
          'Helps your admin assign the right role quickly.',
          style: AppTextStyles.small(),
        ),
        const SizedBox(height: 10),
        ..._options.map((opt) {
          final (roleKey, label, desc) = opt;
          final selected = value == roleKey;
          return GestureDetector(
            onTap: () => onChanged(selected ? null : roleKey),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.only(bottom: AppSpacing.sm),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.base,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: selected ? AppColors.greenTint : AppColors.surface,
                borderRadius: AppRadii.borderMd,
                border: Border.all(
                  color: selected ? AppColors.canopyGreen : AppColors.hairline,
                  width: selected ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 20, height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected ? AppColors.canopyGreen : AppColors.fillMuted,
                      border: Border.all(
                        color: selected ? AppColors.canopyGreen : AppColors.hairline,
                      ),
                    ),
                    child: selected
                        ? const Icon(Icons.check, size: 12, color: AppColors.surface)
                        : null,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label, style: AppTextStyles.title()),
                        Text(desc, style: AppTextStyles.small()),
                      ],
                    ),
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

// ── Error banner ──────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.redTint,
        borderRadius: AppRadii.borderSm,
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
            child: Text(message, style: AppTextStyles.body(color: AppColors.umbrellaRed)),
          ),
        ],
      ),
    );
  }
}
