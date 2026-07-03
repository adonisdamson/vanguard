import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../application/member_providers.dart';
import '../../application/offline_queue.dart';
import '../../data/member_repository.dart';
import '../../../../features/auth/application/auth_provider.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/theme/app_text_styles.dart';
import '../../../../shared/widgets/load_more_button.dart';
import '../../../../shared/widgets/ndc_flag_stripe.dart';
import '../../../../shared/widgets/skeleton_loader.dart';
import '../widgets/member_list_tile.dart';

class MySubmissionsScreen extends ConsumerStatefulWidget {
  const MySubmissionsScreen({super.key});

  @override
  ConsumerState<MySubmissionsScreen> createState() => _MySubmissionsScreenState();
}

class _MySubmissionsScreenState extends ConsumerState<MySubmissionsScreen> {
  static const _pageSize = 20;
  final List<MemberSummary> _items = [];
  int _page = 0;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPage(0);
  }

  Future<void> _loadPage(int page) async {
    if (!mounted) return;
    final session = ref.read(currentSessionProvider);
    if (session == null) return;

    setState(() {
      if (page == 0) { _loading = true; _error = null; }
      else _loadingMore = true;
    });

    try {
      final filter = ref.read(submissionsFilterProvider);
      final items = await MemberRepository().fetchMySubmissions(
        userId: session.user.id,
        page: page,
        statusFilter: filter,
        pageSize: _pageSize,
      );
      if (!mounted) return;
      setState(() {
        if (page == 0) _items.clear();
        _items.addAll(items);
        _page = page;
        _hasMore = items.length == _pageSize;
        _loading = false;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; _loadingMore = false; });
    }
  }

  Future<void> _refresh() async => _loadPage(0);

  Future<void> _syncOfflineQueue() async {
    if (!OfflineQueue.hasItems) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No offline registrations to sync.')),
      );
      return;
    }
    final synced = await OfflineQueue.flush();
    if (!mounted) return;
    ref.invalidate(myStatsProvider);
    await _refresh();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: AppColors.ndcGreen,
      content: Text(
        synced > 0 ? 'Synced $synced registration${synced == 1 ? '' : 's'}.' : 'Sync failed — check connection.',
        style: AppTextStyles.body(color: AppColors.ndcWhite),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(submissionsFilterProvider);

    // Reload when filter changes
    ref.listen(submissionsFilterProvider, (_, __) => _loadPage(0));

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
            onPressed: _syncOfflineQueue,
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
          if (OfflineQueue.hasItems) _OfflineBanner(count: OfflineQueue.count),
          _FilterTabs(selectedFilter: filter),
          Expanded(
            child: RefreshIndicator(
              color: AppColors.ndcGreen,
              onRefresh: _refresh,
              child: _buildBody(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 6,
        itemBuilder: (_, __) => const Padding(
          padding: EdgeInsets.only(bottom: 10),
          child: MemberTileSkeleton(),
        ),
      );
    }
    if (_error != null && _items.isEmpty) {
      return _ErrorState(onRetry: _refresh);
    }
    if (_items.isEmpty) {
      return _EmptyState(filter: ref.read(submissionsFilterProvider));
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
      itemCount: _items.length + (_hasMore ? 1 : 0),
      itemBuilder: (_, i) {
        if (i == _items.length) {
          return LoadMoreButton(
            loading: _loadingMore,
            onPressed: () => _loadPage(_page + 1),
          );
        }
        return MemberListTile(member: _items[i]);
      },
    );
  }
}

class _FilterTabs extends ConsumerWidget {
  final String selectedFilter;
  const _FilterTabs({required this.selectedFilter});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const filters = [('all', 'All'), ('pending', 'Pending'), ('active', 'Approved'), ('rejected', 'Rejected')];

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
                onTap: () => ref.read(submissionsFilterProvider.notifier).state = tab.$1,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.ndcGreen : AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    tab.$2,
                    style: AppTextStyles.small(color: isSelected ? AppColors.ndcWhite : AppColors.textSecondary),
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
          Expanded(
            child: Text(
              '$count registration${count == 1 ? '' : 's'} queued offline — tap ↺ to sync.',
              style: AppTextStyles.small(color: AppColors.ndcWhite),
            ),
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

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const PhosphorIcon(PhosphorIconsFill.wifiSlash, size: 40, color: AppColors.ndcRed),
            const SizedBox(height: 12),
            Text('Failed to load submissions', style: AppTextStyles.h3()),
            const SizedBox(height: 8),
            Text(
              'Check your connection and pull down to retry.',
              style: AppTextStyles.body(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
