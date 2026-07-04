import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../../core/constants/assets.dart';
import '../../../../features/auth/application/auth_provider.dart';
import '../../../../features/auth/application/user_role_provider.dart';
import '../../application/member_providers.dart';
import '../../application/offline_queue.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/theme/app_radii.dart';
import '../../../../shared/theme/app_shadows.dart';
import '../../../../shared/theme/app_spacing.dart';
import '../../../../shared/theme/app_text_styles.dart';
import '../../../../shared/widgets/canopy_arc.dart';
import '../../../../shared/widgets/ndc_button.dart';
import '../../../../shared/widgets/stat_card.dart';
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
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        backgroundColor: AppColors.deepCanopy,
        elevation: 0,
        title: Row(
          children: [
            Container(
              width: 30, height: 30,
              decoration: const BoxDecoration(color: AppColors.surface, shape: BoxShape.circle),
              child: Padding(
                padding: const EdgeInsets.all(5),
                child: Image.asset(Assets.ndcUmbrella),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text('VANGUARD', style: AppTextStyles.appBarTitle()),
          ],
        ),
        actions: [
          IconButton(
            icon: const PhosphorIcon(PhosphorIconsRegular.bell, color: AppColors.surface, size: 22),
            onPressed: () {},
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(4),
          child: CanopyStripe(height: 4),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.canopyGreen,
        foregroundColor: AppColors.surface,
        icon: const PhosphorIcon(PhosphorIconsFill.userPlus, size: 20),
        label: Text('Register', style: AppTextStyles.bodyMedium(color: AppColors.ndcWhite)),
        onPressed: () => context.push('/register-member'),
      ),
      body: RefreshIndicator(
        color: AppColors.canopyGreen,
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
              data: (stats) => Row(children: [
                Expanded(child: StatCard(icon: PhosphorIconsRegular.users, value: '${stats.total}', label: 'Total', iconColor: AppColors.canopyGreen, iconBg: AppColors.greenTint)),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: StatCard(icon: PhosphorIconsRegular.clock, value: '${stats.pending}', label: 'Pending', iconColor: AppColors.statusPending, iconBg: AppColors.amberTint)),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: StatCard(icon: PhosphorIconsRegular.checkCircle, value: '${stats.active}', label: 'Approved', iconColor: AppColors.statusActive, iconBg: AppColors.greenTint)),
              ]),
              loading: () => Row(children: [
                for (int i = 0; i < 3; i++) ...[
                  const Expanded(child: SkeletonLoader(height: 96, borderRadius: AppRadii.borderMd)),
                  if (i < 2) const SizedBox(width: AppSpacing.sm),
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
                  color: AppColors.canopyGreen,
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
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        color: AppColors.deepCanopy,
        borderRadius: AppRadii.borderMd,
        boxShadow: AppShadows.e1,
      ),
      child: Row(
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: AppColors.umbrellaRed.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const PhosphorIcon(PhosphorIconsFill.userCircle, color: AppColors.surface, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Good day, $name', style: AppTextStyles.h3(color: AppColors.surface), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text('Tema West • Personnel', style: AppTextStyles.small(color: AppColors.surface.withValues(alpha: 0.65))),
              ],
            ),
          ),
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
        padding: const EdgeInsets.all(AppSpacing.base),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadii.borderMd,
          boxShadow: AppShadows.e1,
          border: Border.all(color: AppColors.hairline),
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
