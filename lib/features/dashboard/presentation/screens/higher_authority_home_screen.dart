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
import '../../../../shared/theme/app_text_styles.dart';
import '../../../../shared/widgets/ndc_button.dart';
import '../../../../shared/widgets/ndc_flag_stripe.dart';
import '../../../../shared/widgets/skeleton_loader.dart';

class HigherAuthorityHomeScreen extends ConsumerWidget {
  const HigherAuthorityHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(appUserProvider);
    final statsAsync = ref.watch(dashboardStatsProvider);

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
            icon: const PhosphorIcon(PhosphorIconsRegular.arrowCounterClockwise, color: AppColors.ndcWhite, size: 20),
            onPressed: () => ref.invalidate(dashboardStatsProvider),
            tooltip: 'Refresh',
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
          ref.invalidate(dashboardStatsProvider);
          ref.invalidate(appUserProvider);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            // Welcome header
            userAsync.when(
              data: (user) => _DashboardHeader(name: user?.fullName ?? 'Coordinator'),
              loading: () => const SkeletonLoader(height: 90, borderRadius: BorderRadius.all(Radius.circular(12))),
              error: (_, __) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 20),

            // Stats grid
            statsAsync.when(
              data: (stats) => _StatsGrid(stats: stats),
              loading: () => _StatsGridSkeleton(),
              error: (_, __) => _ErrorCard(onRetry: () => ref.invalidate(dashboardStatsProvider)),
            ),
            const SizedBox(height: 20),

            // Trend chart
            statsAsync.when(
              data: (stats) => stats.trend.isNotEmpty ? _TrendChart(trend: stats.trend) : const SizedBox.shrink(),
              loading: () => const SkeletonLoader(height: 180, borderRadius: BorderRadius.all(Radius.circular(12))),
              error: (_, __) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 24),

            // Action menu
            Text('Actions', style: AppTextStyles.h3()),
            const SizedBox(height: 12),
            _MenuTile(
              icon: PhosphorIconsFill.listChecks,
              label: 'Review Queue',
              subtitle: 'Approve or reject pending registrations',
              onTap: () => context.push('/review-queue'),
              badge: statsAsync.valueOrNull?.pending,
            ),
            _MenuTile(
              icon: PhosphorIconsFill.users,
              label: 'Member Directory',
              subtitle: 'Search and browse all members',
              onTap: () => context.push('/member-directory'),
            ),
            _MenuTile(
              icon: PhosphorIconsFill.download,
              label: 'Export Register',
              subtitle: 'Download member data as CSV',
              onTap: () => context.push('/member-directory'),
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

class _StatsGrid extends StatelessWidget {
  final DashboardStats stats;
  const _StatsGrid({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _StatCard(label: 'Total', value: '${stats.total}', icon: PhosphorIconsFill.users, color: AppColors.ndcGreen)),
            const SizedBox(width: 12),
            Expanded(child: _StatCard(label: 'Pending', value: '${stats.pending}', icon: PhosphorIconsFill.clock, color: AppColors.statusPending)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _StatCard(label: 'Approved', value: '${stats.active}', icon: PhosphorIconsFill.checkCircle, color: AppColors.statusActive)),
            const SizedBox(width: 12),
            Expanded(child: _StatCard(label: 'This Month', value: '${stats.thisMonth}', icon: PhosphorIconsFill.calendarBlank, color: AppColors.textSecondary)),
          ],
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: PhosphorIcon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: AppTextStyles.h2()),
              Text(label, style: AppTextStyles.caption()),
            ],
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
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const PhosphorIcon(PhosphorIconsFill.chartLine, size: 16, color: AppColors.ndcGreen),
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
                        color: touched ? AppColors.ndcGreen : AppColors.ndcGreen.withValues(alpha: 0.7),
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
          const Expanded(child: SkeletonLoader(height: 72, borderRadius: BorderRadius.all(Radius.circular(12)))),
          const SizedBox(width: 12),
          const Expanded(child: SkeletonLoader(height: 72, borderRadius: BorderRadius.all(Radius.circular(12)))),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          const Expanded(child: SkeletonLoader(height: 72, borderRadius: BorderRadius.all(Radius.circular(12)))),
          const SizedBox(width: 12),
          const Expanded(child: SkeletonLoader(height: 72, borderRadius: BorderRadius.all(Radius.circular(12)))),
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

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;
  final int? badge;

  const _MenuTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
    this.badge,
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
        trailing: badge != null && badge! > 0
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.statusPending,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('$badge', style: AppTextStyles.badge()),
              )
            : const PhosphorIcon(PhosphorIconsRegular.caretRight, size: 16, color: AppColors.textMuted),
      ),
    );
  }
}
