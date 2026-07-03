import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../../core/constants/assets.dart';
import '../../../../features/auth/application/auth_provider.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/theme/app_text_styles.dart';
import '../../../../shared/widgets/ndc_button.dart';
import '../../../../shared/widgets/ndc_flag_stripe.dart';

class PendingApprovalScreen extends ConsumerWidget {
  const PendingApprovalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const NdcFlagStripe(height: 5),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Umbrella in a muted circle
                    Container(
                      width: 88,
                      height: 88,
                      decoration: const BoxDecoration(
                        color: AppColors.surfaceVariant,
                        shape: BoxShape.circle,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Image.asset(Assets.ndcUmbrella),
                      ),
                    ),
                    const SizedBox(height: 28),

                    Text(
                      'Account Pending',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.h1(),
                    ),
                    const SizedBox(height: 12),

                    Text(
                      'Your account has been created but is not yet active. '
                      'Please contact your administrator to get access.',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodyLarge(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 32),

                    // Info card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        children: [
                          _InfoRow(
                            icon: PhosphorIconsFill.phoneCall,
                            label: 'NDC Tema West Constituency',
                          ),
                          const Divider(height: 20),
                          _InfoRow(
                            icon: PhosphorIconsFill.envelopeSimple,
                            label: 'Contact your constituency coordinator',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),

                    NdcButton(
                      label: 'Sign Out',
                      variant: NdcButtonVariant.secondary,
                      icon: const PhosphorIcon(PhosphorIconsFill.signOut, size: 18, color: AppColors.ndcGreen),
                      onPressed: () async {
                        await ref.read(authServiceProvider).signOut();
                        if (context.mounted) context.go('/login');
                      },
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

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        PhosphorIcon(icon, size: 18, color: AppColors.ndcGreen),
        const SizedBox(width: 12),
        Expanded(
          child: Text(label, style: AppTextStyles.body()),
        ),
      ],
    );
  }
}
