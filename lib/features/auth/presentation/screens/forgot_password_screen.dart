import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../../features/auth/application/auth_provider.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/theme/app_text_styles.dart';
import '../../../../shared/widgets/ndc_button.dart';
import '../../../../shared/widgets/ndc_flag_stripe.dart';
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
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Could not send reset email. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const NdcFlagStripe(height: 5),
            // Compact green header
            Container(
              color: AppColors.ndcGreen,
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: const PhosphorIcon(
                      PhosphorIconsRegular.arrowLeft,
                      color: AppColors.ndcWhite,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'Reset Password',
                    style: AppTextStyles.h2(color: AppColors.ndcWhite),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: _sent ? _SuccessState(email: _emailCtrl.text.trim()) : _FormState(
                  formKey: _formKey,
                  emailCtrl: _emailCtrl,
                  loading: _loading,
                  error: _error,
                  onSubmit: _submit,
                ),
              ),
            ),
          ],
        ),
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
                color: AppColors.redLight,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.ndcRed.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const PhosphorIcon(PhosphorIconsFill.warningCircle, size: 18, color: AppColors.ndcRed),
                  const SizedBox(width: 10),
                  Expanded(child: Text(error!, style: AppTextStyles.body(color: AppColors.ndcRed))),
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
          const SizedBox(height: 24),

          NdcButton(
            label: 'Send Reset Link',
            onPressed: onSubmit,
            loading: loading,
            icon: const PhosphorIcon(PhosphorIconsFill.paperPlaneTilt, size: 18, color: AppColors.ndcWhite),
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
              color: AppColors.greenLight,
              shape: BoxShape.circle,
            ),
            child: const PhosphorIcon(
              PhosphorIconsFill.checkCircle,
              size: 36,
              color: AppColors.ndcGreen,
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
        const SizedBox(height: 36),
        NdcButton(
          label: 'Back to Sign In',
          variant: NdcButtonVariant.secondary,
          onPressed: () => context.go('/login'),
        ),
      ],
    );
  }
}
