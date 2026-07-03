import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../application/review_providers.dart';
import '../../data/review_repository.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/theme/app_text_styles.dart';
import '../../../../shared/widgets/ndc_flag_stripe.dart';
import '../../../../shared/widgets/skeleton_loader.dart';
import '../widgets/member_status_badge.dart';

class ReviewQueueScreen extends ConsumerWidget {
  const ReviewQueueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queueAsync = ref.watch(reviewQueueProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.ndcGreen,
        elevation: 0,
        leading: IconButton(
          icon: const PhosphorIcon(PhosphorIconsRegular.arrowLeft, color: AppColors.ndcWhite, size: 22),
          onPressed: () => context.pop(),
        ),
        title: Text('Review Queue', style: AppTextStyles.appBarTitle()),
        actions: [
          IconButton(
            icon: const PhosphorIcon(PhosphorIconsRegular.arrowCounterClockwise, color: AppColors.ndcWhite, size: 20),
            onPressed: () => ref.invalidate(reviewQueueProvider),
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(4),
          child: NdcFlagStripe(height: 4),
        ),
      ),
      body: RefreshIndicator(
        color: AppColors.ndcGreen,
        onRefresh: () async => ref.invalidate(reviewQueueProvider),
        child: queueAsync.when(
          data: (members) => members.isEmpty
              ? const _EmptyQueue()
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  itemCount: members.length,
                  itemBuilder: (_, i) => _ReviewTile(member: members[i]),
                ),
          loading: () => ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: 6,
            itemBuilder: (_, __) => const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: MemberTileSkeleton(),
            ),
          ),
          error: (e, _) => _ErrorState(error: e.toString(), onRetry: () => ref.invalidate(reviewQueueProvider)),
        ),
      ),
    );
  }
}

class _ReviewTile extends ConsumerWidget {
  final MemberDetail member;
  const _ReviewTile({required this.member});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => context.push('/member/${member.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
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
                      Text(member.fullName, style: AppTextStyles.bodyMedium()),
                      const SizedBox(height: 3),
                      Text(member.phone ?? '—', style: AppTextStyles.small()),
                      if (member.constituencyName != null)
                        Text(member.constituencyName!, style: AppTextStyles.caption()),
                    ],
                  ),
                ),
                MemberStatusBadge(status: member.status),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Submitted ${_ago(member.createdAt)}',
              style: AppTextStyles.caption(),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _QuickAction(
                    label: 'Approve',
                    icon: PhosphorIconsFill.checkCircle,
                    color: AppColors.ndcGreen,
                    onTap: () => _confirmApprove(context, ref, member),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _QuickAction(
                    label: 'Reject',
                    icon: PhosphorIconsFill.xCircle,
                    color: AppColors.ndcRed,
                    onTap: () => _showRejectDialog(context, ref, member),
                  ),
                ),
                const SizedBox(width: 10),
                _QuickAction(
                  label: 'View',
                  icon: PhosphorIconsFill.eye,
                  color: AppColors.textSecondary,
                  onTap: () => context.push('/member/${member.id}'),
                ),
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

  Future<void> _confirmApprove(BuildContext context, WidgetRef ref, MemberDetail member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Approve ${member.fullName}?', style: AppTextStyles.h3()),
        content: Text('This will mark the member as active.', style: AppTextStyles.body()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Approve', style: TextStyle(color: AppColors.ndcGreen)),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ReviewRepository().approveMember(member.id);
      HapticFeedback.mediumImpact();
      ref.invalidate(reviewQueueProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.ndcGreen,
            content: Text('${member.fullName} approved.', style: AppTextStyles.body(color: AppColors.ndcWhite)),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _showRejectDialog(BuildContext context, WidgetRef ref, MemberDetail member) async {
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
            TextField(
              controller: ctrl,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'e.g. Duplicate registration, incomplete documents...',
                hintStyle: AppTextStyles.body(color: AppColors.textMuted),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              if (ctrl.text.trim().isEmpty) return;
              Navigator.pop(context, ctrl.text.trim());
            },
            child: Text('Reject', style: TextStyle(color: AppColors.ndcRed)),
          ),
        ],
      ),
    );
    if (reason == null || !context.mounted) return;
    try {
      await ReviewRepository().rejectMember(member.id, reason);
      HapticFeedback.mediumImpact();
      ref.invalidate(reviewQueueProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.ndcRed,
            content: Text('${member.fullName} rejected.', style: AppTextStyles.body(color: AppColors.ndcWhite)),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    }
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
          borderRadius: BorderRadius.circular(8),
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

class _EmptyQueue extends StatelessWidget {
  const _EmptyQueue();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(color: AppColors.greenLight, shape: BoxShape.circle),
            child: const PhosphorIcon(PhosphorIconsFill.checks, size: 36, color: AppColors.ndcGreen),
          ),
          const SizedBox(height: 20),
          Text('All caught up!', style: AppTextStyles.h2()),
          const SizedBox(height: 8),
          Text('No pending registrations to review.', style: AppTextStyles.body(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorState({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const PhosphorIcon(PhosphorIconsFill.warningCircle, size: 40, color: AppColors.ndcRed),
          const SizedBox(height: 12),
          Text('Failed to load queue', style: AppTextStyles.h3()),
          const SizedBox(height: 16),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
