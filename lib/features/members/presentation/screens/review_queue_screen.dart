import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../data/review_repository.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/theme/app_radii.dart';
import '../../../../shared/theme/app_shadows.dart';
import '../../../../shared/theme/app_spacing.dart';
import '../../../../shared/theme/app_text_styles.dart';
import '../../../../shared/widgets/canopy_arc.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/load_more_button.dart';
import '../../../../shared/widgets/skeleton_loader.dart';
import '../../../../shared/widgets/status_pill.dart';

class ReviewQueueScreen extends ConsumerStatefulWidget {
  const ReviewQueueScreen({super.key});

  @override
  ConsumerState<ReviewQueueScreen> createState() => _ReviewQueueScreenState();
}

class _ReviewQueueScreenState extends ConsumerState<ReviewQueueScreen> {
  static const _pageSize = 20;
  final List<MemberDetail> _items = [];
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
    setState(() {
      if (page == 0) { _loading = true; _error = null; }
      else { _loadingMore = true; }
    });
    try {
      final items = await ReviewRepository().fetchPendingMembers(page: page, pageSize: _pageSize);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        backgroundColor: AppColors.deepCanopy,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Back',
          icon: const PhosphorIcon(PhosphorIconsRegular.arrowLeft, color: AppColors.surface, size: 22),
          onPressed: () => context.pop(),
        ),
        title: Text('Review queue', style: AppTextStyles.appBarTitle()),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const PhosphorIcon(PhosphorIconsRegular.arrowCounterClockwise, color: AppColors.surface, size: 20),
            onPressed: () => _loadPage(0),
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(4),
          child: CanopyStripe(height: 4),
        ),
      ),
      body: RefreshIndicator(
        color: AppColors.canopyGreen,
        onRefresh: () => _loadPage(0),
        child: _buildBody(),
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
      return EmptyState.offline(onRetry: () => _loadPage(0));
    }
    if (_items.isEmpty) return const EmptyState.reviewQueueEmpty();

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: _items.length + (_hasMore ? 1 : 0),
      itemBuilder: (_, i) {
        if (i == _items.length) {
          return LoadMoreButton(loading: _loadingMore, onPressed: () => _loadPage(_page + 1));
        }
        return _ReviewTile(
          member: _items[i],
          onChanged: () => _loadPage(0),
        );
      },
    );
  }
}

class _ReviewTile extends StatelessWidget {
  final MemberDetail member;
  final VoidCallback onChanged;

  const _ReviewTile({required this.member, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/member/${member.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(member.fullName, style: AppTextStyles.title(), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 3),
                      Text(member.phone ?? '—', style: AppTextStyles.small()),
                      if (member.constituencyName != null)
                        Text(member.constituencyName!, style: AppTextStyles.caption(), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                StatusPill.fromString(member.status),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text('Submitted ${_ago(member.createdAt)}', style: AppTextStyles.caption()),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(child: _QuickAction(label: 'Approve', icon: PhosphorIconsRegular.checkCircle, color: AppColors.canopyGreen, onTap: () => _confirmApprove(context, member, onChanged))),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: _QuickAction(label: 'Reject', icon: PhosphorIconsRegular.xCircle, color: AppColors.umbrellaRed, onTap: () => _showRejectDialog(context, member, onChanged))),
                const SizedBox(width: AppSpacing.sm),
                _QuickAction(label: 'View', icon: PhosphorIconsRegular.eye, color: AppColors.mist, onTap: () => context.push('/member/${member.id}')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _ago(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    return '${diff.inMinutes}m ago';
  }
}

Future<void> _confirmApprove(BuildContext context, MemberDetail member, VoidCallback onChanged) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text('Approve ${member.fullName}?', style: AppTextStyles.h3()),
      content: Text('This will mark the member as active.', style: AppTextStyles.body()),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(context, true), child: Text('Approve', style: TextStyle(color: AppColors.canopyGreen))),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;
  try {
    await ReviewRepository().approveMember(member.id);
    HapticFeedback.mediumImpact();
    onChanged();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: AppColors.canopyGreen,
        content: Text('${member.fullName} approved.', style: AppTextStyles.body(color: AppColors.surface)),
      ));
    }
  } catch (e) {
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
  }
}

Future<void> _showRejectDialog(BuildContext context, MemberDetail member, VoidCallback onChanged) async {
  final ctrl = TextEditingController();
  final reason = await showDialog<String>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text('Reject ${member.fullName}?', style: AppTextStyles.h3()),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Provide a reason (required):', style: AppTextStyles.body()),
          const SizedBox(height: 10),
          TextField(controller: ctrl, maxLines: 3, autofocus: true,
            decoration: InputDecoration(hintText: 'e.g. Duplicate registration…', hintStyle: AppTextStyles.body(color: AppColors.textMuted))),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        TextButton(
          onPressed: () { if (ctrl.text.trim().isEmpty) return; Navigator.pop(context, ctrl.text.trim()); },
          child: Text('Reject', style: TextStyle(color: AppColors.umbrellaRed)),
        ),
      ],
    ),
  );
  if (reason == null || !context.mounted) return;
  try {
    await ReviewRepository().rejectMember(member.id, reason);
    HapticFeedback.mediumImpact();
    onChanged();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: AppColors.umbrellaRed,
        content: Text('${member.fullName} rejected.', style: AppTextStyles.body(color: AppColors.surface)),
      ));
    }
  } catch (e) {
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
  }
}

class _QuickAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _QuickAction({required this.label, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: AppRadii.borderSm,
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            PhosphorIcon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(label, style: AppTextStyles.small(color: color)),
          ],
        ),
      ),
    );
  }
}

