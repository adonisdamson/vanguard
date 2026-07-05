import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../../features/auth/application/user_role_provider.dart';
import '../../application/member_providers.dart';
import '../../application/offline_queue.dart';
import '../../data/member_repository.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/theme/app_radii.dart';
import '../../../../shared/theme/app_shadows.dart';
import '../../../../shared/theme/app_spacing.dart';
import '../../../../shared/theme/app_text_styles.dart';
import '../../../../shared/widgets/skeleton_loader.dart';
import '../../../../shared/widgets/stat_card.dart';

class PersonnelHomeScreen extends ConsumerWidget {
  const PersonnelHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(appUserProvider);
    final statsAsync = ref.watch(myStatsProvider);
    final activityAsync = ref.watch(personnelRecentActivityProvider);

    if (OfflineQueue.hasItems) {
      OfflineQueue.flush().then((synced) {
        if (synced > 0) {
          ref.invalidate(myStatsProvider);
          ref.invalidate(mySubmissionsProvider);
        }
      });
    }

    return Scaffold(
      backgroundColor: AppColors.paper,
      body: RefreshIndicator(
        color: AppColors.canopyGreen,
        onRefresh: () async {
          ref.invalidate(appUserProvider);
          ref.invalidate(myStatsProvider);
          ref.invalidate(personnelRecentActivityProvider);
        },
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _GreetingHero(userAsync: userAsync, statsAsync: statsAsync),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenH, AppSpacing.lg,
                AppSpacing.screenH, AppSpacing.h1,
              ),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Offline sync banner
                  if (OfflineQueue.hasItems) ...[
                    _OfflineBanner(count: OfflineQueue.count),
                    const SizedBox(height: AppSpacing.base),
                  ],

                  // Quick register action
                  _QuickRegisterCard(onTap: () => context.push('/register-member')),
                  const SizedBox(height: AppSpacing.xl),

                  // Stat cards
                  _StatsLabel(),
                  const SizedBox(height: AppSpacing.md),
                  statsAsync.when(
                    data: (stats) => Row(children: [
                      Expanded(child: StatCard(
                        icon: PhosphorIconsRegular.users,
                        value: '${stats.total}',
                        label: 'Registered',
                        iconColor: AppColors.canopyGreen,
                        iconBg: AppColors.greenTint,
                      )),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(child: StatCard(
                        icon: PhosphorIconsRegular.hourglass,
                        value: '${stats.pending}',
                        label: 'Pending',
                        iconColor: AppColors.gold,
                        iconBg: AppColors.goldTint,
                      )),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(child: StatCard(
                        icon: PhosphorIconsRegular.sealCheck,
                        value: '${stats.active}',
                        label: 'Approved',
                        iconColor: AppColors.canopyGreen,
                        iconBg: AppColors.greenTint,
                      )),
                    ]),
                    loading: () => Row(children: [
                      for (int i = 0; i < 3; i++) ...[
                        const Expanded(child: SkeletonLoader(height: 100, borderRadius: AppRadii.borderMd)),
                        if (i < 2) const SizedBox(width: AppSpacing.sm),
                      ],
                    ]),
                    error: (_, _) => _RetryCard(onRetry: () => ref.invalidate(myStatsProvider)),
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // Progress card
                  statsAsync.when(
                    data: (stats) => _ProgressCard(active: stats.active, total: stats.total),
                    loading: () => const SkeletonLoader(height: 88, borderRadius: AppRadii.borderMd),
                    error: (_, _) => const SizedBox.shrink(),
                  ),
                  const SizedBox(height: AppSpacing.xxl),

                  // Activity feed
                  Row(
                    children: [
                      Expanded(child: Text('Recent activity', style: AppTextStyles.h3())),
                      GestureDetector(
                        onTap: () => context.push('/submissions'),
                        child: Text('View all', style: AppTextStyles.label(color: AppColors.canopyGreen)),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  activityAsync.when(
                    data: (members) => members.isEmpty
                        ? const _EmptyActivity()
                        : Column(children: members.map((m) => _SubmissionActivityItem(member: m)).toList()),
                    loading: () => Column(
                      children: List.generate(
                        3,
                        (_) => const Padding(
                          padding: EdgeInsets.only(bottom: AppSpacing.sm),
                          child: SkeletonLoader(height: 56, borderRadius: AppRadii.borderMd),
                        ),
                      ),
                    ),
                    error: (_, _) => _RetryCard(onRetry: () => ref.invalidate(personnelRecentActivityProvider)),
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
  final AsyncValue<dynamic> statsAsync;

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
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.deepCanopy, AppColors.canopyMid],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenH, AppSpacing.xl,
        AppSpacing.screenH, AppSpacing.xxl,
      ),
      child: userAsync.when(
        data: (user) {
          final name = user?.fullName ?? 'Officer';
          final firstName = name.split(' ').first;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Eyebrow
              Text(
                _greeting().toUpperCase(),
                style: AppTextStyles.eyebrow(color: AppColors.surface.withValues(alpha: 0.5)),
              ),
              const SizedBox(height: 4),
              // Name
              Text(
                firstName,
                style: AppTextStyles.display(color: AppColors.surface),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),
              // Role + constituency chips
              Row(
                children: [
                  _HeroPill(
                    icon: PhosphorIconsRegular.identificationBadge,
                    label: 'Personnel',
                    color: AppColors.canopyGreen,
                  ),
                  const SizedBox(width: 8),
                  _HeroPill(
                    icon: PhosphorIconsRegular.mapPin,
                    label: 'Tema West',
                    color: AppColors.surface.withValues(alpha: 0.25),
                    textColor: AppColors.surface.withValues(alpha: 0.75),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              // Today summary inline
              statsAsync.when(
                data: (s) => _TodaySummary(total: s.total, pending: s.pending),
                loading: () => const SkeletonLoader(height: 40, borderRadius: AppRadii.borderSm),
                error: (_, _) => const SizedBox.shrink(),
              ),
            ],
          );
        },
        loading: () => const SkeletonLoader(height: 120, borderRadius: AppRadii.borderMd),
        error: (_, _) => const SizedBox.shrink(),
      ),
    );
  }
}

class _HeroPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color? textColor;

  const _HeroPill({
    required this.icon,
    required this.label,
    required this.color,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final tc = textColor ?? AppColors.surface;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), // intentional: pill badge sizing
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PhosphorIcon(icon, size: 12, color: tc),
          const SizedBox(width: 5),
          Text(label, style: AppTextStyles.caption(color: tc)),
        ],
      ),
    );
  }
}

class _TodaySummary extends StatelessWidget {
  final int total;
  final int pending;

  const _TodaySummary({required this.total, required this.pending});

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
          _InlineStat(value: '$total', label: 'Total registered'),
          Container(width: 1, height: 28, color: AppColors.surface.withValues(alpha: 0.15),
              margin: const EdgeInsets.symmetric(horizontal: 14)),
          _InlineStat(value: '$pending', label: 'Awaiting review', color: AppColors.gold),
        ],
      ),
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
        Text(
          value,
          style: AppTextStyles.statNumberLg(color: color),
        ),
        Text(
          label,
          style: AppTextStyles.caption(color: AppColors.surface.withValues(alpha: 0.55)),
        ),
      ],
    );
  }
}

// ── Quick register card ───────────────────────────────────────────────────────
class _QuickRegisterCard extends StatelessWidget {
  final VoidCallback onTap;
  const _QuickRegisterCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.base),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.canopyGreen, AppColors.canopyMid],
          ),
          borderRadius: AppRadii.borderMd,
          boxShadow: [
            BoxShadow(
              color: AppColors.canopyGreen.withValues(alpha: 0.30),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: 0.15),
                borderRadius: AppRadii.borderSm,
              ),
              child: const Icon(PhosphorIconsRegular.userPlus, color: AppColors.surface, size: 22),
            ),
            const SizedBox(width: AppSpacing.base),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Register a member', style: AppTextStyles.title(color: AppColors.surface)),
                  Text(
                    'Tap to open the registration form',
                    style: AppTextStyles.caption(color: AppColors.surface.withValues(alpha: 0.65)),
                  ),
                ],
              ),
            ),
            const PhosphorIcon(PhosphorIconsRegular.arrowRight, color: AppColors.surface, size: 18),
          ],
        ),
      ),
    );
  }
}

class _StatsLabel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 3, height: 14, color: AppColors.canopyGreen,
            margin: const EdgeInsets.only(right: 8)),
        Text('My registrations', style: AppTextStyles.h3()),
      ],
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
    final statusText = pct >= 75
        ? 'Excellent momentum'
        : pct >= 40
            ? 'On track'
            : 'Getting started';
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
              Expanded(
                child: Text('Approval rate', style: AppTextStyles.bodyMedium()),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: AppRadii.borderPill,
                ),
                child: Text(statusText,
                    style: AppTextStyles.caption(color: statusColor).copyWith(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(text: '$pct%', style: AppTextStyles.h1(color: AppColors.canopyGreen)),
                TextSpan(
                  text: '  $active of $total approved',
                  style: AppTextStyles.caption(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
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

// ── Offline banner ────────────────────────────────────────────────────────────
class _OfflineBanner extends StatelessWidget {
  final int count;
  const _OfflineBanner({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.goldTint,
        borderRadius: BorderRadius.circular(AppRadii.sm),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const PhosphorIcon(PhosphorIconsFill.cloudSlash, size: 18, color: AppColors.gold),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$count registration${count == 1 ? '' : 's'} saved offline. Connect to sync.',
              style: AppTextStyles.small(color: AppColors.gold),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Activity feed ─────────────────────────────────────────────────────────────
// Shows a personnel member submission as an activity row (Linear-style dense row)
class _SubmissionActivityItem extends StatelessWidget {
  final MemberSummary member;
  const _SubmissionActivityItem({required this.member});

  static (IconData, Color, Color) _forStatus(String status) => switch (status) {
    'active'    => (PhosphorIconsRegular.sealCheck,      AppColors.canopyGreen, AppColors.greenTint),
    'rejected'  => (PhosphorIconsRegular.xCircle,        AppColors.umbrellaRed, AppColors.redTint),
    'suspended' => (PhosphorIconsRegular.prohibit,       AppColors.umbrellaRed, AppColors.redTint),
    _           => (PhosphorIconsRegular.hourglass,      AppColors.gold,        AppColors.goldTint),
  };

  static String _label(String status) => switch (status) {
    'active'   => 'Approved',
    'rejected' => 'Rejected',
    _          => 'Pending review',
  };

  static String _rel(DateTime dt) {
    final d = DateTime.now().difference(dt);
    if (d.inMinutes < 1) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    if (d.inDays < 7) return '${d.inDays}d ago';
    return '${dt.day}/${dt.month}';
  }

  @override
  Widget build(BuildContext context) {
    final (icon, color, bg) = _forStatus(member.status);
    return GestureDetector(
      onTap: () => context.push('/member/${member.id}'),
      child: Container(
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
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: bg, borderRadius: AppRadii.borderSm),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(member.fullName, style: AppTextStyles.bodyMedium(), maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(_label(member.status), style: AppTextStyles.caption()),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(_rel(member.createdAt), style: AppTextStyles.timestamp()),
          ],
        ),
      ),
    );
  }
}

class _EmptyActivity extends StatelessWidget {
  const _EmptyActivity();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(color: AppColors.fillMuted, shape: BoxShape.circle),
            child: const Icon(PhosphorIconsRegular.clockCounterClockwise, size: 24, color: AppColors.mist),
          ),
          const SizedBox(height: 12),
          Text('No activity yet', style: AppTextStyles.h3()),
          const SizedBox(height: 4),
          Text(
            'Register your first member to get started.',
            style: AppTextStyles.caption(),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _RetryCard extends StatelessWidget {
  final VoidCallback onRetry;
  const _RetryCard({required this.onRetry});

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
