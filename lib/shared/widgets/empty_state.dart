import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'ndc_button.dart';

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  // ── Named constructors for each app empty state ────────────────────────────

  const EmptyState.noMembers({super.key, VoidCallback? onRegister})
      : icon = PhosphorIconsRegular.users,
        title = 'No members yet',
        subtitle = 'Registered members appear here. Start by adding one.',
        actionLabel = 'Register member',
        onAction = onRegister;

  const EmptyState.noSearchResults({super.key, String query = ''})
      : icon = PhosphorIconsRegular.magnifyingGlass,
        title = 'No matches found',
        subtitle = 'Check the spelling or try a phone number or member ID.',
        actionLabel = null,
        onAction = null;

  const EmptyState.reviewQueueEmpty({super.key})
      : icon = PhosphorIconsRegular.checkCircle,
        title = "You're all caught up",
        subtitle = 'No registrations waiting for review.',
        actionLabel = null,
        onAction = null;

  const EmptyState.chooseConstituency({super.key})
      : icon = PhosphorIconsRegular.mapPin,
        title = 'Choose a constituency',
        subtitle = 'Polling stations show once you pick a constituency above.',
        actionLabel = null,
        onAction = null;

  const EmptyState.noRegions({super.key, VoidCallback? onAdd})
      : icon = PhosphorIconsRegular.mapTrifold,
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
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: AppColors.fillMuted,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 32, color: AppColors.mist),
            ),
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
}
