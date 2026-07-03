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

class AdminHomeScreen extends ConsumerWidget {
  const AdminHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(appUserProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.ndcBlack,
        elevation: 0,
        title: Row(
          children: [
            Image.asset(Assets.ndcUmbrella, width: 28, height: 28),
            const SizedBox(width: 10),
            Text('VANGUARD', style: AppTextStyles.appBarTitle()),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.ndcRed,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text('ADMIN', style: AppTextStyles.badge()),
            ),
          ],
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(4),
          child: NdcFlagStripe(height: 4),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          userAsync.when(
            data: (user) => _AdminHeader(name: user?.fullName ?? 'Administrator'),
            loading: () => const SkeletonLoader(height: 80, borderRadius: BorderRadius.all(Radius.circular(12))),
            error: (_, __) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 24),

          Text('System Management', style: AppTextStyles.h3()),
          const SizedBox(height: 12),

          _AdminMenuTile(
            icon: PhosphorIconsFill.usersThree,
            label: 'Operator Accounts',
            subtitle: 'Create and manage personnel/coordinators',
            badge: null,
            onTap: () {},
          ),
          _AdminMenuTile(
            icon: PhosphorIconsFill.users,
            label: 'Member Registry',
            subtitle: 'Full access to all member records',
            badge: null,
            onTap: () => context.push('/members'),
          ),
          _AdminMenuTile(
            icon: PhosphorIconsFill.mapPin,
            label: 'Lookup Tables',
            subtitle: 'Polling stations, districts, constituencies',
            badge: null,
            onTap: () {},
          ),
          _AdminMenuTile(
            icon: PhosphorIconsFill.scroll,
            label: 'Audit Log',
            subtitle: 'System activity and change history',
            badge: null,
            onTap: () {},
          ),
          _AdminMenuTile(
            icon: PhosphorIconsFill.download,
            label: 'Data Exports',
            subtitle: 'Export member data as CSV',
            badge: null,
            onTap: () {},
          ),
          const SizedBox(height: 24),

          // Danger zone
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.redLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.ndcRed.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const PhosphorIcon(PhosphorIconsFill.warning, size: 18, color: AppColors.ndcRed),
                    const SizedBox(width: 8),
                    Text('Danger Zone', style: AppTextStyles.h3(color: AppColors.ndcRed)),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Destructive actions require confirmation and are permanently logged.',
                  style: AppTextStyles.small(color: AppColors.ndcRed),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

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
    );
  }
}

class _AdminHeader extends StatelessWidget {
  final String name;
  const _AdminHeader({required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.ndcBlack,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.ndcRed.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const PhosphorIcon(PhosphorIconsFill.shieldStar, color: AppColors.ndcRed, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: AppTextStyles.h3(color: AppColors.ndcWhite)),
                Text('System Administrator', style: AppTextStyles.small(color: AppColors.ndcWhite.withValues(alpha: 0.6))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminMenuTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final String? badge;
  final VoidCallback onTap;

  const _AdminMenuTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.badge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: onTap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: AppColors.border),
        ),
        tileColor: AppColors.surface,
        leading: PhosphorIcon(icon, color: AppColors.ndcGreen, size: 22),
        title: Text(label, style: AppTextStyles.bodyMedium()),
        subtitle: Text(subtitle, style: AppTextStyles.small()),
        trailing: badge != null
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.ndcRed,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(badge!, style: AppTextStyles.badge()),
              )
            : const PhosphorIcon(PhosphorIconsRegular.caretRight, size: 16, color: AppColors.textMuted),
      ),
    );
  }
}
