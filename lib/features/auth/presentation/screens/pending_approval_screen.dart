import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../../features/auth/application/auth_provider.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/theme/app_radii.dart';
import '../../../../shared/theme/app_spacing.dart';
import '../../../../shared/theme/app_text_styles.dart';
import '../../../../shared/widgets/brand_illustration.dart';
import '../../../../shared/widgets/ndc_button.dart';

class PendingApprovalScreen extends ConsumerWidget {
  const PendingApprovalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const BrandIllustration(
                      'assets/illustrations/empty_account_pending.png',
                      size: 180,
                    ),
                    const SizedBox(height: AppSpacing.xxl),

                    Text(
                      'Account pending',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.h1(),
                    ),
                    const SizedBox(height: AppSpacing.sm),

                    Text(
                      'Your account is created but not yet active. '
                      'Your administrator will assign your role and grant access.',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.body(color: AppColors.mist),
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    // Info card
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.base),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: AppRadii.borderMd,
                        border: Border.all(color: AppColors.hairline),
                      ),
                      child: Column(
                        children: [
                          _InfoRow(
                            icon: PhosphorIconsRegular.mapPin,
                            label: 'NDC Tema West Constituency',
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: AppSpacing.base),
                            child: Divider(height: 1, color: AppColors.hairline),
                          ),
                          _InfoRow(
                            icon: PhosphorIconsRegular.envelopeSimple,
                            label: 'Contact your constituency coordinator',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.h1),

                    // Re-runs the auth gate, which re-fetches the account
                    // fresh — an approved user gets in RIGHT HERE, without
                    // having to force-close and reopen the app.
                    NdcButton(
                      label: 'Check my status',
                      icon: const PhosphorIcon(
                        PhosphorIconsRegular.arrowsClockwise,
                        size: 18,
                        color: AppColors.surface,
                      ),
                      onPressed: () => context.go('/resolving'),
                    ),
                    const SizedBox(height: AppSpacing.sm),

                    NdcButton(
                      label: 'Sign out',
                      variant: NdcButtonVariant.ghost,
                      icon: const PhosphorIcon(
                        PhosphorIconsBold.signOut,
                        size: 18,
                        color: AppColors.mist,
                      ),
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
        PhosphorIcon(icon, size: 18, color: AppColors.canopyGreen),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: Text(label, style: AppTextStyles.body())),
      ],
    );
  }
}
