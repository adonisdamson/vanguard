import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../../core/constants/assets.dart';
import '../../../../features/auth/application/auth_provider.dart';
import '../../../../features/auth/application/user_role_provider.dart';
import '../../application/dashboard_providers.dart';
import '../../data/dashboard_repository.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/theme/app_radii.dart';
import '../../../../shared/theme/app_shadows.dart';
import '../../../../shared/theme/app_spacing.dart';
import '../../../../shared/theme/app_text_styles.dart';
import '../../../../shared/widgets/app_list_tile.dart';
import '../../../../shared/widgets/canopy_arc.dart';
import '../../../../shared/widgets/ndc_button.dart';
import '../../../../shared/widgets/section_header.dart';
import '../../../../shared/widgets/stat_card.dart';
import '../../../../shared/widgets/skeleton_loader.dart';

class HigherAuthorityHomeScreen extends ConsumerWidget {
  const HigherAuthorityHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(appUserProvider);
    final statsAsync = ref.watch(dashboardStatsProvider);

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        backgroundColor: AppColors.deepCanopy,
        elevation: 0,
        titleSpacing: AppSpacing.base,
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
            icon: const PhosphorIcon(PhosphorIconsRegular.arrowCounterClockwise, color: AppColors.surface, size: 20),
            onPressed: () => ref.invalidate(dashboardStatsProvider),
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
          ref.invalidate(appUserProvider);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.xl, AppSpacing.screenH, AppSpacing.h1),
          children: [
            // Welcome header
            userAsync.when(
              data: (user) => _DashboardHeader(name: user?.fullName ?? 'Coordinator'),
              loading: () => const SkeletonLoader(height: 90, borderRadius: AppRadii.borderMd),
              error: (_, __) => const SizedBox.shrink(),
            ),
            const SizedBox(height: AppSpacing.base),

            // Stats grid
            const SectionHeader(title: 'Registry overview'),
            statsAsync.when(
              data: (stats) => Column(children: [
                Row(children: [
                  Expanded(child: StatCard(icon: PhosphorIconsRegular.users, value: '${stats.total}', label: 'Total', iconColor: AppColors.canopyGreen, iconBg: AppColors.greenTint)),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: StatCard(icon: PhosphorIconsRegular.clock, value: '${stats.pending}', label: 'Pending', iconColor: AppColors.statusPending, iconBg: AppColors.amberTint)),
                ]),
                const SizedBox(height: AppSpacing.sm),
                Row(children: [
                  Expanded(child: StatCard(icon: PhosphorIconsRegular.checkCircle, value: '${stats.active}', label: 'Approved', iconColor: AppColors.statusActive, iconBg: AppColors.greenTint)),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: StatCard(icon: PhosphorIconsRegular.calendarBlank, value: '${stats.thisMonth}', label: 'This month', iconColor: AppColors.mist, iconBg: AppColors.fillMuted)),
                ]),
              ]),
              loading: () => _StatsGridSkeleton(),
              error: (_, __) => _ErrorCard(onRetry: () => ref.invalidate(dashboardStatsProvider)),
            ),

            // Trend chart
            statsAsync.when(
              data: (stats) => stats.trend.isNotEmpty ? Padding(
                padding: const EdgeInsets.only(top: AppSpacing.base),
                child: _TrendChart(trend: stats.trend),
              ) : const SizedBox.shrink(),
              loading: () => const Padding(
                padding: EdgeInsets.only(top: AppSpacing.base),
                child: SkeletonLoader(height: 180, borderRadius: AppRadii.borderMd),
              ),
              error: (_, __) => const SizedBox.shrink(),
            ),

            // Action menu
            const SectionHeader(title: 'Actions'),
            AppListTile(
              leadingIcon: PhosphorIconsRegular.listChecks,
              title: 'Review queue',
              subtitle: 'Approve or reject pending registrations',
              trailing: statsAsync.valueOrNull?.pending != null && statsAsync.valueOrNull!.pending > 0
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: const BoxDecoration(color: AppColors.statusPending, borderRadius: AppRadii.borderPill),
                      child: Text('${statsAsync.valueOrNull!.pending}', style: AppTextStyles.badge(color: AppColors.surface)),
                    )
                  : null,
              onTap: () => context.push('/review-queue'),
            ),
            AppListTile(
              leadingIcon: PhosphorIconsRegular.users,
              title: 'Member directory',
              subtitle: 'Search and browse all members',
              onTap: () => context.push('/member-directory'),
            ),
            AppListTile(
              leadingIcon: PhosphorIconsRegular.download,
              title: 'Export register',
              subtitle: 'Download member data as CSV',
              onTap: () => context.push('/member-directory'),
            ),
            const SizedBox(height: AppSpacing.xl),

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

class _DashboardHeader extends StatelessWidget {
  final String name;
  const _DashboardHeader({required this.name});

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
            width: 52, height: 52,
            decoration: BoxDecoration(
              color: AppColors.canopyGreen.withValues(alpha: 0.25),
              shape: BoxShape.circle,
            ),
            child: const PhosphorIcon(PhosphorIconsFill.userCircleCheck, color: AppColors.surface, size: 26),
          ),
          const SizedBox(width: AppSpacing.base),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Welcome, $name', style: AppTextStyles.h3(color: AppColors.surface), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text('Higher authority', style: AppTextStyles.label(color: AppColors.surface.withValues(alpha: 0.65))),
                Text('Tema West Constituency', style: AppTextStyles.caption(color: AppColors.surface.withValues(alpha: 0.45))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TrendChart extends StatefulWidget {
  final List<MonthlyCount> trend;
  const _TrendChart({required this.trend});

  @override
  State<_TrendChart> createState() => _TrendChartState();
}

class _TrendChartState extends State<_TrendChart> {
  int? _touchedIndex;

  @override
  Widget build(BuildContext context) {
    final maxY = widget.trend.fold(0, (m, e) => e.count > m ? e.count : m).toDouble();
    final adjustedMax = maxY < 10 ? 10.0 : (maxY * 1.3).ceilToDouble();

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.borderMd,
        boxShadow: AppShadows.e1,
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const PhosphorIcon(PhosphorIconsRegular.chartBar, size: 16, color: AppColors.canopyGreen),
              const SizedBox(width: 8),
              Text('Registrations — Last 6 Months', style: AppTextStyles.h3()),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 160,
            child: BarChart(
              BarChartData(
                maxY: adjustedMax,
                minY: 0,
                barTouchData: BarTouchData(
                  touchCallback: (event, response) {
                    if (event is FlTapUpEvent || event is FlLongPressEnd) {
                      setState(() => _touchedIndex = null);
                    } else if (response?.spot != null) {
                      setState(() => _touchedIndex = response!.spot!.touchedBarGroupIndex);
                    }
                  },
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, gI, rod, rI) => BarTooltipItem(
                      '${rod.toY.toInt()}',
                      AppTextStyles.badge(color: AppColors.ndcWhite),
                    ),
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final i = value.toInt();
                        if (i < 0 || i >= widget.trend.length) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(widget.trend[i].month, style: AppTextStyles.caption()),
                        );
                      },
                      reservedSize: 28,
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 36,
                      getTitlesWidget: (value, _) => Text(
                        value.toInt().toString(),
                        style: AppTextStyles.caption(),
                      ),
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: adjustedMax / 4,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: AppColors.divider,
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(widget.trend.length, (i) {
                  final touched = _touchedIndex == i;
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: widget.trend[i].count.toDouble(),
                        width: 18,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                        color: touched ? AppColors.canopyGreen : AppColors.canopyGreen.withValues(alpha: 0.7),
                        backDrawRodData: BackgroundBarChartRodData(
                          show: true,
                          toY: adjustedMax,
                          color: AppColors.surfaceVariant,
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsGridSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(children: [
          const Expanded(child: SkeletonLoader(height: 96, borderRadius: AppRadii.borderMd)),
          const SizedBox(width: AppSpacing.sm),
          const Expanded(child: SkeletonLoader(height: 96, borderRadius: AppRadii.borderMd)),
        ]),
        const SizedBox(height: AppSpacing.sm),
        Row(children: [
          const Expanded(child: SkeletonLoader(height: 96, borderRadius: AppRadii.borderMd)),
          const SizedBox(width: AppSpacing.sm),
          const Expanded(child: SkeletonLoader(height: 96, borderRadius: AppRadii.borderMd)),
        ]),
      ],
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorCard({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.redLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.ndcRed.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const PhosphorIcon(PhosphorIconsFill.warningCircle, size: 20, color: AppColors.ndcRed),
          const SizedBox(width: 12),
          Expanded(child: Text('Could not load stats.', style: AppTextStyles.body())),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

