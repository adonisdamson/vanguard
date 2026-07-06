import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../../core/errors/app_error_mapper.dart';
import '../../../../features/auth/application/auth_provider.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/theme/app_radii.dart';
import '../../../../shared/theme/app_spacing.dart';
import '../../../../shared/theme/app_text_styles.dart';
import '../../../../shared/widgets/canopy_arc.dart';
import '../../../../shared/widgets/form_scaffold.dart';
import '../../../../shared/widgets/ndc_text_field.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  bool _loading = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref
          .read(authServiceProvider)
          .sendPasswordResetEmail(_emailCtrl.text.trim());
      if (mounted) setState(() => _sent = true);
    } catch (e, st) {
      if (mounted) {
        setState(() => _error = AppErrorMapper.forAuth(e, st) ?? 'Something went wrong. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FormScaffold(
      header: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const CanopyArc(height: 5),
            Container(
              color: AppColors.deepCanopy,
              padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.base, AppSpacing.screenH, AppSpacing.xl),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: const PhosphorIcon(
                      PhosphorIconsRegular.arrowLeft,
                      color: AppColors.surface,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.base),
                  Text(
                    'Reset password',
                    style: AppTextStyles.h2(color: AppColors.surface),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: _sent ? _SuccessState(email: _emailCtrl.text.trim()) : _FormState(
          formKey: _formKey,
          emailCtrl: _emailCtrl,
          loading: _loading,
          error: _error,
          onSubmit: _submit,
        ),
      ),
      actionBar: _sent
          ? FormActionBar(
              primaryLabel: 'Back to Sign In',
              onPrimary: () => context.go('/login'),
            )
          : FormActionBar(
              primaryLabel: 'Send Reset Link',
              onPrimary: _submit,
              loading: _loading,
              primaryIcon: const PhosphorIcon(PhosphorIconsFill.paperPlaneTilt,
                  size: 18, color: AppColors.surface),
            ),
    );
  }
}

class _FormState extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController emailCtrl;
  final bool loading;
  final String? error;
  final VoidCallback onSubmit;

  const _FormState({
    required this.formKey,
    required this.emailCtrl,
    required this.loading,
    required this.error,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          Text(
            'Enter your email address and we\'ll send you a link to reset your password.',
            style: AppTextStyles.bodyLarge(),
          ),
          const SizedBox(height: 28),

          if (error != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.redTint,
                borderRadius: AppRadii.borderSm,
                border: Border.all(color: AppColors.umbrellaRed.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const PhosphorIcon(PhosphorIconsRegular.warningCircle, size: 18, color: AppColors.umbrellaRed),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: Text(error!, style: AppTextStyles.body(color: AppColors.umbrellaRed))),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          NdcTextField(
            label: 'Email Address',
            hint: 'you@ndc.org.gh',
            icon: PhosphorIconsRegular.envelope,
            controller: emailCtrl,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => onSubmit(),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Email is required';
              if (!v.contains('@')) return 'Enter a valid email address';
              return null;
            },
          ),
        ],
      ),
    );
  }
}

class _SuccessState extends StatelessWidget {
  final String email;
  const _SuccessState({required this.email});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 40),
        Center(
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.greenTint,
              shape: BoxShape.circle,
            ),
            child: const PhosphorIcon(
              PhosphorIconsFill.checkCircle,
              size: 36,
              color: AppColors.canopyGreen,
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Check your inbox',
          textAlign: TextAlign.center,
          style: AppTextStyles.h2(),
        ),
        const SizedBox(height: 12),
        Text(
          'A password reset link has been sent to\n$email\n\nCheck your spam folder if you don\'t see it.',
          textAlign: TextAlign.center,
          style: AppTextStyles.body(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
