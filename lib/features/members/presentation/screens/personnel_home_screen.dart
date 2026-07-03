import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../../core/constants/assets.dart';
import '../../../../features/auth/application/auth_provider.dart';
import '../../../../features/auth/application/user_role_provider.dart';
import '../../application/member_providers.dart';
import '../../data/member_repository.dart';
import '../../application/offline_queue.dart';
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
    final statsAsync = ref.watch(myStatsProvider);

    // Flush offline queue silently on load
    if (OfflineQueue.hasItems) {
      OfflineQueue.flush().then((synced) {
        if (synced > 0) {
          ref.invalidate(myStatsProvider);
          ref.invalidate(mySubmissionsProvider);
        }
      });
    }

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
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.ndcGreen,
        foregroundColor: AppColors.ndcWhite,
        icon: const PhosphorIcon(PhosphorIconsFill.userPlus, size: 20),
        label: Text('Register', style: AppTextStyles.bodyMedium(color: AppColors.ndcWhite)),
        onPressed: () => context.push('/register-member'),
      ),
      body: RefreshIndicator(
        color: AppColors.ndcGreen,
        onRefresh: () async {
          ref.invalidate(appUserProvider);
          ref.invalidate(myStatsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
          children: [
            // Welcome card
            userAsync.when(
              data: (user) => _WelcomeCard(name: user?.fullName ?? 'Officer'),
              loading: () => const SkeletonLoader(height: 80, borderRadius: BorderRadius.all(Radius.circular(12))),
              error: (_, __) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 20),

            // Offline queue banner
            if (OfflineQueue.hasItems) _OfflineBanner(count: OfflineQueue.count),
            if (OfflineQueue.hasItems) const SizedBox(height: 16),

            // Stats row
            statsAsync.when(
              data: (stats) => _StatsRow(stats: stats),
              loading: () => Row(children: [
                for (int i = 0; i < 3; i++) ...[
                  const Expanded(child: SkeletonLoader(height: 70, borderRadius: BorderRadius.all(Radius.circular(10)))),
                  if (i < 2) const SizedBox(width: 10),
                ],
              ]),
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
              childAspectRatio: 1.5,
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
                  icon: PhosphorIconsFill.listChecks,
                  label: 'My Submissions',
                  color: AppColors.ndcBlack,
                  onTap: () => context.go('/my-submissions'),
                ),
                _ActionCard(
                  icon: PhosphorIconsFill.clockCounterClockwise,
                  label: 'Recent Records',
                  color: AppColors.textSecondary,
                  onTap: () => context.go('/my-submissions'),
                ),
                _ActionCard(
                  icon: PhosphorIconsFill.magnifyingGlass,
                  label: 'Search',
                  color: AppColors.statusPending,
                  onTap: () {},
                ),
              ],
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

class _StatsRow extends StatelessWidget {
  final MemberStats stats;
  const _StatsRow({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _StatChip(label: 'Total', value: '${stats.total}', color: AppColors.ndcGreen)),
        const SizedBox(width: 10),
        Expanded(child: _StatChip(label: 'Pending', value: '${stats.pending}', color: AppColors.statusPending)),
        const SizedBox(width: 10),
        Expanded(child: _StatChip(label: 'Approved', value: '${stats.active}', color: AppColors.statusActive)),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: AppTextStyles.h2(color: color)),
          Text(label, style: AppTextStyles.caption()),
        ],
      ),
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  final int count;
  const _OfflineBanner({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.statusPending.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.statusPending.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const PhosphorIcon(PhosphorIconsFill.cloudSlash, size: 18, color: AppColors.statusPending),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$count registration${count == 1 ? '' : 's'} saved offline. Connect to sync.',
              style: AppTextStyles.small(color: AppColors.statusPending),
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
