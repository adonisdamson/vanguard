import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/theme/app_radii.dart';
import '../../../../shared/theme/app_shadows.dart';
import '../../../../shared/theme/app_spacing.dart';
import '../../../../shared/theme/app_text_styles.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/skeleton_loader.dart';

class AreaStats {
  final int electoralArea;
  final int total;
  final int active;

  const AreaStats({required this.electoralArea, required this.total, required this.active});

  double get ratio => total == 0 ? 0.0 : (active / total).clamp(0.0, 1.0);

  String get statusLabel {
    if (ratio >= 0.75) return 'Excellent';
    if (ratio >= 0.40) return 'On track';
    return 'Needs follow-up';
  }

  Color get statusColor {
    if (ratio >= 0.75) return AppColors.canopyGreen;
    if (ratio >= 0.40) return AppColors.gold;
    return AppColors.umbrellaRed;
  }

  Color get statusBg {
    if (ratio >= 0.75) return AppColors.greenTint;
    if (ratio >= 0.40) return AppColors.goldTint;
    return AppColors.redTint;
  }
}

final trackerProvider = FutureProvider<List<AreaStats>>((ref) async {
  final db = Supabase.instance.client;
  final data = await db.rpc('get_electoral_area_stats');
  final rows = data as List<dynamic>;
  return rows
      .map((r) {
        final m = r as Map<String, dynamic>;
        return AreaStats(
          electoralArea: (m['electoral_area'] as num).toInt(),
          total: (m['total'] as num).toInt(),
          active: (m['active_count'] as num).toInt(),
        );
      })
      .toList()
    ..sort((a, b) => a.electoralArea.compareTo(b.electoralArea));
});

class TrackerScreen extends ConsumerWidget {
  const TrackerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(trackerProvider);

    return Scaffold(
      backgroundColor: AppColors.paper,
      body: CustomScrollView(
        slivers: [
          _TrackerAppBar(onRefresh: () => ref.invalidate(trackerProvider)),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenH, AppSpacing.lg,
              AppSpacing.screenH, AppSpacing.h1,
            ),
            sliver: statsAsync.when(
              data: (areas) => areas.isEmpty
                  ? const SliverToBoxAdapter(
                      child: EmptyState(
                        icon: PhosphorIconsRegular.mapPin,
                        title: 'No data yet',
                        subtitle: 'Tracker will populate once members are registered.',
                      ),
                    )
                  : SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, i) {
                          if (i == 0) return _SummaryHeader(areas: areas);
                          return Padding(
                            padding: const EdgeInsets.only(bottom: AppSpacing.md),
                            child: _AreaCard(area: areas[i - 1]),
                          );
                        },
                        childCount: areas.length + 1,
                      ),
                    ),
              loading: () => SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, _) => const Padding(
                    padding: EdgeInsets.only(bottom: AppSpacing.md),
                    child: SkeletonLoader(height: 100, borderRadius: AppRadii.borderMd),
                  ),
                  childCount: 6,
                ),
              ),
              error: (e, _) => SliverToBoxAdapter(
                child: _ErrorCard(onRetry: () => ref.invalidate(trackerProvider)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrackerAppBar extends StatelessWidget {
  final VoidCallback onRefresh;
  const _TrackerAppBar({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.deepCanopy, AppColors.canopyMid],
          ),
        ),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenH, AppSpacing.base,
          AppSpacing.sm, AppSpacing.base,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Area Tracker', style: AppTextStyles.h2(color: AppColors.surface)),
                  Text(
                    'Per electoral area — Tema West',
                    style: AppTextStyles.caption(color: AppColors.surface.withValues(alpha: 0.6)),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const PhosphorIcon(
                PhosphorIconsRegular.arrowCounterClockwise,
                color: AppColors.surface,
                size: 20,
              ),
              onPressed: onRefresh,
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryHeader extends StatelessWidget {
  final List<AreaStats> areas;
  const _SummaryHeader({required this.areas});

  @override
  Widget build(BuildContext context) {
    final totalAll = areas.fold(0, (s, a) => s + a.total);
    final activeAll = areas.fold(0, (s, a) => s + a.active);
    final needsFollowUp = areas.where((a) => a.ratio < 0.40).length;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.base),
      child: Row(
        children: [
          Expanded(
            child: _SumCard(
              value: '$totalAll',
              label: 'Total registered',
              color: AppColors.canopyGreen,
              bg: AppColors.greenTint,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: _SumCard(
              value: '$activeAll',
              label: 'Approved',
              color: AppColors.canopyGreen,
              bg: AppColors.greenTint,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: _SumCard(
              value: '$needsFollowUp',
              label: 'Need follow-up',
              color: AppColors.umbrellaRed,
              bg: AppColors.redTint,
            ),
          ),
        ],
      ),
    );
  }
}

class _SumCard extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  final Color bg;
  const _SumCard({required this.value, required this.label, required this.color, required this.bg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.borderMd,
        boxShadow: AppShadows.e1,
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: AppTextStyles.statNumber(color: color)),
          const SizedBox(height: 2),
          Text(label, style: AppTextStyles.caption()),
        ],
      ),
    );
  }
}

class _AreaCard extends StatelessWidget {
  final AreaStats area;
  const _AreaCard({required this.area});

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
      child: Row(
        children: [
          // Progress ring
          SizedBox(
            width: 64,
            height: 64,
            child: _ProgressRing(ratio: area.ratio, color: area.statusColor),
          ),
          const SizedBox(width: AppSpacing.base),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Electoral Area ${area.electoralArea}',
                  style: AppTextStyles.title(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      '${area.active}/${area.total} approved',
                      style: AppTextStyles.label(),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: area.statusBg,
                        borderRadius: AppRadii.borderPill,
                      ),
                      child: Text(
                        area.statusLabel,
                        style: AppTextStyles.caption(color: area.statusColor).copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: area.ratio,
                    backgroundColor: AppColors.fillMuted,
                    valueColor: AlwaysStoppedAnimation<Color>(area.statusColor),
                    minHeight: 4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressRing extends StatelessWidget {
  final double ratio;
  final Color color;
  const _ProgressRing({required this.ratio, required this.color});

  @override
  Widget build(BuildContext context) {
    final pct = (ratio * 100).round();
    return CustomPaint(
      painter: _RingPainter(ratio: ratio, color: color),
      child: Center(
        child: Text(
          '$pct%',
          style: AppTextStyles.ringPercent(color: color),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double ratio;
  final Color color;
  const _RingPainter({required this.ratio, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final radius = (size.width / 2) - 4;
    const strokeWidth = 6.0;

    final bgPaint = Paint()
      ..color = AppColors.fillMuted
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final fgPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(Offset(cx, cy), radius, bgPaint);

    if (ratio > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: radius),
        -math.pi / 2,
        2 * math.pi * ratio,
        false,
        fgPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.ratio != ratio || old.color != color;
}

class _ErrorCard extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorCard({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.base),
      margin: const EdgeInsets.only(top: AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.redTint,
        borderRadius: AppRadii.borderMd,
        border: Border.all(color: AppColors.umbrellaRed.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const PhosphorIcon(PhosphorIconsFill.warningCircle, size: 20, color: AppColors.umbrellaRed),
          const SizedBox(width: 12),
          Expanded(
            child: Text('Could not load tracker data.', style: AppTextStyles.body()),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
