import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_shadows.dart';
import '../theme/app_text_styles.dart';

class StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color iconColor;
  final Color iconBg;
  final String? delta;

  const StatCard({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    this.iconColor = AppColors.canopyGreen,
    this.iconBg = AppColors.greenTint,
    this.delta,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.borderMd,
        boxShadow: AppShadows.e1,
        border: Border.all(color: AppColors.hairline, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: AppRadii.borderSm,
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(height: 12),
          Text(value, style: AppTextStyles.statNumber(color: AppColors.ink)),
          const SizedBox(height: 2),
          Text(label, style: AppTextStyles.label()),
          if (delta != null) ...[
            const SizedBox(height: 4),
            Text(delta!, style: AppTextStyles.caption()),
          ],
        ],
      ),
    );
  }
}
