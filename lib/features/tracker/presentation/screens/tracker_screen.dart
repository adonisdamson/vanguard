import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/theme/app_radii.dart';
import '../../../../shared/theme/app_spacing.dart';
import '../../../../shared/theme/app_text_styles.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/inline_load_error.dart';
import '../../../../shared/widgets/ndc_flag_stripe.dart';
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

  bool get covered => total > 0;
  double get ratio => total == 0 ? 0.0 : (active / total).clamp(0.0, 1.0);
}

/// One electoral area, aggregated from its stations.
class AreaGroup {
  final int? area;
  final List<StationStats> stations;
  const AreaGroup(this.area, this.stations);

  String get label => area == null ? 'Unassigned' : 'Electoral Area $area';
  int get members => stations.fold(0, (s, e) => s + e.total);
  int get approved => stations.fold(0, (s, e) => s + e.active);
  int get coveredStations => stations.where((s) => s.covered).length;
  int get stationCount => stations.length;
  double get coverage =>
      stationCount == 0 ? 0.0 : coveredStations / stationCount;
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

List<AreaGroup> _group(List<StationStats> stations) {
  final map = <int?, List<StationStats>>{};
  for (final s in stations) {
    map.putIfAbsent(s.area, () => []).add(s);
  }
  final keys = map.keys.toList()
    ..sort((a, b) => (a ?? 9999).compareTo(b ?? 9999));
  return [for (final k in keys) AreaGroup(k, map[k]!)];
}

class TrackerScreen extends ConsumerWidget {
  const TrackerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(trackerProvider);

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: RefreshIndicator(
        color: AppColors.brand,
        onRefresh: () async => ref.invalidate(trackerProvider),
        child: CustomScrollView(
          slivers: [
            const _TrackerHeader(),
            statsAsync.when(
              data: (stations) => _body(stations),
              loading: () => const _LoadingSliver(),
              error: (_, _) => SliverPadding(
                padding: const EdgeInsets.all(AppSpacing.screenH),
                sliver: SliverToBoxAdapter(
                  child: InlineLoadError(
                    message: "Couldn't load coverage",
                    onRetry: () => ref.invalidate(trackerProvider),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body(List<StationStats> stations) {
    final totalMembers = stations.fold(0, (s, e) => s + e.total);

    if (totalMembers == 0) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: EmptyState(
          icon: PhosphorIconsRegular.mapPinLine,
          title: 'No members registered yet',
          subtitle: 'Once personnel register members, coverage by electoral '
              'area and polling station will appear here.',
        ),
      );
    }

    final groups = _group(stations);
    final coveredStations = stations.where((s) => s.covered).length;
    final activeAreas = groups.where((g) => g.members > 0).length;

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenH, AppSpacing.lg, AppSpacing.screenH, AppSpacing.h3),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, i) {
            if (i == 0) {
              return _OverviewCard(
                members: totalMembers,
                coveredStations: coveredStations,
                totalStations: stations.length,
                activeAreas: activeAreas,
              );
            }
            final g = groups[i - 1];
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _AreaCard(group: g, startExpanded: g.members > 0),
            );
          },
          childCount: groups.length + 1,
        ),
      ),
    );
  }
}

// ── Header band ───────────────────────────────────────────────────────────────
class _TrackerHeader extends StatelessWidget {
  const _TrackerHeader();

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return SliverToBoxAdapter(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            color: AppColors.deepCanopy,
            padding: EdgeInsets.fromLTRB(
                AppSpacing.screenH, top + 16, AppSpacing.screenH, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('AREA TRACKER',
                    style: AppTextStyles.eyebrow(
                        color: AppColors.surface.withValues(alpha: 0.5))),
                const SizedBox(height: 4),
                Text('Coverage by electoral area',
                    style: AppTextStyles.h1(color: AppColors.surface)),
                const SizedBox(height: 2),
                Text('Tema West Constituency · 283 polling stations',
                    style: AppTextStyles.caption(
                        color: AppColors.surface.withValues(alpha: 0.6))),
              ],
            ),
          ),
          const NdcFlagStripe(height: 6),
        ],
      ),
    );
  }
}

// ── Overview strip ────────────────────────────────────────────────────────────
class _OverviewCard extends StatelessWidget {
  final int members;
  final int coveredStations;
  final int totalStations;
  final int activeAreas;

  const _OverviewCard({
    required this.members,
    required this.coveredStations,
    required this.totalStations,
    required this.activeAreas,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.base),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.borderMd,
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          Expanded(
            child: _Metric(
                icon: PhosphorIconsRegular.usersThree,
                value: '$members',
                label: 'Members'),
          ),
          _divider(),
          Expanded(
            child: _Metric(
                icon: PhosphorIconsRegular.mapPin,
                value: '$coveredStations',
                label: 'of $totalStations stations'),
          ),
          _divider(),
          Expanded(
            child: _Metric(
                icon: PhosphorIconsRegular.stackSimple,
                value: '$activeAreas',
                label: 'active areas'),
          ),
        ],
      ),
    );
  }

  Widget _divider() => Container(
      width: 1, height: 34, color: AppColors.line,
      margin: const EdgeInsets.symmetric(horizontal: 12));
}

class _Metric extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  const _Metric({required this.icon, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: AppTextStyles.h1()),
        const SizedBox(height: 2),
        Row(
          children: [
            Icon(icon, size: 13, color: AppColors.inkMuted),
            const SizedBox(width: 4),
            Expanded(
              child: Text(label,
                  style: AppTextStyles.caption(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Expandable area card ──────────────────────────────────────────────────────
class _AreaCard extends StatefulWidget {
  final AreaGroup group;
  final bool startExpanded;
  const _AreaCard({required this.group, this.startExpanded = false});

  @override
  State<_AreaCard> createState() => _AreaCardState();
}

class _AreaCardState extends State<_AreaCard> {
  late bool _expanded = widget.startExpanded;

  @override
  Widget build(BuildContext context) {
    final g = widget.group;
    final hasMembers = g.members > 0;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.borderMd,
        border: Border.all(color: AppColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Header row (tap to expand)
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: hasMembers ? AppColors.brandTint : AppColors.fillMuted,
                      borderRadius: AppRadii.borderSm,
                    ),
                    child: Icon(PhosphorIconsRegular.mapPinArea,
                        size: 20,
                        color: hasMembers ? AppColors.brand : AppColors.inkMuted),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(g.label, style: AppTextStyles.bodyMedium()),
                        const SizedBox(height: 2),
                        Text(
                          hasMembers
                              ? '${g.members} member${g.members == 1 ? '' : 's'} · ${g.coveredStations}/${g.stationCount} stations covered'
                              : '${g.stationCount} stations · none covered yet',
                          style: AppTextStyles.caption(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: _expanded ? 0.25 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: const PhosphorIcon(PhosphorIconsRegular.caretRight,
                        size: 16, color: AppColors.inkMuted),
                  ),
                ],
              ),
            ),
          ),
          // Coverage bar
          if (hasMembers)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: g.coverage,
                  backgroundColor: AppColors.fillMuted,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.brand),
                  minHeight: 5,
                ),
              ),
            ),
          // Expanded station list
          if (_expanded) ...[
            const Divider(height: 1, color: AppColors.line),
            ...g.stations.map((s) => _StationRow(station: s)),
          ],
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Row(
        children: [
          Container(
            width: 7, height: 7,
            margin: const EdgeInsets.only(top: 5, right: 10),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: station.covered ? AppColors.success : AppColors.line,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(station.name,
                    style: AppTextStyles.body(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                if (station.code != null) ...[
                  const SizedBox(height: 1),
                  Text(station.code!, style: AppTextStyles.caption()),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            station.covered ? '${station.active}/${station.total}' : '—',
            style: station.covered
                ? AppTextStyles.label(color: AppColors.ink)
                : AppTextStyles.label(color: AppColors.inkMuted),
          ),
        ],
      ),
    );
  }
}

// ── Loading ───────────────────────────────────────────────────────────────────
class _LoadingSliver extends StatelessWidget {
  const _LoadingSliver();

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenH, AppSpacing.lg, AppSpacing.screenH, AppSpacing.h1),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (_, i) => Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: SkeletonLoader(
                height: i == 0 ? 84 : 68, borderRadius: AppRadii.borderMd),
          ),
          childCount: 7,
        ),
      ),
    );
  }
}
