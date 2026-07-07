import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../application/notification_providers.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/theme/app_text_styles.dart';

/// App-bar bell with an unread-count badge. Opens the notifications inbox.
/// Refreshes the count when returning from the inbox.
class NotificationBell extends ConsumerWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadCountProvider).valueOrNull ?? 0;
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: IconButton(
        tooltip: 'Notifications',
        icon: Stack(
          clipBehavior: Clip.none,
          children: [
            const PhosphorIcon(PhosphorIconsRegular.bell,
                color: AppColors.surface, size: 22),
            if (unread > 0)
              Positioned(
                right: -5,
                top: -4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  constraints: const BoxConstraints(minWidth: 16),
                  decoration: BoxDecoration(
                    color: AppColors.danger,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.deepCanopy, width: 1.5),
                  ),
                  child: Text(
                    unread > 9 ? '9+' : '$unread',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.caption(color: AppColors.surface)
                        .copyWith(fontSize: 9.5, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
          ],
        ),
        onPressed: () async {
          await context.push('/notifications');
          ref.invalidate(unreadCountProvider);
        },
      ),
    );
  }
}
