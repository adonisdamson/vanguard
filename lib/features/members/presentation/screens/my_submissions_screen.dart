import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../application/member_providers.dart';
import '../../application/offline_queue.dart';
import '../../../../features/auth/application/auth_provider.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/theme/app_text_styles.dart';
import '../../../../shared/widgets/ndc_flag_stripe.dart';
import '../../../../shared/widgets/skeleton_loader.dart';
import '../widgets/member_list_tile.dart';

class MySubmissionsScreen extends ConsumerWidget {
  const MySubmissionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(submissionsFilterProvider);
    final membersAsync = ref.watch(mySubmissionsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.ndcGreen,
        elevation: 0,
        leading: IconButton(
          icon: const PhosphorIcon(PhosphorIconsRegular.arrowLeft, color: AppColors.ndcWhite, size: 22),
          onPressed: () => context.pop(),
        ),
        title: Text('My Submissions', style: AppTextStyles.appBarTitle()),
        actions: [
          IconButton(
            icon: const PhosphorIcon(PhosphorIconsRegular.arrowCounterClockwise, color: AppColors.ndcWhite, size: 20),
            onPressed: () => _syncOfflineQueue(context, ref),
            tooltip: 'Sync offline',
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(4),
          child: NdcFlagStripe(height: 4),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.ndcGreen,
        foregroundColor: AppColors.ndcWhite,
        icon: const PhosphorIcon(PhosphorIconsFill.userPlus, size: 20),
        label: Text('Register', style: AppTextStyles.bodyMedium(color: AppColors.ndcWhite)),
        onPressed: () => context.push('/register-member'),
      ),
      body: Column(
        children: [
          // Offline queue banner
          if (OfflineQueue.hasItems) _OfflineBanner(count: OfflineQueue.count),

          // Filter tabs
          _FilterTabs(selectedFilter: filter),

          // Member list
          Expanded(
            child: RefreshIndicator(
              color: AppColors.ndcGreen,
              onRefresh: () async => ref.invalidate(mySubmissionsProvider),
              child: membersAsync.when(
                data: (members) => members.isEmpty
                    ? _EmptyState(filter: filter)
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                        itemCount: members.length,
                        itemBuilder: (_, i) => MemberListTile(member: members[i]),
                      ),
                loading: () => _LoadingList(),
                error: (e, _) => _ErrorState(error: e.toString()),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _syncOfflineQueue(BuildContext context, WidgetRef ref) async {
    if (!OfflineQueue.hasItems) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No offline registrations to sync.')),
      );
      return;
    }

    final synced = await OfflineQueue.flush();
    if (!context.mounted) return;

    ref.invalidate(mySubmissionsProvider);
    ref.invalidate(myStatsProvider);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.ndcGreen,
        content: Text(
          synced > 0 ? 'Synced $synced registration${synced == 1 ? '' : 's'}.' : 'Sync failed — check connection.',
          style: AppTextStyles.body(color: AppColors.ndcWhite),
        ),
      ),
    );
  }
}

class _FilterTabs extends ConsumerWidget {
  final String selectedFilter;
  const _FilterTabs({required this.selectedFilter});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filters = [
      ('all', 'All'),
      ('pending', 'Pending'),
      ('active', 'Approved'),
      ('rejected', 'Rejected'),
    ];

    return Container(
      color: AppColors.surface,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: filters.map(((String value, String label) tab) {
            final isSelected = selectedFilter == tab.$1;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () {
                  ref.read(submissionsFilterProvider.notifier).state = tab.$1;
                  ref.read(submissionsPageProvider.notifier).state = 0;
                  ref.invalidate(mySubmissionsProvider);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.ndcGreen : AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    tab.$2,
                    style: AppTextStyles.small(
                      color: isSelected ? AppColors.ndcWhite : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  final int count;
  const _OfflineBanner({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.statusPending,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const PhosphorIcon(PhosphorIconsFill.cloudSlash, size: 16, color: AppColors.ndcWhite),
          const SizedBox(width: 8),
          Text(
            '$count registration${count == 1 ? '' : 's'} queued offline — tap ↺ to sync.',
            style: AppTextStyles.small(color: AppColors.ndcWhite),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String filter;
  const _EmptyState({required this.filter});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const PhosphorIcon(PhosphorIconsRegular.usersThree, size: 56, color: AppColors.textMuted),
            const SizedBox(height: 16),
            Text(
              filter == 'all' ? 'No submissions yet' : 'No ${filter == 'active' ? 'approved' : filter} submissions',
              style: AppTextStyles.h3(),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Members you register will appear here.',
              style: AppTextStyles.body(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 6,
      itemBuilder: (_, __) => const Padding(
        padding: EdgeInsets.only(bottom: 10),
        child: MemberTileSkeleton(),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String error;
  const _ErrorState({required this.error});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const PhosphorIcon(PhosphorIconsFill.warningCircle, size: 40, color: AppColors.ndcRed),
            const SizedBox(height: 12),
            Text('Failed to load submissions', style: AppTextStyles.h3()),
            const SizedBox(height: 8),
            Text(
              'Check your connection and pull down to retry.',
              style: AppTextStyles.body(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
