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

class HigherAuthorityHomeScreen extends ConsumerWidget {
  const HigherAuthorityHomeScreen({super.key});

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
            icon: const PhosphorIcon(PhosphorIconsRegular.export, color: AppColors.ndcWhite, size: 22),
            onPressed: () {},
            tooltip: 'Export',
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
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          userAsync.when(
            data: (user) => _DashboardHeader(name: user?.fullName ?? 'Coordinator'),
            loading: () => const SkeletonLoader(height: 90, borderRadius: BorderRadius.all(Radius.circular(12))),
            error: (_, __) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 24),

          // Stats row
          Row(
            children: [
              Expanded(child: _StatCard(label: 'Total Members', value: '—', icon: PhosphorIconsFill.users)),
              const SizedBox(width: 12),
              Expanded(child: _StatCard(label: 'Pending Review', value: '—', icon: PhosphorIconsFill.clock)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _StatCard(label: 'Active Today', value: '—', icon: PhosphorIconsFill.chartLine)),
              const SizedBox(width: 12),
              Expanded(child: _StatCard(label: 'Polling Stations', value: '—', icon: PhosphorIconsFill.mapPin)),
            ],
          ),
          const SizedBox(height: 24),

          Text('Actions', style: AppTextStyles.h3()),
          const SizedBox(height: 12),
          _MenuTile(
            icon: PhosphorIconsFill.listChecks,
            label: 'Review Queue',
            subtitle: 'Pending member approvals',
            onTap: () {},
          ),
          _MenuTile(
            icon: PhosphorIconsFill.users,
            label: 'Member Directory',
            subtitle: 'Browse and search all members',
            onTap: () => context.push('/members'),
          ),
          _MenuTile(
            icon: PhosphorIconsFill.download,
            label: 'Export Register',
            subtitle: 'Download CSV of member list',
            onTap: () {},
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

class _DashboardHeader extends StatelessWidget {
  final String name;
  const _DashboardHeader({required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.ndcGreen, AppColors.greenMid],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Dashboard', style: AppTextStyles.small(color: AppColors.ndcWhite.withValues(alpha: 0.8))),
          const SizedBox(height: 4),
          Text('Welcome, $name', style: AppTextStyles.h2(color: AppColors.ndcWhite)),
          const SizedBox(height: 4),
          Text('Tema West Constituency', style: AppTextStyles.small(color: AppColors.ndcWhite.withValues(alpha: 0.75))),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatCard({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PhosphorIcon(icon, size: 20, color: AppColors.ndcGreen),
          const SizedBox(height: 8),
          Text(value, style: AppTextStyles.h2()),
          Text(label, style: AppTextStyles.caption()),
        ],
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _MenuTile({
    required this.icon,
    required this.label,
    required this.subtitle,
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
        trailing: const PhosphorIcon(PhosphorIconsRegular.caretRight, size: 16, color: AppColors.textMuted),
      ),
    );
  }
}
