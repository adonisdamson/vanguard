import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_text_styles.dart';

class HeroSummaryItem {
  final IconData icon;
  final String value;
  final String label;
  final Color? accent; // number color; defaults to white

  const HeroSummaryItem({
    required this.icon,
    required this.value,
    required this.label,
    this.accent,
  });
}

/// The glass panel inside the greeting hero. One deliberate design used by
/// all three role homes: frosted fill, crisp inner divider, icon + big
/// number + quiet label per segment. Optional onTap on the whole card.
class HeroSummaryCard extends StatelessWidget {
  final List<HeroSummaryItem> items;
  final VoidCallback? onTap;

  const HeroSummaryCard({super.key, required this.items, this.onTap});

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.12),
        borderRadius: AppRadii.borderLg,
        border: Border.all(color: AppColors.surface.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0)
              Container(
                width: 1,
                height: 40,
                color: AppColors.surface.withValues(alpha: 0.18),
                margin: const EdgeInsets.symmetric(horizontal: 16),
              ),
            Expanded(child: _Segment(item: items[i])),
          ],
          if (onTap != null)
            PhosphorIcon(PhosphorIconsRegular.caretRight,
                size: 16, color: AppColors.surface.withValues(alpha: 0.55)),
        ],
      ),
    );
    if (onTap == null) return card;
    return GestureDetector(onTap: onTap, child: card);
  }
}

class _Segment extends StatelessWidget {
  final HeroSummaryItem item;
  const _Segment({required this.item});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.14),
            borderRadius: AppRadii.borderSm,
          ),
          child: PhosphorIcon(item.icon,
              size: 17, color: AppColors.surface.withValues(alpha: 0.9)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(item.value,
                  style: AppTextStyles.h1(
                      color: item.accent ?? AppColors.surface)),
              Text(item.label,
                  style: AppTextStyles.caption(
                      color: AppColors.surface.withValues(alpha: 0.65)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ],
    );
  }
}
