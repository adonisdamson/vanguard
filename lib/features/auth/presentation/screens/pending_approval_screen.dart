import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../../core/constants/assets.dart';
import '../../../../features/auth/application/auth_provider.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/theme/app_radii.dart';
import '../../../../shared/theme/app_spacing.dart';
import '../../../../shared/theme/app_text_styles.dart';
import '../../../../shared/widgets/canopy_arc.dart';
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
            const CanopyArc(height: 5),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Umbrella in a white circle with soft shadow
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.hairline, width: 1),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x0C12211A),
                            blurRadius: 12,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Image.asset(Assets.ndcUmbrella),
                      ),
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

                    NdcButton(
                      label: 'Sign out',
                      variant: NdcButtonVariant.ghost,
                      icon: const PhosphorIcon(
                        PhosphorIconsRegular.signOut,
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
