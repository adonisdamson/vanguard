import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_text_styles.dart';

/// Compact in-place failure state for a section that failed to load.
/// Replaces the old SizedBox.shrink() error branches, which made data loss
/// look like an intentionally empty UI.
class InlineLoadError extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const InlineLoadError({
    super.key,
    this.message = "Couldn't load this section",
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.borderMd,
        border: Border.all(color: AppColors.hairline),
      ),
      child: Row(
        children: [
          const PhosphorIcon(PhosphorIconsRegular.warningCircle,
              size: 18, color: AppColors.umbrellaRed),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              onRetry == null ? '$message — pull down to refresh.' : message,
              style: AppTextStyles.small(color: AppColors.textSecondary),
            ),
          ),
          if (onRetry != null)
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text('Retry',
                  style: AppTextStyles.label(color: AppColors.canopyGreen)),
            ),
        ],
      ),
    );
  }
}
