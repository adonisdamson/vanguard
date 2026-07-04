import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class LoadMoreButton extends StatelessWidget {
  final VoidCallback onPressed;
  final bool loading;

  const LoadMoreButton({super.key, required this.onPressed, this.loading = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: TextButton.icon(
          onPressed: loading ? null : onPressed,
          icon: loading
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.canopyGreen,
                  ),
                )
              : const PhosphorIcon(PhosphorIconsRegular.arrowDown, size: 16, color: AppColors.canopyGreen),
          label: Text(
            loading ? 'Loading…' : 'Load More',
            style: AppTextStyles.small(color: AppColors.canopyGreen),
          ),
        ),
      ),
    );
  }
}
