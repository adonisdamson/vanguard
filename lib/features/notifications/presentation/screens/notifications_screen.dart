import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../application/notification_providers.dart';
import '../../data/notification_repository.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/theme/app_radii.dart';
import '../../../../shared/theme/app_spacing.dart';
import '../../../../shared/theme/app_text_styles.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/inline_load_error.dart';
import '../../../../shared/widgets/skeleton_loader.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(notificationsProvider);

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        backgroundColor: AppColors.deepCanopy,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Back',
          icon: const PhosphorIcon(PhosphorIconsRegular.arrowLeft,
              color: AppColors.surface, size: 22),
          onPressed: () => context.pop(),
        ),
        title: Text('Notifications', style: AppTextStyles.appBarTitle()),
        actions: [
          TextButton(
            onPressed: () async {
              await NotificationRepository().markAllRead();
              ref.invalidate(notificationsProvider);
              ref.invalidate(unreadCountProvider);
            },
            child: Text('Mark all read',
                style: AppTextStyles.label(color: AppColors.surface)),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.brand,
        onRefresh: () async {
          ref.invalidate(notificationsProvider);
          ref.invalidate(unreadCountProvider);
        },
        child: async.when(
          data: (items) {
            if (items.isEmpty) {
              return const EmptyState(
                icon: PhosphorIconsRegular.bellSlash,
                title: 'No notifications yet',
                subtitle:
                    'New registrations and review decisions will appear here.',
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (_, i) => _NotificationTile(
                item: items[i],
                onTap: () async {
                  if (!items[i].read) {
                    await NotificationRepository().markRead(items[i].id);
                    ref.invalidate(notificationsProvider);
                    ref.invalidate(unreadCountProvider);
                  }
                  if (items[i].memberId != null && context.mounted) {
                    context.push('/member/${items[i].memberId}');
                  }
                },
              ),
            );
          },
          loading: () => ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: 6,
            itemBuilder: (_, _) => const Padding(
              padding: EdgeInsets.only(bottom: AppSpacing.sm),
              child: SkeletonLoader(height: 64, borderRadius: AppRadii.borderMd),
            ),
          ),
          error: (_, _) => InlineLoadError(
            message: "Couldn't load notifications",
            onRetry: () => ref.invalidate(notificationsProvider),
          ),
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final AppNotification item;
  final VoidCallback onTap;
  const _NotificationTile({required this.item, required this.onTap});

  (IconData, Color, Color) _visual() => switch (item.type) {
        'member_approved' => (PhosphorIconsFill.checkCircle, AppColors.success, AppColors.brandTint),
        'member_rejected' => (PhosphorIconsFill.xCircle, AppColors.danger, AppColors.redTint),
        _ => (PhosphorIconsFill.userPlus, AppColors.brand, AppColors.brandTint),
      };

  String _ago(DateTime dt) {
    final d = DateTime.now().difference(dt);
    if (d.inDays > 0) return '${d.inDays}d ago';
    if (d.inHours > 0) return '${d.inHours}h ago';
    if (d.inMinutes > 0) return '${d.inMinutes}m ago';
    return 'Just now';
  }

  @override
  Widget build(BuildContext context) {
    final (icon, color, bg) = _visual();
    return Material(
      color: item.read ? AppColors.surface : AppColors.brandTint.withValues(alpha: 0.4),
      borderRadius: AppRadii.borderMd,
      child: InkWell(
        borderRadius: AppRadii.borderMd,
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: AppRadii.borderMd,
            border: Border.all(color: AppColors.line),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(color: bg, borderRadius: AppRadii.borderSm),
                child: Icon(icon, size: 20, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(item.title,
                              style: AppTextStyles.bodyMedium(),
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                        if (!item.read)
                          Container(
                              width: 8, height: 8,
                              decoration: const BoxDecoration(
                                  color: AppColors.brand, shape: BoxShape.circle)),
                      ],
                    ),
                    if (item.body != null) ...[
                      const SizedBox(height: 2),
                      Text(item.body!, style: AppTextStyles.small(),
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                    ],
                    const SizedBox(height: 4),
                    Text(_ago(item.createdAt), style: AppTextStyles.caption()),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
