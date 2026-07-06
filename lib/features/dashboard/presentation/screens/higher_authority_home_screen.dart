import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../../features/auth/application/user_role_provider.dart';
import '../../application/dashboard_providers.dart';
import '../../data/dashboard_repository.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/theme/app_radii.dart';
import '../../../../shared/theme/app_shadows.dart';
import '../../../../shared/theme/app_spacing.dart';
import '../../../../shared/theme/app_text_styles.dart';
import '../../../../shared/widgets/skeleton_loader.dart';
import '../../../../shared/widgets/stat_card.dart';
import '../../../../shared/widgets/inline_load_error.dart';

class HigherAuthorityHomeScreen extends ConsumerWidget {
  const HigherAuthorityHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(appUserProvider);
    final statsAsync = ref.watch(dashboardStatsProvider);
    final activityAsync = ref.watch(recentActivityProvider);

    return Scaffold(
      backgroundColor: AppColors.paper,
      body: RefreshIndicator(
        color: AppColors.canopyGreen,
        onRefresh: () async {
          ref.invalidate(dashboardStatsProvider);
          ref.invalidate(recentActivityProvider);
          ref.invalidate(appUserProvider);
        },
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _GreetingHero(userAsync: userAsync, statsAsync: statsAsync),
            ),
            SliverPadding(
              // Bottom clearance: last row must never sit clipped against the nav.
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenH, AppSpacing.lg,
                AppSpacing.screenH, AppSpacing.h3,
              ),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Review queue urgency card (shown when pending > 0)
                  statsAsync.when(
                    data: (s) => s.pending > 0
                        ? Padding(
                            padding: const EdgeInsets.only(bottom: AppSpacing.base),
                            child: _ReviewUrgencyCard(pending: s.pending),
                          )
                        : const SizedBox.shrink(),
                    loading: () => const SizedBox.shrink(),
                    error: (_, _) => const InlineLoadError(),
                  ),

                  // Stat cards 2x2
                  Row(
                    children: [
                      Container(width: 3, height: 14, color: AppColors.canopyGreen,
                          margin: const EdgeInsets.only(right: 8)),
                      Text('Overview', style: AppTextStyles.h3()),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  statsAsync.when(
                    data: (s) => s.total == 0
                        ? const EmptyStatsNote(
                            icon: PhosphorIconsRegular.usersThree,
                            message:
                                'No members in the registry yet — new registrations will appear here for review.',
                          )
                        : Column(children: [
                      Row(children: [
                        Expanded(child: StatCard(
                          icon: PhosphorIconsRegular.users,
                          value: '${s.total}',
                          label: 'Total members',
                          iconColor: AppColors.canopyGreen,
                          iconBg: AppColors.greenTint,
                        )),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(child: StatCard(
                          icon: PhosphorIconsRegular.hourglass,
                          value: '${s.pending}',
                          label: 'Pending review',
                          iconColor: AppColors.gold,
                          iconBg: AppColors.goldTint,
                        )),
                      ]),
                      const SizedBox(height: AppSpacing.sm),
                      Row(children: [
                        Expanded(child: StatCard(
                          icon: PhosphorIconsRegular.sealCheck,
                          value: '${s.active}',
                          label: 'Approved',
                          iconColor: AppColors.canopyGreen,
                          iconBg: AppColors.greenTint,
                        )),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(child: StatCard(
                          icon: PhosphorIconsRegular.calendarBlank,
                          value: '${s.thisMonth}',
                          label: 'This month',
                          iconColor: AppColors.mist,
                          iconBg: AppColors.fillMuted,
                        )),
                      ]),
                    ]),
                    loading: () => _StatsGridSkeleton(),
                    error: (_, _) => _ErrorCard(onRetry: () => ref.invalidate(dashboardStatsProvider)),
                  ),
                  const SizedBox(height: AppSpacing.base),

                  // Approval progress bar
                  statsAsync.when(
                    data: (s) => _ProgressCard(active: s.active, total: s.total),
                    loading: () => const SkeletonLoader(height: 90, borderRadius: AppRadii.borderMd),
                    error: (_, _) => const InlineLoadError(),
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // Quick actions
                  Row(children: [
                    Expanded(child: _ActionCard(
                      icon: PhosphorIconsFill.listChecks,
                      label: 'Review queue',
                      badge: statsAsync.valueOrNull?.pending,
                      color: AppColors.canopyGreen,
                      bg: AppColors.greenTint,
                      onTap: () => context.push('/review-queue'),
                    )),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(child: _ActionCard(
                      icon: PhosphorIconsFill.users,
                      label: 'Directory',
                      color: AppColors.mist,
                      bg: AppColors.fillMuted,
                      onTap: () => context.push('/member-directory'),
                    )),
                  ]),
                  const SizedBox(height: AppSpacing.xl),

                  // Trend chart
                  statsAsync.when(
                    data: (s) => s.trend.isNotEmpty
                        ? _TrendChart(trend: s.trend)
                        : const SizedBox.shrink(),
                    loading: () => const SkeletonLoader(height: 180, borderRadius: AppRadii.borderMd),
                    error: (_, _) => const InlineLoadError(),
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // Activity feed
                  Row(
                    children: [
                      Expanded(child: Text('Recent activity', style: AppTextStyles.h3())),
                      GestureDetector(
                        onTap: () => context.push('/admin/audit'),
                        child: Text('View all', style: AppTextStyles.label(color: AppColors.canopyGreen)),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  activityAsync.when(
                    data: (entries) => entries.isEmpty
                        ? _EmptyActivity()
                        : Column(children: entries.map((e) => _ActivityItem(entry: e)).toList()),
                    loading: () => Column(
                      children: List.generate(
                        4,
                        (_) => const Padding(
                          padding: EdgeInsets.only(bottom: AppSpacing.sm),
                          child: SkeletonLoader(height: 56, borderRadius: AppRadii.borderMd),
                        ),
                      ),
                    ),
                    error: (_, _) => const InlineLoadError(),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Greeting hero ─────────────────────────────────────────────────────────────
class _GreetingHero extends StatelessWidget {
  final AsyncValue<AppUser?> userAsync;
  final AsyncValue<DashboardStats> statsAsync;

  const _GreetingHero({required this.userAsync, required this.statsAsync});

  static String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.brand,
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenH, AppSpacing.xl,
        AppSpacing.screenH, AppSpacing.xxl,
      ),
      child: userAsync.when(
        data: (user) {
          final firstName = user?.fullName.split(' ').first ?? 'Coordinator';
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _greeting().toUpperCase(),
                style: AppTextStyles.eyebrow(color: AppColors.surface.withValues(alpha: 0.5)),
              ),
              const SizedBox(height: 4),
              Text(
                firstName,
                style: AppTextStyles.display(color: AppColors.surface),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _HeroPill(
                    icon: PhosphorIconsRegular.star,
                    label: 'Coordinator',
                    color: AppColors.gold.withValues(alpha: 0.22),
                    textColor: AppColors.gold,
                  ),
                  const SizedBox(width: 8),
                  _HeroPill(
                    icon: PhosphorIconsRegular.mapPin,
                    label: 'Tema West',
                    color: AppColors.surface.withValues(alpha: 0.12),
                    textColor: AppColors.surface.withValues(alpha: 0.7),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              // Inline stats
              statsAsync.when(
                data: (s) => _HeroStatsRow(total: s.total, pending: s.pending, active: s.active),
                loading: () => const SkeletonLoader(height: 40, borderRadius: AppRadii.borderSm),
                error: (_, _) => const InlineLoadError(),
              ),
            ],
          );
        },
        loading: () => const SkeletonLoader(height: 120, borderRadius: AppRadii.borderMd),
        error: (_, _) => const InlineLoadError(),
      ),
    );
  }
}

class _HeroPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color textColor;

  const _HeroPill({
    required this.icon,
    required this.label,
    required this.color,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), // intentional: pill badge sizing
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(color: textColor.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PhosphorIcon(icon, size: 12, color: textColor),
          const SizedBox(width: 5),
          Text(label, style: AppTextStyles.caption(color: textColor)),
        ],
      ),
    );
  }
}

class _HeroStatsRow extends StatelessWidget {
  final int total;
  final int pending;
  final int active;

  const _HeroStatsRow({required this.total, required this.pending, required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: AppColors.surface.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          _InlineStat(value: '$total', label: 'Total'),
          _Divider(),
          _InlineStat(
            value: '$pending',
            label: 'Pending',
            color: pending > 0 ? AppColors.gold : AppColors.surface,
          ),
          _Divider(),
          _InlineStat(value: '$active', label: 'Approved'),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 28,
      color: AppColors.surface.withValues(alpha: 0.15),
      margin: const EdgeInsets.symmetric(horizontal: 14),
    );
  }
}

class _InlineStat extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _InlineStat({
    required this.value,
    required this.label,
    this.color = AppColors.surface,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: AppTextStyles.statNumberLg(color: color)),
        Text(label, style: AppTextStyles.caption(color: AppColors.surface.withValues(alpha: 0.55))),
      ],
    );
  }
}

// ── Review urgency card ───────────────────────────────────────────────────────
class _ReviewUrgencyCard extends StatelessWidget {
  final int pending;
  const _ReviewUrgencyCard({required this.pending});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        context.push('/review-queue');
      },
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.base),
        decoration: BoxDecoration(
          color: AppColors.goldTint,
          borderRadius: AppRadii.borderMd,
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
          boxShadow: [
            BoxShadow(
              color: AppColors.gold.withValues(alpha: 0.10),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: AppColors.gold.withValues(alpha: 0.18), borderRadius: AppRadii.borderSm),
              child: const Icon(PhosphorIconsFill.bell, size: 20, color: AppColors.gold),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$pending member${pending == 1 ? '' : 's'} awaiting review',
                    style: AppTextStyles.bodyMedium(color: AppColors.ink),
                  ),
                  Text(
                    'Tap to open review queue',
                    style: AppTextStyles.caption(color: AppColors.mist),
                  ),
                ],
              ),
            ),
            const PhosphorIcon(PhosphorIconsRegular.arrowRight, size: 18, color: AppColors.gold),
          ],
        ),
      ),
    );
  }
}

// ── Action cards ─────────────────────────────────────────────────────────────
class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final int? badge;
  final Color color;
  final Color bg;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.label,
    this.badge,
    required this.color,
    required this.bg,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadii.borderMd,
          boxShadow: AppShadows.e1,
          border: Border.all(color: AppColors.hairline),
        ),
        child: Row(
          children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(color: bg, borderRadius: AppRadii.borderSm),
              child: Icon(icon, size: 16, color: color),
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(label, style: AppTextStyles.bodyMedium())),
            if (badge != null && badge! > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: const BoxDecoration(color: AppColors.gold, borderRadius: AppRadii.borderPill),
                child: Text('$badge', style: AppTextStyles.badge(color: AppColors.surface)),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Trend chart ───────────────────────────────────────────────────────────────
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
          Row(children: [
            Container(width: 3, height: 14, color: AppColors.canopyGreen, margin: const EdgeInsets.only(right: 8)),
            Text('Registrations — last 6 months', style: AppTextStyles.h3()),
          ]),
          const SizedBox(height: 20),
          SizedBox(
            height: 150,
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
                      AppTextStyles.badge(color: AppColors.surface),
                    ),
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, _) {
                        final i = value.toInt();
                        if (i < 0 || i >= widget.trend.length) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(widget.trend[i].month, style: AppTextStyles.caption()),
                        );
                      },
                      reservedSize: 24,
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      getTitlesWidget: (value, _) =>
                          Text(value.toInt().toString(), style: AppTextStyles.caption()),
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: adjustedMax / 4,
                  getDrawingHorizontalLine: (_) =>
                      FlLine(color: AppColors.hairline, strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(widget.trend.length, (i) {
                  final touched = _touchedIndex == i;
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: widget.trend[i].count.toDouble(),
                        width: 16,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
                        color: touched
                            ? AppColors.canopyGreen
                            : AppColors.canopyGreen.withValues(alpha: 0.65),
                        backDrawRodData: BackgroundBarChartRodData(
                          show: true,
                          toY: adjustedMax,
                          color: AppColors.fillMuted,
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

// ── Helpers ───────────────────────────────────────────────────────────────────
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
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        color: AppColors.redTint,
        borderRadius: AppRadii.borderMd,
        border: Border.all(color: AppColors.umbrellaRed.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const PhosphorIcon(PhosphorIconsFill.warningCircle, size: 20, color: AppColors.umbrellaRed),
          const SizedBox(width: 12),
          Expanded(child: Text('Could not load stats.', style: AppTextStyles.body())),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _ActivityItem extends StatelessWidget {
  final dynamic entry;
  const _ActivityItem({required this.entry});

  static String _humanAction(String action, Map<String, dynamic> meta) {
    return switch (action) {
      'member_created' => 'New member registered',
      'member_status_changed' => () {
          final s = meta['new_status'] as String? ?? '';
          return s == 'active' ? 'Member approved' : 'Member rejected';
        }(),
      'member_updated' => 'Member record updated',
      'operator_created' => 'New operator account created',
      'role_changed' => 'Operator role changed',
      'account_status_changed' => 'Account status updated',
      _ => action.replaceAll('_', ' '),
    };
  }

  static IconData _icon(String action) {
    return switch (action) {
      'member_created' => PhosphorIconsRegular.userPlus,
      'member_status_changed' => PhosphorIconsRegular.sealCheck,
      'operator_created' => PhosphorIconsRegular.usersThree,
      'role_changed' => PhosphorIconsRegular.shieldStar,
      _ => PhosphorIconsRegular.clockCounterClockwise,
    };
  }

  static Color _color(String action, Map<String, dynamic> meta) {
    if (action == 'member_status_changed') {
      return (meta['new_status'] as String?) == 'active'
          ? AppColors.canopyGreen
          : AppColors.umbrellaRed;
    }
    return AppColors.canopyGreen;
  }

  static Color _bg(String action, Map<String, dynamic> meta) {
    if (action == 'member_status_changed') {
      return (meta['new_status'] as String?) == 'active'
          ? AppColors.greenTint
          : AppColors.redTint;
    }
    return AppColors.greenTint;
  }

  static String _relTime(DateTime dt) {
    final d = DateTime.now().difference(dt);
    if (d.inMinutes < 1) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    if (d.inDays < 7) return '${d.inDays}d ago';
    return '${dt.day}/${dt.month}';
  }

  @override
  Widget build(BuildContext context) {
    final action = entry.action as String;
    final meta = entry.metadata as Map<String, dynamic>;
    final actor = entry.actorName as String? ?? 'System';

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.borderMd,
        boxShadow: AppShadows.e1,
        border: Border.all(color: AppColors.hairline),
      ),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: _bg(action, meta), borderRadius: AppRadii.borderSm),
            child: Icon(_icon(action), color: _color(action, meta), size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_humanAction(action, meta), style: AppTextStyles.bodyMedium(),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(actor, style: AppTextStyles.caption(),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(_relTime(entry.createdAt as DateTime), style: AppTextStyles.timestamp()),
        ],
      ),
    );
  }
}

class _EmptyActivity extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
      child: Column(
        children: [
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(color: AppColors.fillMuted, shape: BoxShape.circle),
            child: const Icon(PhosphorIconsRegular.clockCounterClockwise, size: 24, color: AppColors.mist),
          ),
          const SizedBox(height: 12),
          Text('No activity yet', style: AppTextStyles.h3()),
          const SizedBox(height: 4),
          Text('Actions will appear here once members are registered.',
              style: AppTextStyles.caption(), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

// ── Progress card ─────────────────────────────────────────────────────────────
class _ProgressCard extends StatelessWidget {
  final int active;
  final int total;
  const _ProgressCard({required this.active, required this.total});

  @override
  Widget build(BuildContext context) {
    final ratio = total == 0 ? 0.0 : (active / total).clamp(0.0, 1.0);
    final pct = (ratio * 100).round();
    final statusText = pct >= 75 ? 'Excellent' : pct >= 40 ? 'On track' : 'Getting started';
    final statusColor = pct >= 75
        ? AppColors.canopyGreen
        : pct >= 40
            ? AppColors.gold
            : AppColors.mist;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.base),
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
              Expanded(child: Text('Approval rate', style: AppTextStyles.bodyMedium())),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: AppRadii.borderPill,
                ),
                child: Text(statusText,
                    style: AppTextStyles.caption(color: statusColor)
                        .copyWith(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          RichText(
            text: TextSpan(children: [
              TextSpan(text: '$pct%', style: AppTextStyles.h1(color: AppColors.canopyGreen)),
              TextSpan(
                  text: '  $active of $total approved',
                  style: AppTextStyles.caption()),
            ]),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: AppRadii.borderXs,
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 6,
              backgroundColor: AppColors.fillMuted,
              valueColor: AlwaysStoppedAnimation<Color>(statusColor),
            ),
          ),
        ],
      ),
    );
  }
}
