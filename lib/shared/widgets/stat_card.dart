import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_text_styles.dart';

/// Stat tile — number-first, flat.
/// LOCKED (design pass 2): no tinted icon badge above the number. Large H1
/// number, Label beneath in neutral/600, 1px border, no shadow. The icon is
/// a single small neutral glyph inline next to the label.
class StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  // Kept for call-site compatibility; tinted boxes are gone by design.
  final Color iconColor;
  final Color iconBg;
  final String? delta;

  const StatCard({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    this.iconColor = AppColors.inkMuted,
    this.iconBg = AppColors.brandTint,
    this.delta,
  });

  @override
  Widget build(BuildContext context) {
    final semanticLabel = delta != null ? '$label: $value, $delta' : '$label: $value';
    return Semantics(
      label: semanticLabel,
      child: ExcludeSemantics(child: _card()),
    );
  }

  Widget _card() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.borderMd,
        border: Border.all(color: AppColors.line, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value, style: AppTextStyles.h1()),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(icon, color: AppColors.inkMuted, size: 14),
              const SizedBox(width: 5),
              Expanded(
                child: Text(label,
                    style: AppTextStyles.label(color: AppColors.inkMuted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          if (delta != null) ...[
            const SizedBox(height: 4),
            Text(delta!, style: AppTextStyles.caption()),
          ],
        ],
      ),
    );
  }
}

/// Replaces a row of bare-zero stat tiles before any real data exists.
class EmptyStatsNote extends StatelessWidget {
  final IconData icon;
  final String message;

  const EmptyStatsNote({super.key, required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.borderMd,
        border: Border.all(color: AppColors.line, width: 1),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.inkMuted),
          const SizedBox(width: 12),
          Expanded(
            child: Text(message,
                style: AppTextStyles.body(color: AppColors.inkMuted)),
          ),
        ],
      ),
    );
  }
}
