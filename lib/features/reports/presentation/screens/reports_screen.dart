import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/errors/app_error_mapper.dart';
import '../../../../core/net/file_saver.dart';
import '../../../../features/dashboard/application/dashboard_providers.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/theme/app_radii.dart';
import '../../../../shared/theme/app_shadows.dart';
import '../../../../shared/theme/app_spacing.dart';
import '../../../../shared/theme/app_text_styles.dart';
import '../../../../shared/widgets/skeleton_loader.dart';
import '../../../../shared/widgets/inline_load_error.dart';
import '../../../dashboard/presentation/widgets/status_donut.dart';

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
      final apiBaseUrl =
          dotenv.env['API_BASE_URL'] ?? dotenv.env['RAILWAY_API_URL'] ?? '';
      final response = await http.post(
        Uri.parse('$apiBaseUrl/api/exports/members'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'format': 'csv'}),
      ).timeout(const Duration(seconds: 120));
      if (response.statusCode != 200) throw Exception('Export failed');

      final stamp = DateTime.now().toIso8601String().substring(0, 10);
      // Mobile: temp file + share sheet. Web: browser download.
      await saveOrShareBytes(
        response.bodyBytes,
        filename: 'NDC_members_$stamp.csv',
        mime: 'text/csv',
        subject: 'NDC member register ($stamp)',
        text: 'NDC Tema West member register — CSV export ($stamp).',
      );
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
        subtitle: 'Coverage per electoral area',
        color: AppColors.gold,
        bg: AppColors.goldTint,
        onTap: () => context.push('/tracker'),
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
                  error: (_, _) => InlineLoadError(
                    onRetry: () => ref.invalidate(dashboardStatsProvider),
                  ),
                ),
                const SizedBox(height: AppSpacing.base),

                // Status breakdown donut (pie) — appears once there's data
                statsAsync.when(
                  data: (s) => (s.total > 0)
                      ? StatusDonut(
                          active: s.active, pending: s.pending, rejected: s.rejected)
                      : const SizedBox.shrink(),
                  loading: () => const SkeletonLoader(height: 160, borderRadius: AppRadii.borderMd),
                  error: (_, _) => const SizedBox.shrink(),
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
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.borderMd,
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          _Metric(value: '${stats.total}', label: 'Total'),
          _Divider(),
          _Metric(value: '${stats.active}', label: 'Approved', dotColor: AppColors.success),
          _Divider(),
          _Metric(value: '${stats.pending}', label: 'Pending', dotColor: AppColors.warning),
          _Divider(),
          _Metric(value: '${stats.rejected}', label: 'Rejected', dotColor: AppColors.danger),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 30, color: AppColors.line);
  }
}

class _Metric extends StatelessWidget {
  final String value;
  final String label;
  final Color? dotColor;
  const _Metric({required this.value, required this.label, this.dotColor});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: AppTextStyles.h1()),
          const SizedBox(height: 3),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (dotColor != null) ...[
                Container(
                    width: 6, height: 6,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: dotColor)),
                const SizedBox(width: 4),
              ],
              Flexible(
                child: Text(label,
                    style: AppTextStyles.caption(),
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.fade),
              ),
            ],
          ),
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
    // Real button affordance: ink ripple + chevron. Uniform brand icon chip —
    // no rainbow of green/gold/red tinted boxes.
    return Material(
      color: AppColors.surface,
      borderRadius: AppRadii.borderMd,
      child: InkWell(
        borderRadius: AppRadii.borderMd,
        onTap: data.onTap,
        child: Ink(
          padding: const EdgeInsets.all(AppSpacing.base),
          decoration: BoxDecoration(
            borderRadius: AppRadii.borderMd,
            border: Border.all(color: AppColors.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.brandTint,
                      borderRadius: AppRadii.borderSm,
                    ),
                    child: Icon(data.icon, color: AppColors.brand, size: 18),
                  ),
                  const Spacer(),
                  const PhosphorIcon(PhosphorIconsRegular.caretRight,
                      size: 15, color: AppColors.inkMuted),
                ],
              ),
              const SizedBox(height: 14),
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
        boxShadow: AppShadows.e2,
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
