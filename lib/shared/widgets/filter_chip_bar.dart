import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_text_styles.dart';

class FilterChipBar<T> extends StatelessWidget {
  final List<({T value, String label})> chips;
  final T selected;
  final ValueChanged<T> onSelected;

  const FilterChipBar({
    super.key,
    required this.chips,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: chips.map((chip) {
          final isSelected = chip.value == selected;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Semantics(
              label: chip.label,
              selected: isSelected,
              button: true,
              child: SizedBox(
                height: 48, // minimum WCAG touch target
                child: Center(
                  child: InkWell(
                    onTap: () => onSelected(chip.value),
                    borderRadius: AppRadii.borderPill,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.canopyGreen : AppColors.fillMuted,
                        borderRadius: AppRadii.borderPill,
                      ),
                      child: Text(
                        chip.label,
                        style: AppTextStyles.label(
                          color: isSelected ? AppColors.surface : AppColors.ink,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
