import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/errors/app_error_mapper.dart';
import '../../../../features/dashboard/application/dashboard_providers.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/theme/app_radii.dart';
import '../../../../shared/theme/app_shadows.dart';
import '../../../../shared/theme/app_spacing.dart';
import '../../../../shared/theme/app_text_styles.dart';
import '../../../../shared/widgets/skeleton_loader.dart';

class _ReportTileData {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final Color bg;
  final VoidCallback onTap;

  const _ReportTileData({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.bg,
    required this.onTap,
  });
}

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
      final railwayUrl = dotenv.env['RAILWAY_API_URL'] ?? '';
      final client = HttpClient();
      final uri = Uri.parse('$railwayUrl/api/exports/members');
      final request = await client.postUrl(uri);
      request.headers.set('Authorization', 'Bearer $token');
      request.headers.set('Content-Type', 'application/json');
      request.add(utf8.encode(jsonEncode({'format': 'csv'})));
      final response = await request.close().timeout(const Duration(seconds: 120));
      if (response.statusCode != 200) throw Exception('Export failed');
      final chunks = <List<int>>[];
      await for (final chunk in response) {
        chunks.add(chunk);
      }
      final bytes = chunks.expand((x) => x).toList();
      final dir = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${dir.path}/members_export_$timestamp.csv');
      await file.writeAsBytes(bytes);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Exported to ${file.path}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppErrorMapper.friendly(e)),
            backgroundColor: AppColors.umbrellaRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context, ) {
    final statsAsync = ref.watch(dashboardStatsProvider);

    final tiles = [
      _ReportTileData(
        icon: PhosphorIconsRegular.chartBar,
        title: 'Constituency summary',
        subtitle: 'Overall registration and approval stats',
        color: AppColors.canopyGreen,
        bg: AppColors.greenTint,
        onTap: () => context.push('/member-directory'),
      ),
      _ReportTileData(
        icon: PhosphorIconsRegular.mapPin,
        title: 'Area performance',
        subtitle: 'Per electoral area breakdown',
        color: AppColors.gold,
        bg: AppColors.goldTint,
        onTap: () {},
      ),
      _ReportTileData(
        icon: PhosphorIconsRegular.userPlus,
        title: 'New registrations',
        subtitle: 'Members registered this month',
        color: AppColors.canopyGreen,
        bg: AppColors.greenTint,
        onTap: () => context.push('/member-directory'),
      ),
      _ReportTileData(
        icon: PhosphorIconsRegular.clock,
        title: 'Unverified members',
        subtitle: 'Pending approval — needs review',
        color: AppColors.gold,
        bg: AppColors.goldTint,
        onTap: () => context.push('/review-queue'),
      ),
      _ReportTileData(
        icon: PhosphorIconsRegular.xCircle,
        title: 'Rejected records',
        subtitle: 'Members rejected during review',
        color: AppColors.umbrellaRed,
        bg: AppColors.redTint,
        onTap: () => context.push('/member-directory'),
      ),
      _ReportTileData(
        icon: PhosphorIconsRegular.scroll,
        title: 'Audit log',
        subtitle: 'Full system activity trail',
        color: AppColors.mist,
        bg: AppColors.fillMuted,
        onTap: () => context.push('/admin/audit'),
      ),
    ];

    return Scaffold(
      backgroundColor: AppColors.paper,
      body: CustomScrollView(
        slivers: [
          _ReportsAppBar(statsAsync: statsAsync),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenH, AppSpacing.lg,
              AppSpacing.screenH, AppSpacing.h1,
            ),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Stats summary
                statsAsync.when(
                  data: (s) => _StatsRow(stats: s),
                  loading: () => const SkeletonLoader(height: 72, borderRadius: AppRadii.borderMd),
                  error: (_, __) => const SizedBox.shrink(),
                ),
                const SizedBox(height: AppSpacing.xl),

                // Report tiles grid
                Text('Reports', style: AppTextStyles.h3()),
                const SizedBox(height: AppSpacing.md),
                GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: AppSpacing.md,
                  mainAxisSpacing: AppSpacing.md,
                  childAspectRatio: 1.15,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: tiles.map((t) => _ReportTile(data: t)).toList(),
                ),
                const SizedBox(height: AppSpacing.xl),

                // Export card
                _ExportCard(exporting: _exporting, onExport: _exportCsv),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportsAppBar extends StatelessWidget {
  final AsyncValue<dynamic> statsAsync;
  const _ReportsAppBar({required this.statsAsync});

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Container(
        color: AppColors.deepCanopy,
        padding: EdgeInsets.fromLTRB(
          AppSpacing.screenH,
          MediaQuery.of(context).padding.top + AppSpacing.base,
          AppSpacing.screenH,
          AppSpacing.base,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Reports', style: AppTextStyles.h2(color: AppColors.surface)),
            Text(
              'Analytics & data exports',
              style: AppTextStyles.caption(color: AppColors.surface.withValues(alpha: 0.6)),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final dynamic stats;
  const _StatsRow({required this.stats});

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
          _Metric(value: '${stats.total}', label: 'Total', color: AppColors.canopyGreen),
          _Divider(),
          _Metric(value: '${stats.active}', label: 'Approved', color: AppColors.canopyGreen),
          _Divider(),
          _Metric(value: '${stats.pending}', label: 'Pending', color: AppColors.gold),
          _Divider(),
          _Metric(value: '${stats.rejected}', label: 'Rejected', color: AppColors.umbrellaRed),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 32, color: AppColors.hairline, margin: const EdgeInsets.symmetric(horizontal: 12));
  }
}

class _Metric extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  const _Metric({required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: AppTextStyles.h2(color: color)),
          Text(label, style: AppTextStyles.caption()),
        ],
      ),
    );
  }
}

class _ReportTile extends StatelessWidget {
  final _ReportTileData data;
  const _ReportTile({required this.data});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: data.onTap,
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
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: data.bg,
                borderRadius: AppRadii.borderSm,
              ),
              child: Icon(data.icon, color: data.color, size: 18),
            ),
            const Spacer(),
            Text(
              data.title,
              style: AppTextStyles.bodyMedium(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              data.subtitle,
              style: AppTextStyles.caption(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _ExportCard extends StatelessWidget {
  final bool exporting;
  final VoidCallback onExport;
  const _ExportCard({required this.exporting, required this.onExport});

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
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.12),
              borderRadius: AppRadii.borderSm,
            ),
            child: const Icon(PhosphorIconsRegular.download, color: AppColors.surface, size: 20),
          ),
          const SizedBox(width: AppSpacing.base),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Export member data', style: AppTextStyles.bodyMedium(color: AppColors.surface)),
                Text(
                  'Download full register as CSV',
                  style: AppTextStyles.caption(color: AppColors.surface.withValues(alpha: 0.6)),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          if (exporting)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.surface),
            )
          else
            GestureDetector(
              onTap: onExport,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: AppRadii.borderSm,
                ),
                child: Text('Export', style: AppTextStyles.buttonText(color: AppColors.deepCanopy)),
              ),
            ),
        ],
      ),
    );
  }
}
