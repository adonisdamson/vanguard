import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../application/audit_providers.dart';
import '../../data/audit_repository.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/theme/app_text_styles.dart';
import '../../../../shared/widgets/ndc_flag_stripe.dart';
import '../../../../shared/widgets/skeleton_loader.dart';

const _kActions = [
  'member_created',
  'member_status_changed',
  'member_updated',
  'operator_created',
  'role_changed',
  'account_status_changed',
];

class AuditLogScreen extends ConsumerWidget {
  const AuditLogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(auditActionFilterProvider);
    final logAsync = ref.watch(auditLogProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.ndcBlack,
        elevation: 0,
        leading: IconButton(
          icon: const PhosphorIcon(PhosphorIconsRegular.arrowLeft, color: AppColors.ndcWhite, size: 22),
          onPressed: () => context.pop(),
        ),
        title: Text('Audit Log', style: AppTextStyles.appBarTitle()),
        actions: [
          IconButton(
            icon: const PhosphorIcon(PhosphorIconsRegular.arrowCounterClockwise, color: AppColors.ndcWhite, size: 20),
            onPressed: () => ref.invalidate(auditLogProvider),
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(4),
          child: NdcFlagStripe(height: 4),
        ),
      ),
      body: Column(
        children: [
          // Filter chips
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _FilterChip(
                    label: 'All',
                    selected: filter == null,
                    onTap: () {
                      ref.read(auditActionFilterProvider.notifier).state = null;
                      ref.read(auditPageProvider.notifier).state = 0;
                      ref.invalidate(auditLogProvider);
                    },
                  ),
                  ..._kActions.map((action) => Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: _FilterChip(
                          label: _actionLabel(action),
                          selected: filter == action,
                          onTap: () {
                            ref.read(auditActionFilterProvider.notifier).state = action;
                            ref.read(auditPageProvider.notifier).state = 0;
                            ref.invalidate(auditLogProvider);
                          },
                        ),
                      )),
                ],
              ),
            ),
          ),

          // Log entries
          Expanded(
            child: RefreshIndicator(
              color: AppColors.ndcGreen,
              onRefresh: () async => ref.invalidate(auditLogProvider),
              child: logAsync.when(
                data: (entries) => entries.isEmpty
                    ? const _EmptyLog()
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                        itemCount: entries.length,
                        itemBuilder: (_, i) => _AuditTile(entry: entries[i]),
                      ),
                loading: () => ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: 8,
                  itemBuilder: (_, __) => const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: SkeletonLoader(height: 70, borderRadius: BorderRadius.all(Radius.circular(10))),
                  ),
                ),
                error: (e, _) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const PhosphorIcon(PhosphorIconsFill.warningCircle, size: 40, color: AppColors.ndcRed),
                      const SizedBox(height: 12),
                      Text('Failed to load audit log', style: AppTextStyles.h3()),
                      const SizedBox(height: 8),
                      TextButton(onPressed: () => ref.invalidate(auditLogProvider), child: const Text('Retry')),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.ndcGreen : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: AppTextStyles.small(color: selected ? AppColors.ndcWhite : AppColors.textSecondary),
        ),
      ),
    );
  }
}

class _AuditTile extends StatelessWidget {
  final AuditEntry entry;
  const _AuditTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final (icon, color) = _iconForAction(entry.action);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: PhosphorIcon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(_actionLabel(entry.action), style: AppTextStyles.bodyMedium()),
                    ),
                    Text(_timeAgo(entry.createdAt), style: AppTextStyles.caption()),
                  ],
                ),
                const SizedBox(height: 3),
                if (entry.actorName != null)
                  Text('By ${entry.actorName}', style: AppTextStyles.small()),
                if (entry.targetId != null)
                  Text('Target: ${entry.targetTable ?? ''} #${_shortId(entry.targetId!)}',
                      style: AppTextStyles.caption()),
                if (entry.metadata.isNotEmpty) _MetadataTile(metadata: entry.metadata),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _shortId(String id) => id.length > 8 ? '${id.substring(0, 8)}…' : id;

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }

  (IconData, Color) _iconForAction(String action) {
    switch (action) {
      case 'member_created':
        return (PhosphorIconsFill.userPlus, AppColors.ndcGreen);
      case 'member_status_changed':
        return (PhosphorIconsFill.arrowsLeftRight, AppColors.ndcGold);
      case 'member_updated':
        return (PhosphorIconsFill.pencilSimple, AppColors.textSecondary);
      case 'operator_created':
        return (PhosphorIconsFill.userCirclePlus, AppColors.ndcGreen);
      case 'role_changed':
        return (PhosphorIconsFill.shieldStar, AppColors.ndcGold);
      case 'account_status_changed':
        return (PhosphorIconsFill.prohibit, AppColors.ndcRed);
      default:
        return (PhosphorIconsFill.clockCounterClockwise, AppColors.textMuted);
    }
  }
}

class _MetadataTile extends StatelessWidget {
  final Map<String, dynamic> metadata;
  const _MetadataTile({required this.metadata});

  @override
  Widget build(BuildContext context) {
    final parts = metadata.entries
        .where((e) => e.value != null && e.value.toString().isNotEmpty)
        .map((e) => '${e.key}: ${e.value}')
        .join(' · ');
    if (parts.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Text(parts, style: AppTextStyles.caption()),
    );
  }
}

class _EmptyLog extends StatelessWidget {
  const _EmptyLog();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const PhosphorIcon(PhosphorIconsRegular.scroll, size: 48, color: AppColors.textMuted),
          const SizedBox(height: 16),
          Text('No audit events', style: AppTextStyles.h3()),
          const SizedBox(height: 8),
          Text('System activity will appear here as operators use the app.',
              style: AppTextStyles.body(color: AppColors.textSecondary),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

String _actionLabel(String action) {
  switch (action) {
    case 'member_created':
      return 'Member Created';
    case 'member_status_changed':
      return 'Status Changed';
    case 'member_updated':
      return 'Member Updated';
    case 'operator_created':
      return 'Operator Created';
    case 'role_changed':
      return 'Role Changed';
    case 'account_status_changed':
      return 'Account Status Changed';
    default:
      return action.replaceAll('_', ' ').toUpperCase();
  }
}
