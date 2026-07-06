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

class StationStats {
  final int id;
  final String? code;
  final String name;
  final int? area;
  final int total;
  final int active;

  const StationStats({
    required this.id,
    required this.code,
    required this.name,
    required this.area,
    required this.total,
    required this.active,
  });

  double get ratio => total == 0 ? 0.0 : (active / total).clamp(0.0, 1.0);

  String get statusLabel {
    if (total == 0) return 'No members yet';
    if (ratio >= 0.75) return 'Excellent';
    if (ratio >= 0.40) return 'On track';
    return 'Needs follow-up';
  }

  Color get statusColor {
    if (total == 0) return AppColors.mist;
    if (ratio >= 0.75) return AppColors.canopyGreen;
    if (ratio >= 0.40) return AppColors.gold;
    return AppColors.umbrellaRed;
  }

  Color get statusBg {
    if (total == 0) return AppColors.fillMuted;
    if (ratio >= 0.75) return AppColors.greenTint;
    if (ratio >= 0.40) return AppColors.goldTint;
    return AppColors.redTint;
  }
}

final trackerProvider = FutureProvider<List<StationStats>>((ref) async {
  final db = Supabase.instance.client;
  final data = await db.rpc('get_polling_station_stats');
  final rows = data as List<dynamic>;
  return rows.map((r) {
    final m = r as Map<String, dynamic>;
    return StationStats(
      id: (m['polling_station_id'] as num).toInt(),
      code: m['station_code'] as String?,
      name: m['name'] as String,
      area: m['electoral_area'] == null ? null : (m['electoral_area'] as num).toInt(),
      total: (m['total'] as num).toInt(),
      active: (m['active_count'] as num).toInt(),
    );
  }).toList();
});

// A flattened tracker row: either an area header or a station.
sealed class _Row {}

class _AreaHeaderRow extends _Row {
  final int? area;
  final int stationCount;
  final int memberCount;
  _AreaHeaderRow(this.area, this.stationCount, this.memberCount);
}

class _StationRowData extends _Row {
  final StationStats station;
  _StationRowData(this.station);
}

List<_Row> _flatten(List<StationStats> stations) {
  final rows = <_Row>[];
  int? current;
  var started = false;
  var idx = 0;
  while (idx < stations.length) {
    final area = stations[idx].area;
    if (!started || area != current) {
      // Gather this area's slice to compute header counts.
      final slice = <StationStats>[];
      var j = idx;
      while (j < stations.length && stations[j].area == area) {
        slice.add(stations[j]);
        j++;
      }
      rows.add(_AreaHeaderRow(
        area,
        slice.length,
        slice.fold(0, (s, e) => s + e.total),
      ));
      started = true;
      current = area;
    }
    rows.add(_StationRowData(stations[idx]));
    idx++;
  }
  return rows;
}

class TrackerScreen extends ConsumerWidget {
  const TrackerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(trackerProvider);

    return Scaffold(
      backgroundColor: AppColors.paper,
      body: RefreshIndicator(
        color: AppColors.canopyGreen,
        onRefresh: () async => ref.invalidate(trackerProvider),
        child: CustomScrollView(
          slivers: [
            _TrackerAppBar(onRefresh: () => ref.invalidate(trackerProvider)),
            statsAsync.when(
              data: (stations) => _buildBody(stations),
              loading: () => SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenH, AppSpacing.lg, AppSpacing.screenH, AppSpacing.h1,
                ),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, _) => const Padding(
                      padding: EdgeInsets.only(bottom: AppSpacing.sm),
                      child: SkeletonLoader(height: 64, borderRadius: AppRadii.borderMd),
                    ),
                    childCount: 8,
                  ),
                ),
              ),
              error: (e, _) => SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenH, AppSpacing.lg, AppSpacing.screenH, AppSpacing.h1,
                ),
                sliver: SliverToBoxAdapter(
                  child: _ErrorCard(onRetry: () => ref.invalidate(trackerProvider)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(List<StationStats> stations) {
    final totalAll = stations.fold(0, (s, a) => s + a.total);

    // No members anywhere yet — show a real empty state, not 283 zero rows.
    if (totalAll == 0) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: EmptyState(
          icon: PhosphorIconsRegular.mapPinLine,
          title: 'No members registered yet',
          subtitle: 'Once personnel register members, coverage per polling '
              'station will appear here.',
        ),
      );
    }

    final activeAll = stations.fold(0, (s, a) => s + a.active);
    // Only stations that actually have members can "need follow-up".
    final needsFollowUp = stations.where((a) => a.total > 0 && a.ratio < 0.40).length;
    final rows = _flatten(stations);

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenH, AppSpacing.lg, AppSpacing.screenH, AppSpacing.h1,
      ),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, i) {
            if (i == 0) {
              return _SummaryHeader(
                total: totalAll,
                approved: activeAll,
                needsFollowUp: needsFollowUp,
              );
            }
            final row = rows[i - 1];
            return switch (row) {
              _AreaHeaderRow() => _AreaHeader(row: row),
              _StationRowData() => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: _StationRow(station: row.station),
                ),
            };
          },
          childCount: rows.length + 1,
        ),
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
          color: AppColors.brand,
        ),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenH, AppSpacing.base, AppSpacing.sm, AppSpacing.base,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Area Tracker', style: AppTextStyles.h2(color: AppColors.surface)),
                  Text(
                    'Coverage by polling station — Tema West',
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
  final int total;
  final int approved;
  final int needsFollowUp;
  const _SummaryHeader({
    required this.total,
    required this.approved,
    required this.needsFollowUp,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.base),
      child: Row(
        children: [
          Expanded(
            child: _SumCard(
              value: '$total',
              label: 'Total registered',
              color: AppColors.canopyGreen,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: _SumCard(
              value: '$approved',
              label: 'Approved',
              color: AppColors.canopyGreen,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: _SumCard(
              value: '$needsFollowUp',
              label: 'Need follow-up',
              color: needsFollowUp > 0 ? AppColors.umbrellaRed : AppColors.mist,
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
  const _SumCard({required this.value, required this.label, required this.color});

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

class _AreaHeader extends StatelessWidget {
  final _AreaHeaderRow row;
  const _AreaHeader({required this.row});

  @override
  Widget build(BuildContext context) {
    final label = row.area == null ? 'Unassigned' : 'Electoral Area ${row.area}';
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.sm),
      child: Row(
        children: [
          Container(
            width: 3, height: 14, color: AppColors.canopyGreen,
            margin: const EdgeInsets.only(right: 8),
          ),
          Expanded(child: Text(label, style: AppTextStyles.h3())),
          Text(
            '${row.memberCount} member${row.memberCount == 1 ? '' : 's'} · ${row.stationCount} stations',
            style: AppTextStyles.caption(),
          ),
        ],
      ),
    );
  }
}

class _StationRow extends StatelessWidget {
  final StationStats station;
  const _StationRow({required this.station});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      station.name,
                      style: AppTextStyles.bodyMedium(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (station.code != null) ...[
                      const SizedBox(height: 2),
                      Text(station.code!, style: AppTextStyles.memberNumber()),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: station.statusBg,
                  borderRadius: AppRadii.borderPill,
                ),
                child: Text(
                  station.statusLabel,
                  style: AppTextStyles.caption(color: station.statusColor)
                      .copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          if (station.total > 0) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Text('${station.active}/${station.total} approved', style: AppTextStyles.label()),
                const Spacer(),
                Text('${(station.ratio * 100).round()}%',
                    style: AppTextStyles.label(color: station.statusColor)),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: station.ratio,
                backgroundColor: AppColors.fillMuted,
                valueColor: AlwaysStoppedAnimation<Color>(station.statusColor),
                minHeight: 4,
              ),
            ),
          ],
        ],
      ),
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
