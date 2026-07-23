import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/errors/app_error_mapper.dart';
import '../../../../core/net/file_saver.dart';
import '../../../../features/dashboard/application/dashboard_providers.dart';
import '../../../../features/dashboard/data/dashboard_repository.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/theme/app_radii.dart';
import '../../../../shared/theme/app_shadows.dart';
import '../../../../shared/theme/app_spacing.dart';
import '../../../../shared/theme/app_text_styles.dart';
import '../../../../shared/widgets/skeleton_loader.dart';
import '../../../../shared/widgets/inline_load_error.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Reports screen — completely redesigned.
// Design direction: "NDC Command Centre" — data-dense but purposeful.
//   • Hero header shows approval rate as the headline KPI (political health signal)
//   • Horizontal stacked bars for status breakdown (legible at a glance, no donut)
//   • Gradient area chart for registration trend
//   • Report shortcuts + export CTA at bottom
// ─────────────────────────────────────────────────────────────────────────────

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  bool _exporting = false;

  Future<void> _exportCsv() async {
    setState(() => _exporting = true);
    try {
      final token = Supabase.instance.client.auth.currentSession?.accessToken;
      if (token == null) throw Exception('Not authenticated');
      final base = dotenv.env['API_BASE_URL'] ?? dotenv.env['RAILWAY_API_URL'] ?? '';
      final resp = await http.post(
        Uri.parse('$base/api/exports/members'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'format': 'csv'}),
      ).timeout(const Duration(seconds: 120));
      if (resp.statusCode != 200) throw Exception('Export failed (${resp.statusCode})');

      final stamp = DateTime.now().toIso8601String().substring(0, 10);
      await saveOrShareBytes(
        resp.bodyBytes,
        filename: 'NDC_members_$stamp.csv',
        mime: 'text/csv',
        subject: 'NDC member register ($stamp)',
        text: 'NDC Tema West member register — CSV export ($stamp).',
      );
      if (mounted) {
        HapticFeedback.mediumImpact();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Member register exported successfully.'),
          backgroundColor: AppColors.canopyGreen,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: AppRadii.borderSm),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(AppErrorMapper.friendly(e)),
          backgroundColor: AppColors.umbrellaRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: AppRadii.borderSm),
        ));
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(dashboardStatsProvider);

    return Scaffold(
      backgroundColor: AppColors.paper,
      body: RefreshIndicator(
        color: AppColors.canopyGreen,
        onRefresh: () async => ref.invalidate(dashboardStatsProvider),
        child: CustomScrollView(
          slivers: [
            // ── Hero header ──────────────────────────────────────────────
            SliverToBoxAdapter(
              child: statsAsync.when(
                data: (s) => _HeroHeader(stats: s),
                loading: () => const SkeletonLoader(height: 180),
                error: (_, _) => _HeroHeaderEmpty(),
              ),
            ),

            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenH, AppSpacing.xl,
                AppSpacing.screenH, AppSpacing.h1,
              ),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // ── Status breakdown (horizontal bars) ───────────────
                  _SectionLabel('Member status'),
                  const SizedBox(height: AppSpacing.md),
                  statsAsync.when(
                    data: (s) => s.total == 0
                        ? _EmptyCard(message: 'No members in the system yet.')
                        : _StatusBreakdown(
                            active: s.active,
                            pending: s.pending,
                            rejected: s.rejected,
                            total: s.total,
                          ),
                    loading: () => const SkeletonLoader(height: 130, borderRadius: AppRadii.borderMd),
                    error: (_, _) => InlineLoadError(
                        onRetry: () => ref.invalidate(dashboardStatsProvider)),
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // ── Registration trend chart ─────────────────────────
                  _SectionLabel('Registration trend'),
                  const SizedBox(height: AppSpacing.md),
                  statsAsync.when(
                    data: (s) => s.trend.length >= 2
                        ? _TrendChart(trend: s.trend)
                        : _EmptyCard(message: 'Not enough data yet — trend appears after 2 months.'),
                    loading: () => const SkeletonLoader(height: 240, borderRadius: AppRadii.borderMd),
                    error: (_, _) => InlineLoadError(
                        onRetry: () => ref.invalidate(dashboardStatsProvider)),
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // ── Quick report links ───────────────────────────────
                  _SectionLabel('Quick access'),
                  const SizedBox(height: AppSpacing.md),
                  _ReportGrid(context: context),
                  const SizedBox(height: AppSpacing.xl),

                  // ── Export CTA ───────────────────────────────────────
                  _ExportCard(exporting: _exporting, onExport: _exportCsv),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Section label with left accent bar ───────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(width: 3, height: 16, color: AppColors.canopyGreen,
          margin: const EdgeInsets.only(right: 10)),
      Text(text, style: AppTextStyles.h3()),
    ]);
  }
}

// ── Hero header — approval rate as the headline KPI ──────────────────────────

class _HeroHeader extends StatelessWidget {
  final DashboardStats stats;
  const _HeroHeader({required this.stats});

  @override
  Widget build(BuildContext context) {
    final pct = stats.total == 0
        ? 0
        : ((stats.active / stats.total) * 100).round();

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.deepCanopy, Color(0xFF005733)],
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.screenH,
        MediaQuery.of(context).padding.top + AppSpacing.base,
        AppSpacing.screenH,
        AppSpacing.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label
          Row(children: [
            PhosphorIcon(PhosphorIconsFill.chartLineUp,
                size: 15, color: AppColors.surface.withValues(alpha: 0.55)),
            const SizedBox(width: 6),
            Text('ANALYTICS', style: AppTextStyles.eyebrow(
                color: AppColors.surface.withValues(alpha: 0.55))),
          ]),
          const SizedBox(height: 6),
          Text('Reports', style: AppTextStyles.display(color: AppColors.surface)),
          const SizedBox(height: AppSpacing.xl),

          // Three KPI chips in a row
          Row(
            children: [
              _HeroKpi(value: '${stats.total}', label: 'Total'),
              const SizedBox(width: AppSpacing.sm),
              _HeroKpi(value: '$pct%', label: 'Approved', highlight: true),
              const SizedBox(width: AppSpacing.sm),
              _HeroKpi(value: '${stats.thisMonth}', label: 'This month'),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroHeaderEmpty extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.deepCanopy,
      padding: EdgeInsets.fromLTRB(
        AppSpacing.screenH,
        MediaQuery.of(context).padding.top + AppSpacing.base,
        AppSpacing.screenH,
        AppSpacing.xl,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Reports', style: AppTextStyles.display(color: AppColors.surface)),
      ]),
    );
  }
}

class _HeroKpi extends StatelessWidget {
  final String value;
  final String label;
  final bool highlight;
  const _HeroKpi({required this.value, required this.label, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: highlight
              ? AppColors.surface.withValues(alpha: 0.18)
              : AppColors.surface.withValues(alpha: 0.08),
          borderRadius: AppRadii.borderSm,
          border: highlight
              ? Border.all(color: AppColors.surface.withValues(alpha: 0.55), width: 1)
              : Border.all(color: AppColors.surface.withValues(alpha: 0.12), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: AppTextStyles.h2(color: AppColors.surface),
            ),
            const SizedBox(height: 2),
            Text(label,
                style: AppTextStyles.caption(
                    color: AppColors.surface.withValues(alpha: 0.6))),
          ],
        ),
      ),
    );
  }
}

// ── Status breakdown — horizontal bars, much cleaner than a donut ─────────────

class _StatusBreakdown extends StatelessWidget {
  final int active, pending, rejected, total;
  const _StatusBreakdown({
    required this.active,
    required this.pending,
    required this.rejected,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.borderMd,
        boxShadow: AppShadows.e1,
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        children: [
          _HorizBar(label: 'Approved', value: active, total: total,
              color: AppColors.canopyGreen, bg: AppColors.greenTint,
              icon: PhosphorIconsFill.sealCheck),
          const SizedBox(height: AppSpacing.md),
          _HorizBar(label: 'Pending', value: pending, total: total,
              color: AppColors.statusPending, bg: AppColors.amberTint,
              icon: PhosphorIconsFill.hourglass),
          const SizedBox(height: AppSpacing.md),
          _HorizBar(label: 'Rejected', value: rejected, total: total,
              color: AppColors.umbrellaRed, bg: AppColors.redTint,
              icon: PhosphorIconsFill.xCircle),
        ],
      ),
    );
  }
}

class _HorizBar extends StatefulWidget {
  final String label;
  final int value;
  final int total;
  final Color color;
  final Color bg;
  final IconData icon;
  const _HorizBar({
    required this.label,
    required this.value,
    required this.total,
    required this.color,
    required this.bg,
    required this.icon,
  });

  @override
  State<_HorizBar> createState() => _HorizBarState();
}

class _HorizBarState extends State<_HorizBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pct = widget.total == 0 ? 0.0 : widget.value / widget.total;
    final pctLabel = '${(pct * 100).round()}%';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 26, height: 26,
              decoration: BoxDecoration(
                color: widget.bg, borderRadius: AppRadii.borderSm),
              child: PhosphorIcon(widget.icon, size: 14, color: widget.color),
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(widget.label, style: AppTextStyles.bodyMedium())),
            Text(
              '${widget.value}',
              style: AppTextStyles.bodyMedium().copyWith(color: widget.color),
            ),
            const SizedBox(width: 6),
            SizedBox(
              width: 38,
              child: Text(pctLabel,
                  style: AppTextStyles.caption(),
                  textAlign: TextAlign.right),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Animated progress bar
        AnimatedBuilder(
          animation: _anim,
          builder: (_, _) => ClipRRect(
            borderRadius: AppRadii.borderPill,
            child: Stack(
              children: [
                Container(
                  height: 7,
                  color: AppColors.hairline,
                  width: double.infinity,
                ),
                FractionallySizedBox(
                  widthFactor: (_anim.value * pct).clamp(0.0, 1.0),
                  child: Container(height: 7, color: widget.color),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Registration trend — gradient area chart with annotations ─────────────────

class _TrendChart extends StatelessWidget {
  final List<MonthlyCount> trend;
  const _TrendChart({required this.trend});

  @override
  Widget build(BuildContext context) {
    final t = trend;
    final maxY = t.fold<int>(0, (m, e) => e.count > m ? e.count : m);
    final chartMax = (maxY < 5 ? 6 : (maxY * 1.3).ceil()).toDouble();
    final total = t.fold<int>(0, (m, e) => m + e.count);

    final last = t.last.count;
    final prev = t.length >= 2 ? t[t.length - 2].count : 0;
    final delta = last - prev;
    final up = delta >= 0;

    final spots = [
      for (var i = 0; i < t.length; i++)
        FlSpot(i.toDouble(), t[i].count.toDouble()),
    ];

    // Show at most 6 x-axis labels — take evenly spaced indices
    final step = (t.length / 6).ceil().clamp(1, t.length);

    return Container(
      padding: const EdgeInsets.fromLTRB(4, 20, 16, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.borderMd,
        boxShadow: AppShadows.e1,
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Row(children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$total', style: AppTextStyles.h1()),
                    Text('members over ${t.length} months',
                        style: AppTextStyles.caption()),
                  ],
                ),
              ),
              // Momentum badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: up ? AppColors.greenTint : AppColors.redTint,
                  borderRadius: AppRadii.borderPill,
                  border: Border.all(
                    color: (up ? AppColors.canopyGreen : AppColors.umbrellaRed)
                        .withValues(alpha: 0.3),
                  ),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  PhosphorIcon(
                    up ? PhosphorIconsFill.trendUp : PhosphorIconsFill.trendDown,
                    size: 13,
                    color: up ? AppColors.canopyGreen : AppColors.umbrellaRed,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${delta.abs()} this month',
                    style: AppTextStyles.badge(
                        color: up ? AppColors.canopyGreen : AppColors.umbrellaRed),
                  ),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: (t.length - 1).toDouble(),
                minY: 0,
                maxY: chartMax,
                lineTouchData: LineTouchData(
                  handleBuiltInTouches: true,
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => AppColors.deepCanopy,
                    tooltipRoundedRadius: 8,
                    getTooltipItems: (spots) => spots.map((s) {
                      final i = s.x.toInt();
                      return LineTooltipItem(
                        '${s.y.toInt()}\n',
                        AppTextStyles.bodyMedium(color: AppColors.surface),
                        children: [
                          TextSpan(
                            text: (i >= 0 && i < t.length) ? t[i].month : '',
                            style: AppTextStyles.caption(
                                color: AppColors.surface.withValues(alpha: 0.65)),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      interval: (chartMax / 3).ceilToDouble(),
                      getTitlesWidget: (v, _) => Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Text(
                          v.toInt() == 0 ? '' : '${v.toInt()}',
                          style: AppTextStyles.caption(),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 26,
                      interval: 1,
                      getTitlesWidget: (v, _) {
                        final i = v.toInt();
                        if (i < 0 || i >= t.length) return const SizedBox.shrink();
                        if (i % step != 0 && i != t.length - 1) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(t[i].month,
                              style: AppTextStyles.caption(), textAlign: TextAlign.center),
                        );
                      },
                    ),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: (chartMax / 3).ceilToDouble(),
                  getDrawingHorizontalLine: (_) =>
                      FlLine(color: AppColors.hairline, strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    curveSmoothness: 0.35,
                    preventCurveOverShooting: true,
                    color: AppColors.canopyGreen,
                    barWidth: 2.5,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, _, ld, i) {
                        // Only show dot on the last (current) point
                        if (i != ld.spots.length - 1) {
                          return FlDotCirclePainter(
                              radius: 0, color: Colors.transparent, strokeWidth: 0, strokeColor: Colors.transparent);
                        }
                        return FlDotCirclePainter(
                          radius: 4,
                          color: AppColors.surface,
                          strokeWidth: 2.5,
                          strokeColor: AppColors.canopyGreen,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppColors.canopyGreen.withValues(alpha: 0.22),
                          AppColors.canopyGreen.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Quick report tiles grid ───────────────────────────────────────────────────

class _ReportGrid extends StatelessWidget {
  final BuildContext context;
  const _ReportGrid({required this.context});

  @override
  Widget build(BuildContext context) {
    final tiles = [
      _TileData(
        icon: PhosphorIconsFill.users,
        title: 'Member directory',
        subtitle: 'Browse & search all members',
        color: AppColors.canopyGreen,
        onTap: () => context.push('/member-directory'),
      ),
      _TileData(
        icon: PhosphorIconsFill.listChecks,
        title: 'Review queue',
        subtitle: 'Pending approvals',
        color: AppColors.ndcRed,
        onTap: () => context.push('/review-queue'),
      ),
      _TileData(
        icon: PhosphorIconsFill.mapPin,
        title: 'Area tracker',
        subtitle: 'Coverage by polling station',
        color: AppColors.deepCanopy,
        onTap: () => context.push('/tracker'),
      ),
      _TileData(
        icon: PhosphorIconsFill.scroll,
        title: 'Audit log',
        subtitle: 'Full system activity trail',
        color: AppColors.inkMuted,
        onTap: () => context.push('/admin/audit'),
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: AppSpacing.md,
        mainAxisSpacing: AppSpacing.md,
        childAspectRatio: 1.3,
      ),
      itemCount: tiles.length,
      itemBuilder: (_, i) => _ReportTile(data: tiles[i]),
    );
  }
}

class _TileData {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  const _TileData({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });
}

class _ReportTile extends StatelessWidget {
  final _TileData data;
  const _ReportTile({required this.data});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: AppRadii.borderMd,
      child: InkWell(
        borderRadius: AppRadii.borderMd,
        onTap: data.onTap,
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: AppRadii.borderMd,
            border: Border.all(color: AppColors.hairline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  width: 34, height: 34,
                  decoration: BoxDecoration(
                    color: data.color.withValues(alpha: 0.1),
                    borderRadius: AppRadii.borderSm,
                  ),
                  child: PhosphorIcon(data.icon, size: 17, color: data.color),
                ),
                const Spacer(),
                PhosphorIcon(PhosphorIconsRegular.arrowRight,
                    size: 14, color: AppColors.inkMuted),
              ]),
              const Spacer(),
              Text(data.title,
                  style: AppTextStyles.bodyMedium(),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text(data.subtitle,
                  style: AppTextStyles.caption(),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Export CTA ────────────────────────────────────────────────────────────────

class _ExportCard extends StatelessWidget {
  final bool exporting;
  final VoidCallback onExport;
  const _ExportCard({required this.exporting, required this.onExport});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: exporting ? null : onExport,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.base),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.deepCanopy, Color(0xFF005733)],
          ),
          borderRadius: AppRadii.borderMd,
          boxShadow: AppShadows.e2,
        ),
        child: Row(
          children: [
            Container(
              width: 46, height: 46,
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: 0.12),
                borderRadius: AppRadii.borderSm,
              ),
              child: const PhosphorIcon(PhosphorIconsRegular.downloadSimple,
                  color: AppColors.surface, size: 22),
            ),
            const SizedBox(width: AppSpacing.base),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Export member register',
                      style: AppTextStyles.bodyMedium(color: AppColors.surface)),
                  const SizedBox(height: 2),
                  Text('Download full CSV — all members, all fields',
                      style: AppTextStyles.caption(
                          color: AppColors.surface.withValues(alpha: 0.6))),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: exporting
                  ? const SizedBox(
                      key: ValueKey('loading'),
                      width: 22, height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.surface),
                    )
                  : Container(
                      key: const ValueKey('button'),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: AppRadii.borderSm,
                      ),
                      child: Text('Export',
                          style: AppTextStyles.buttonText(
                              color: AppColors.deepCanopy)),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Misc helpers ──────────────────────────────────────────────────────────────

class _EmptyCard extends StatelessWidget {
  final String message;
  const _EmptyCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.borderMd,
        border: Border.all(color: AppColors.hairline),
      ),
      child: Row(children: [
        const PhosphorIcon(PhosphorIconsRegular.info,
            size: 18, color: AppColors.inkMuted),
        const SizedBox(width: 10),
        Expanded(child: Text(message, style: AppTextStyles.body(color: AppColors.inkMuted))),
      ]),
    );
  }
}
