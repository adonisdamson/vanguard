import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../../features/auth/application/user_role_provider.dart';
import '../../../../features/dashboard/application/dashboard_providers.dart';
import '../../application/operator_providers.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/theme/app_radii.dart';
import '../../../../shared/theme/app_shadows.dart';
import '../../../../shared/theme/app_spacing.dart';
import '../../../../shared/theme/app_text_styles.dart';
import '../../../../shared/widgets/skeleton_loader.dart';
import '../../../../shared/widgets/stat_card.dart';
import '../../../../shared/widgets/inline_load_error.dart';
import '../../../../shared/widgets/hero_crest.dart';
import '../../../../shared/widgets/hero_summary_card.dart';

class AdminHomeScreen extends ConsumerWidget {
  const AdminHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(appUserProvider);
    final memberStatsAsync = ref.watch(dashboardStatsProvider);
    final operatorStatsAsync = ref.watch(operatorStatsProvider);
    final activityAsync = ref.watch(recentActivityProvider);

    return Scaffold(
      backgroundColor: AppColors.paper,
      body: RefreshIndicator(
        color: AppColors.canopyGreen,
        onRefresh: () async {
          ref.invalidate(dashboardStatsProvider);
          ref.invalidate(operatorStatsProvider);
          ref.invalidate(recentActivityProvider);
          ref.invalidate(appUserProvider);
        },
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _AdminGreetingHero(userAsync: userAsync, statsAsync: memberStatsAsync),
            ),
            SliverPadding(
              // Bottom clearance: last row must never sit clipped against the nav.
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenH, AppSpacing.lg,
                AppSpacing.screenH, AppSpacing.h3,
              ),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Member stats
                  _SectionLabel(label: 'Member registry'),
                  const SizedBox(height: AppSpacing.md),
                  memberStatsAsync.when(
                    data: (s) => s.total == 0
                        ? const EmptyStatsNote(
                            icon: PhosphorIconsRegular.usersThree,
                            message:
                                'No members in the registry yet — registrations will appear here.',
                          )
                        : Row(children: [
                      Expanded(child: StatCard(
                        icon: PhosphorIconsRegular.users,
                        value: '${s.total}',
                        label: 'Total',
                        iconColor: AppColors.canopyGreen,
                        iconBg: AppColors.greenTint,
                      )),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(child: StatCard(
                        icon: PhosphorIconsRegular.hourglass,
                        value: '${s.pending}',
                        label: 'Pending',
                        iconColor: AppColors.statusPending,
                        iconBg: AppColors.pendingBg,
                      )),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(child: StatCard(
                        icon: PhosphorIconsRegular.sealCheck,
                        value: '${s.active}',
                        label: 'Active',
                        iconColor: AppColors.canopyGreen,
                        iconBg: AppColors.greenTint,
                      )),
                    ]),
                    loading: () => Row(children: [
                      for (var i = 0; i < 3; i++) ...[
                        if (i > 0) const SizedBox(width: AppSpacing.sm),
                        const Expanded(child: SkeletonLoader(height: 96, borderRadius: AppRadii.borderMd)),
                      ]
                    ]),
                    error: (_, _) => _ErrorCard(onRetry: () => ref.invalidate(dashboardStatsProvider)),
                  ),
                  const SizedBox(height: AppSpacing.base),

                  // Approval progress
                  memberStatsAsync.when(
                    data: (s) => _ProgressCard(active: s.active, total: s.total),
                    loading: () => const SkeletonLoader(height: 90, borderRadius: AppRadii.borderMd),
                    error: (_, _) => const InlineLoadError(),
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // Operator stats
                  _SectionLabel(label: 'Operators'),
                  const SizedBox(height: AppSpacing.md),
                  operatorStatsAsync.when(
                    data: (counts) => Row(children: [
                      Expanded(child: StatCard(
                        icon: PhosphorIconsRegular.usersThree,
                        value: '${counts['total'] ?? 0}',
                        label: 'Total',
                        iconColor: AppColors.ink,
                        iconBg: AppColors.fillMuted,
                      )),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(child: StatCard(
                        icon: PhosphorIconsRegular.shieldStar,
                        value: '${counts['admin'] ?? 0}',
                        label: 'Admins',
                        iconColor: AppColors.umbrellaRed,
                        iconBg: AppColors.redTint,
                      )),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(child: StatCard(
                        icon: PhosphorIconsRegular.identificationCard,
                        value: '${counts['personnel'] ?? 0}',
                        label: 'Personnel',
                        iconColor: AppColors.canopyGreen,
                        iconBg: AppColors.greenTint,
                      )),
                    ]),
                    loading: () => Row(children: [
                      for (var i = 0; i < 3; i++) ...[
                        if (i > 0) const SizedBox(width: AppSpacing.sm),
                        const Expanded(child: SkeletonLoader(height: 96, borderRadius: AppRadii.borderMd)),
                      ]
                    ]),
                    error: (_, _) => _ErrorCard(onRetry: () => ref.invalidate(operatorStatsProvider)),
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // System management action grid
                  _SectionLabel(label: 'System management'),
                  const SizedBox(height: AppSpacing.md),
                  _SystemActionsGrid(
                    pendingCount: memberStatsAsync.valueOrNull?.pending,
                  ),
                  const SizedBox(height: AppSpacing.xxl),

                  // Recent activity
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
                        ? const SizedBox.shrink()
                        : Column(children: entries.map((e) => _ActivityRow(entry: e)).toList()),
                    loading: () => Column(
                      children: List.generate(
                        3,
                        (_) => const Padding(
                          padding: EdgeInsets.only(bottom: AppSpacing.sm),
                          child: SkeletonLoader(height: 56, borderRadius: AppRadii.borderMd),
                        ),
                      ),
                    ),
                    error: (_, _) => _ErrorCard(onRetry: () => ref.invalidate(recentActivityProvider)),
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
class _AdminGreetingHero extends StatelessWidget {
  final AsyncValue<AppUser?> userAsync;
  final AsyncValue<dynamic> statsAsync;

  const _AdminGreetingHero({required this.userAsync, required this.statsAsync});

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
          final firstName = user?.fullName.split(' ').first ?? 'Admin';
          return Column(
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
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  const HeroCrest(),
                ],
              ),
              const SizedBox(height: 10),
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), // intentional: pill badge sizing
                  decoration: BoxDecoration(
                    color: AppColors.surface.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      PhosphorIcon(PhosphorIconsRegular.userGear, size: 12, color: AppColors.surface.withValues(alpha: 0.9)),
                      const SizedBox(width: 5),
                      Text('Administrator', style: AppTextStyles.caption(color: AppColors.surface.withValues(alpha: 0.9))),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), // intentional: pill badge sizing
                  decoration: BoxDecoration(
                    color: AppColors.surface.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      PhosphorIcon(PhosphorIconsRegular.mapPin, size: 12, color: AppColors.surface.withValues(alpha: 0.7)),
                      const SizedBox(width: 5),
                      Text('Tema West', style: AppTextStyles.caption(color: AppColors.surface.withValues(alpha: 0.7))),
                    ],
                  ),
                ),
              ]),
              const SizedBox(height: AppSpacing.xl),
              statsAsync.when(
                data: (s) => HeroSummaryCard(items: [
                  HeroSummaryItem(icon: PhosphorIconsRegular.usersThree, value: '${s.total}', label: 'Total members'),
                  HeroSummaryItem(icon: PhosphorIconsRegular.listChecks, value: '${s.pending}', label: 'Need review', accent: const Color(0xFFF2CE6B)),
                ]),
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



// ── Section label ─────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 3, height: 14, color: AppColors.canopyGreen, margin: const EdgeInsets.only(right: 8)),
        Text(label, style: AppTextStyles.h3()),
      ],
    );
  }
}

// ── System actions grid ───────────────────────────────────────────────────────
class _SystemActionsGrid extends StatelessWidget {
  final int? pendingCount;
  const _SystemActionsGrid({this.pendingCount});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _SystemActionRow(
          icon: PhosphorIconsRegular.usersThree,
          iconColor: AppColors.brand,
          iconBg: AppColors.brandTint,
          label: 'Operators',
          subtitle: 'Create, approve and manage accounts',
          onTap: () => context.push('/admin/operators'),
        ),
        const SizedBox(height: AppSpacing.sm),
        _SystemActionRow(
          icon: PhosphorIconsRegular.listChecks,
          iconColor: AppColors.warning,
          iconBg: AppColors.amberTint,
          label: 'Review queue',
          subtitle: pendingCount != null && pendingCount! > 0
              ? '$pendingCount registrations waiting'
              : 'Nothing waiting for review',
          badge: pendingCount,
          onTap: () => context.push('/review-queue'),
        ),
        const SizedBox(height: AppSpacing.sm),
        _SystemActionRow(
          icon: PhosphorIconsRegular.mapPin,
          iconColor: AppColors.brand,
          iconBg: AppColors.brandTint,
          label: 'Location setup',
          subtitle: 'Regions, districts and polling stations',
          onTap: () => context.push('/admin/lookups'),
        ),
        const SizedBox(height: AppSpacing.sm),
        _SystemActionRow(
          icon: PhosphorIconsRegular.scroll,
          iconColor: AppColors.ink,
          iconBg: AppColors.fillMuted,
          label: 'Audit log',
          subtitle: 'Every action, who did it, and when',
          onTap: () => context.push('/admin/audit'),
        ),
      ],
    );
  }
}

/// Full-width action row — unmistakably a button: ink ripple, bold title,
/// and a chevron in its own circle. Not another stat card.
class _SystemActionRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String label;
  final String subtitle;
  final int? badge;
  final VoidCallback onTap;

  const _SystemActionRow({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.label,
    required this.subtitle,
    this.badge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: AppRadii.borderMd,
      child: InkWell(
        borderRadius: AppRadii.borderMd,
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: AppRadii.borderMd,
            border: Border.all(color: AppColors.line),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                    color: iconBg, borderRadius: AppRadii.borderSm),
                child: Icon(icon, size: 20, color: iconColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: AppTextStyles.bodyMedium()),
                    const SizedBox(height: 1),
                    Text(subtitle,
                        style: AppTextStyles.caption(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (badge != null && badge! > 0) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: const BoxDecoration(
                    color: AppColors.warning,
                    borderRadius: AppRadii.borderPill,
                  ),
                  child: Text('$badge',
                      style: AppTextStyles.badge(color: AppColors.surface)),
                ),
                const SizedBox(width: 8),
              ],
              Container(
                width: 30,
                height: 30,
                decoration: const BoxDecoration(
                  color: AppColors.fillMuted,
                  shape: BoxShape.circle,
                ),
                child: const PhosphorIcon(PhosphorIconsRegular.caretRight,
                    size: 15, color: AppColors.ink),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Activity row ──────────────────────────────────────────────────────────────
class _ActivityRow extends StatelessWidget {
  final dynamic entry;
  const _ActivityRow({required this.entry});

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

  static (Color, Color) _colors(String action, Map<String, dynamic> meta) {
    return switch (action) {
      'member_status_changed' when (meta['new_status'] as String?) == 'active' =>
        (AppColors.canopyGreen, AppColors.greenTint),
      'member_status_changed' => (AppColors.umbrellaRed, AppColors.redTint),
      'operator_created' || 'role_changed' => (AppColors.umbrellaRed, AppColors.redTint),
      _ => (AppColors.canopyGreen, AppColors.greenTint),
    };
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
    final (color, bg) = _colors(action, meta);

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
            decoration: BoxDecoration(color: bg, borderRadius: AppRadii.borderSm),
            child: Icon(_icon(action), color: color, size: 18),
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
          Expanded(child: Text('Could not load data.', style: AppTextStyles.body())),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
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
            ? AppColors.statusPending
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
