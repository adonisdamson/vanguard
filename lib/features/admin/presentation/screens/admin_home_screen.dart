import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../../core/constants/assets.dart';
import '../../../../features/auth/application/auth_provider.dart';
import '../../../../features/auth/application/user_role_provider.dart';
import '../../../../features/dashboard/application/dashboard_providers.dart';
import '../../application/operator_providers.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/theme/app_radii.dart';
import '../../../../shared/theme/app_shadows.dart';
import '../../../../shared/theme/app_spacing.dart';
import '../../../../shared/theme/app_text_styles.dart';
import '../../../../shared/widgets/app_list_tile.dart';
import '../../../../shared/widgets/canopy_arc.dart';
import '../../../../shared/widgets/ndc_button.dart';
import '../../../../shared/widgets/section_header.dart';
import '../../../../shared/widgets/skeleton_loader.dart';
import '../../../../shared/widgets/stat_card.dart';

class AdminHomeScreen extends ConsumerWidget {
  const AdminHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(appUserProvider);
    final memberStatsAsync = ref.watch(dashboardStatsProvider);
    final operatorStatsAsync = ref.watch(operatorStatsProvider);

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        backgroundColor: AppColors.deepCanopy,
        elevation: 0,
        titleSpacing: AppSpacing.base,
        title: Row(
          children: [
            // Circular logo mark
            Container(
              width: 30,
              height: 30,
              decoration: const BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
              ),
              child: Padding(
                padding: const EdgeInsets.all(5),
                child: Image.asset(Assets.ndcUmbrella),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text('VANGUARD', style: AppTextStyles.appBarTitle()),
            const SizedBox(width: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.umbrellaRed,
                borderRadius: AppRadii.borderPill,
              ),
              child: Text('ADMIN', style: AppTextStyles.badge()),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const PhosphorIcon(
              PhosphorIconsRegular.arrowCounterClockwise,
              color: AppColors.surface,
              size: 20,
            ),
            onPressed: () {
              ref.invalidate(dashboardStatsProvider);
              ref.invalidate(operatorStatsProvider);
            },
            tooltip: 'Refresh',
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(4),
          child: CanopyStripe(height: 4),
        ),
      ),
      body: RefreshIndicator(
        color: AppColors.canopyGreen,
        onRefresh: () async {
          ref.invalidate(dashboardStatsProvider);
          ref.invalidate(operatorStatsProvider);
          ref.invalidate(appUserProvider);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenH, AppSpacing.xl,
            AppSpacing.screenH, AppSpacing.h1,
          ),
          children: [
            // Profile card
            userAsync.when(
              data: (user) => _ProfileCard(name: user?.fullName ?? 'Administrator'),
              loading: () => const SkeletonLoader(
                height: 88,
                borderRadius: AppRadii.borderMd,
              ),
              error: (_, __) => const SizedBox.shrink(),
            ),

            // Member stats
            const SectionHeader(title: 'Member registry'),
            memberStatsAsync.when(
              data: (stats) => Row(children: [
                Expanded(
                  child: StatCard(
                    icon: PhosphorIconsRegular.users,
                    value: '${stats.total}',
                    label: 'Total',
                    iconColor: AppColors.canopyGreen,
                    iconBg: AppColors.greenTint,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: StatCard(
                    icon: PhosphorIconsRegular.clock,
                    value: '${stats.pending}',
                    label: 'Pending',
                    iconColor: AppColors.statusPending,
                    iconBg: AppColors.amberTint,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: StatCard(
                    icon: PhosphorIconsRegular.checkCircle,
                    value: '${stats.active}',
                    label: 'Active',
                    iconColor: AppColors.canopyGreen,
                    iconBg: AppColors.greenTint,
                  ),
                ),
              ]),
              loading: () => Row(children: [
                for (var i = 0; i < 3; i++) ...[
                  if (i > 0) const SizedBox(width: AppSpacing.sm),
                  const Expanded(child: SkeletonLoader(height: 96, borderRadius: AppRadii.borderMd)),
                ]
              ]),
              error: (_, __) => const SizedBox.shrink(),
            ),

            // Operator stats
            const SectionHeader(title: 'Operators'),
            operatorStatsAsync.when(
              data: (counts) => Row(children: [
                Expanded(
                  child: StatCard(
                    icon: PhosphorIconsRegular.usersThree,
                    value: '${counts['total'] ?? 0}',
                    label: 'Total',
                    iconColor: AppColors.ink,
                    iconBg: AppColors.fillMuted,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: StatCard(
                    icon: PhosphorIconsRegular.shieldStar,
                    value: '${counts['admin'] ?? 0}',
                    label: 'Admin',
                    iconColor: AppColors.umbrellaRed,
                    iconBg: AppColors.redTint,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: StatCard(
                    icon: PhosphorIconsRegular.identificationCard,
                    value: '${counts['personnel'] ?? 0}',
                    label: 'Personnel',
                    iconColor: AppColors.canopyGreen,
                    iconBg: AppColors.greenTint,
                  ),
                ),
              ]),
              loading: () => Row(children: [
                for (var i = 0; i < 3; i++) ...[
                  if (i > 0) const SizedBox(width: AppSpacing.sm),
                  const Expanded(child: SkeletonLoader(height: 96, borderRadius: AppRadii.borderMd)),
                ]
              ]),
              error: (_, __) => const SizedBox.shrink(),
            ),

            // System management
            const SectionHeader(title: 'System management'),

            AppListTile(
              leadingIcon: PhosphorIconsRegular.usersThree,
              title: 'Operator accounts',
              subtitle: 'Create and manage personnel & coordinators',
              onTap: () => context.push('/admin/operators'),
            ),
            AppListTile(
              leadingIcon: PhosphorIconsRegular.users,
              title: 'Member directory',
              subtitle: 'Full access to all member records',
              onTap: () => context.push('/member-directory'),
            ),
            AppListTile(
              leadingIcon: PhosphorIconsRegular.listChecks,
              title: 'Review queue',
              subtitle: 'Approve or reject pending registrations',
              trailing: memberStatsAsync.valueOrNull?.pending != null &&
                      memberStatsAsync.valueOrNull!.pending > 0
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: const BoxDecoration(
                        color: AppColors.statusPending,
                        borderRadius: AppRadii.borderPill,
                      ),
                      child: Text(
                        '${memberStatsAsync.valueOrNull!.pending}',
                        style: AppTextStyles.badge(color: AppColors.surface),
                      ),
                    )
                  : null,
              onTap: () => context.push('/review-queue'),
            ),
            AppListTile(
              leadingIcon: PhosphorIconsRegular.mapPin,
              title: 'Lookup tables',
              subtitle: 'Regions, districts, constituencies, polling stations',
              onTap: () => context.push('/admin/lookups'),
            ),
            AppListTile(
              leadingIcon: PhosphorIconsRegular.scroll,
              title: 'Audit log',
              subtitle: 'Full system activity and change history',
              onTap: () => context.push('/admin/audit'),
            ),
            AppListTile(
              leadingIcon: PhosphorIconsRegular.download,
              title: 'Data exports',
              subtitle: 'Export member data as CSV',
              onTap: () => context.push('/member-directory'),
            ),

            const SizedBox(height: AppSpacing.xl),

            NdcButton(
              label: 'Sign out',
              variant: NdcButtonVariant.ghost,
              icon: const PhosphorIcon(
                PhosphorIconsRegular.signOut,
                size: 16,
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
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final String name;
  const _ProfileCard({required this.name});

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
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.umbrellaRed.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: const PhosphorIcon(
              PhosphorIconsFill.shieldStar,
              color: AppColors.umbrellaRed,
              size: 26,
            ),
          ),
          const SizedBox(width: AppSpacing.base),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: AppTextStyles.h3(color: AppColors.surface),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'System administrator',
                  style: AppTextStyles.label(color: AppColors.surface.withValues(alpha: 0.65)),
                ),
                Text(
                  'Tema West Constituency',
                  style: AppTextStyles.caption(color: AppColors.surface.withValues(alpha: 0.45)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
