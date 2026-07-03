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
import '../../../../shared/widgets/ndc_flag_stripe.dart';
import '../../../../shared/widgets/skeleton_loader.dart';

class PersonnelHomeScreen extends ConsumerWidget {
  const PersonnelHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(appUserProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.ndcGreen,
        elevation: 0,
        title: Row(
          children: [
            Image.asset(Assets.ndcUmbrella, width: 28, height: 28),
            const SizedBox(width: 10),
            Text('VANGUARD', style: AppTextStyles.appBarTitle()),
          ],
        ),
        actions: [
          IconButton(
            icon: const PhosphorIcon(PhosphorIconsRegular.bell, color: AppColors.ndcWhite, size: 22),
            onPressed: () {},
          ),
          IconButton(
            icon: const PhosphorIcon(PhosphorIconsRegular.userCircle, color: AppColors.ndcWhite, size: 22),
            onPressed: () {},
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(4),
          child: NdcFlagStripe(height: 4),
        ),
      ),
      body: RefreshIndicator(
        color: AppColors.ndcGreen,
        onRefresh: () async {
          ref.invalidate(appUserProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Welcome card
            userAsync.when(
              data: (user) => _WelcomeCard(name: user?.fullName ?? 'Officer'),
              loading: () => const SkeletonLoader(height: 80, borderRadius: BorderRadius.all(Radius.circular(12))),
              error: (_, __) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 24),

            // Quick actions
            Text('Quick Actions', style: AppTextStyles.h3()),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _ActionCard(
                  icon: PhosphorIconsFill.userPlus,
                  label: 'Register Member',
                  color: AppColors.ndcGreen,
                  onTap: () => context.push('/register-member'),
                ),
                _ActionCard(
                  icon: PhosphorIconsFill.magnifyingGlass,
                  label: 'Find Member',
                  color: AppColors.ndcBlack,
                  onTap: () => context.push('/members'),
                ),
                _ActionCard(
                  icon: PhosphorIconsFill.clockCounterClockwise,
                  label: 'Recent Records',
                  color: AppColors.textSecondary,
                  onTap: () {},
                ),
                _ActionCard(
                  icon: PhosphorIconsFill.qrCode,
                  label: 'Scan ID',
                  color: AppColors.statusPending,
                  onTap: () {},
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Sign out (temporary, will move to profile)
            NdcButton(
              label: 'Sign Out',
              variant: NdcButtonVariant.ghost,
              icon: const PhosphorIcon(PhosphorIconsFill.signOut, size: 16, color: AppColors.textSecondary),
              onPressed: () async {
                await ref.read(authServiceProvider).signOut();
                if (context.mounted) context.go('/login');
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _WelcomeCard extends StatelessWidget {
  final String name;
  const _WelcomeCard({required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: AppColors.greenLight,
              shape: BoxShape.circle,
            ),
            child: const PhosphorIcon(PhosphorIconsFill.userCircle, color: AppColors.ndcGreen, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Good day, $name', style: AppTextStyles.h3()),
                Text('Tema West • Personnel', style: AppTextStyles.small()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            PhosphorIcon(icon, color: color, size: 26),
            Text(label, style: AppTextStyles.bodyMedium()),
          ],
        ),
      ),
    );
  }
}
