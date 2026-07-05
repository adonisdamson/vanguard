import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

class AppBottomNav extends StatelessWidget {
  final int currentIndex;
  final List<NavItem> items;
  final ValueChanged<int> onTap;

  const AppBottomNav({
    super.key,
    required this.currentIndex,
    required this.items,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.hairline, width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Row(
            children: List.generate(items.length, (i) {
              final item = items[i];
              final active = i == currentIndex;
              return Expanded(
                child: _NavTab(
                  icon: item.icon,
                  activeIcon: item.activeIcon,
                  label: item.label,
                  active: active,
                  onTap: () => onTap(i),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavTab extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _NavTab({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Top active indicator
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 2,
            width: active ? 24 : 0,
            decoration: BoxDecoration(
              color: AppColors.canopyGreen,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
          const SizedBox(height: 6),
          PhosphorIcon(
            active ? activeIcon : icon,
            size: 22,
            color: active ? AppColors.canopyGreen : AppColors.mist,
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: active
                ? AppTextStyles.navLabelActive()
                : AppTextStyles.navLabel(),
          ),
        ],
      ),
    );
  }
}
