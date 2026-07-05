import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'brand_illustration.dart';
import 'ndc_button.dart';

class EmptyState extends StatelessWidget {
  final IconData? icon;
  final String? illustrationAsset;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    this.icon,
    this.illustrationAsset,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  }) : assert(icon != null || illustrationAsset != null,
            'Provide either icon or illustrationAsset');

  // ── Named constructors ────────────────────────────────────────────────────

  const EmptyState.noMembers({super.key, VoidCallback? onRegister})
      : icon = null,
        illustrationAsset = 'assets/illustrations/empty_no_members.png',
        title = 'No members yet',
        subtitle = 'Registered members appear here. Start by adding one.',
        actionLabel = 'Register member',
        onAction = onRegister;

  const EmptyState.noSearchResults({super.key, String query = ''})
      : icon = null,
        illustrationAsset = 'assets/illustrations/empty_no_results.png',
        title = 'No matches found',
        subtitle = 'Check the spelling or try a phone number or member ID.',
        actionLabel = null,
        onAction = null;

  const EmptyState.reviewQueueEmpty({super.key})
      : icon = null,
        illustrationAsset = 'assets/illustrations/empty_no_pending.png',
        title = "You're all caught up",
        subtitle = 'No registrations waiting for review.',
        actionLabel = null,
        onAction = null;

  const EmptyState.chooseConstituency({super.key})
      : icon = null,
        illustrationAsset = 'assets/illustrations/empty_choose_constituency.png',
        title = 'Choose a constituency',
        subtitle = 'Polling stations show once you pick a constituency above.',
        actionLabel = null,
        onAction = null;

  const EmptyState.noPendingOperators({super.key})
      : icon = null,
        illustrationAsset = 'assets/illustrations/empty_no_pending.png',
        title = 'No pending requests',
        subtitle = 'New sign-ups waiting for approval will show here.',
        actionLabel = null,
        onAction = null;

  const EmptyState.offline({super.key, VoidCallback? onRetry})
      : icon = null,
        illustrationAsset = 'assets/illustrations/empty_offline.png',
        title = 'No connection',
        subtitle = 'Check your signal. Any pending registrations are saved and will sync when you reconnect.',
        actionLabel = 'Retry',
        onAction = onRetry;

  const EmptyState.noRegions({super.key, VoidCallback? onAdd})
      : icon = null,
        illustrationAsset = 'assets/illustrations/empty_polling.svg',
        title = 'No regions yet',
        subtitle = "Add Ghana's regions to start building the location list.",
        actionLabel = 'Add region',
        onAction = onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildGraphic(context),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTextStyles.h2(),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: AppTextStyles.body(color: AppColors.mist),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 24),
              SizedBox(
                width: 200,
                child: NdcButton(
                  label: actionLabel!,
                  onPressed: onAction,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildGraphic(BuildContext context) {
    if (illustrationAsset != null) {
      return BrandIllustration(illustrationAsset!, size: 160);
    }
    return Container(
      width: 72,
      height: 72,
      decoration: const BoxDecoration(
        color: AppColors.fillMuted,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 32, color: AppColors.mist),
    );
  }
}
