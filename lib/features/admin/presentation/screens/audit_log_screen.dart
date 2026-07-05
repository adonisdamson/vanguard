import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../../core/errors/app_error_mapper.dart';
import '../../data/audit_repository.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/theme/app_radii.dart';
import '../../../../shared/theme/app_shadows.dart';
import '../../../../shared/theme/app_spacing.dart';
import '../../../../shared/theme/app_text_styles.dart';
import '../../../../shared/widgets/canopy_arc.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/load_more_button.dart';
import '../../../../shared/widgets/skeleton_loader.dart';

const _kActions = [
  'member_created',
  'member_status_changed',
  'member_updated',
  'operator_created',
  'role_changed',
  'account_status_changed',
];

class AuditLogScreen extends ConsumerStatefulWidget {
  const AuditLogScreen({super.key});

  @override
  ConsumerState<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends ConsumerState<AuditLogScreen> {
  static const _pageSize = 25;
  final List<AuditEntry> _items = [];
  String? _filter;
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
      final items = await AuditRepository().fetchAuditLog(page: page, actionFilter: _filter, pageSize: _pageSize);
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
      setState(() { _error = AppErrorMapper.forDataLoad(e); _loading = false; _loadingMore = false; });
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
        title: Text('Audit log', style: AppTextStyles.appBarTitle()),
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
      body: Column(
        children: [
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _FilterChip(
                    label: 'All',
                    selected: _filter == null,
                    onTap: () { setState(() => _filter = null); _loadPage(0); },
                  ),
                  ..._kActions.map((action) => Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: _FilterChip(
                          label: _actionLabel(action),
                          selected: _filter == action,
                          onTap: () { setState(() => _filter = action); _loadPage(0); },
                        ),
                      )),
                ],
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              color: AppColors.canopyGreen,
              onRefresh: () => _loadPage(0),
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
        itemCount: 8,
        itemBuilder: (_, _) => const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: SkeletonLoader(height: 70, borderRadius: BorderRadius.all(Radius.circular(10))),
        ),
      );
    }
    if (_error != null && _items.isEmpty) {
      return EmptyState.offline(onRetry: () => _loadPage(0));
    }
    if (_items.isEmpty) return const EmptyState(icon: PhosphorIconsRegular.scroll, title: 'No audit events', subtitle: 'System activity will appear here as operators use the app.');

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: _items.length + (_hasMore ? 1 : 0),
      itemBuilder: (_, i) {
        if (i == _items.length) {
          return LoadMoreButton(loading: _loadingMore, onPressed: () => _loadPage(_page + 1));
        }
        return _AuditTile(entry: _items[i]);
      },
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
          color: selected ? AppColors.canopyGreen : AppColors.fillMuted,
          borderRadius: AppRadii.borderPill,
        ),
        child: Text(label, style: AppTextStyles.small(color: selected ? AppColors.surface : AppColors.mist)),
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
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.borderMd,
        boxShadow: AppShadows.e1,
        border: Border.all(color: AppColors.hairline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: AppRadii.borderSm),
            child: PhosphorIcon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(_actionLabel(entry.action), style: AppTextStyles.bodyMedium())),
                    Text(_timeAgo(entry.createdAt), style: AppTextStyles.caption()),
                  ],
                ),
                const SizedBox(height: 3),
                if (entry.actorName != null) Text('By ${entry.actorName}', style: AppTextStyles.small()),
                if (entry.targetId != null)
                  Text('Target: ${entry.targetTable ?? ''} #${_shortId(entry.targetId!)}', style: AppTextStyles.caption()),
                if (entry.metadata.isNotEmpty) _MetadataLine(action: entry.action, metadata: entry.metadata),
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
      case 'member_created': return (PhosphorIconsRegular.userPlus, AppColors.canopyGreen);
      case 'member_status_changed': return (PhosphorIconsRegular.arrowsLeftRight, AppColors.statusPending);
      case 'member_updated': return (PhosphorIconsRegular.pencilSimple, AppColors.mist);
      case 'operator_created': return (PhosphorIconsRegular.userCirclePlus, AppColors.canopyGreen);
      case 'role_changed': return (PhosphorIconsRegular.shieldStar, AppColors.statusPending);
      case 'account_status_changed': return (PhosphorIconsRegular.prohibit, AppColors.umbrellaRed);
      default: return (PhosphorIconsRegular.clockCounterClockwise, AppColors.mist);
    }
  }
}

class _MetadataLine extends StatelessWidget {
  final String action;
  final Map<String, dynamic> metadata;
  const _MetadataLine({required this.action, required this.metadata});

  String? _toHuman() {
    switch (action) {
      case 'member_status_changed':
        final oldS = metadata['old_status'] as String? ?? '';
        final newS = metadata['new_status'] as String? ?? '';
        final reason = metadata['reason'] as String?;
        if (newS == 'active') return '${_statusLabel(oldS)} → Approved';
        if (newS == 'rejected') {
          final base = '${_statusLabel(oldS)} → Rejected';
          return reason != null && reason.isNotEmpty ? '$base: $reason' : base;
        }
        return '${_statusLabel(oldS)} → ${_statusLabel(newS)}';
      case 'role_changed':
        final old = metadata['old_role'] as String?;
        final next = metadata['new_role'] as String?;
        if (old != null && next != null) return '${_roleLabel(old)} → ${_roleLabel(next)}';
        return null;
      case 'account_status_changed':
        final active = metadata['is_active'];
        if (active == true) return 'Account reactivated';
        if (active == false) return 'Account suspended';
        return null;
      case 'operator_created':
        final role = metadata['role'] as String?;
        return role != null ? 'Assigned as ${_roleLabel(role)}' : null;
      default:
        return null;
    }
  }

  static String _statusLabel(String s) => switch (s) {
    'active' => 'Approved',
    'pending' => 'Pending',
    'rejected' => 'Rejected',
    'suspended' => 'Suspended',
    _ => s,
  };

  static String _roleLabel(String r) => switch (r) {
    'admin' => 'Administrator',
    'higher_authority' => 'Coordinator',
    'personnel' => 'Personnel',
    _ => r,
  };

  @override
  Widget build(BuildContext context) {
    final text = _toHuman();
    if (text == null || text.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 3), // intentional: tight metadata label nudge
      child: Text(text, style: AppTextStyles.caption(color: AppColors.mist)),
    );
  }
}


String _actionLabel(String action) {
  return switch (action) {
    'member_created' => 'Member registered',
    'member_status_changed' => 'Status changed',
    'member_updated' => 'Member updated',
    'operator_created' => 'Operator created',
    'role_changed' => 'Role changed',
    'account_status_changed' => 'Account status changed',
    _ => action.replaceAll('_', ' '),
  };
}
