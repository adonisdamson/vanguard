import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class AppTabBar extends StatelessWidget implements PreferredSizeWidget {
  final TabController controller;
  final List<String> tabs;

  const AppTabBar({
    super.key,
    required this.controller,
    required this.tabs,
  });

  @override
  Size get preferredSize => const Size.fromHeight(48);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      child: TabBar(
        controller: controller,
        tabs: tabs.map((t) => Tab(text: t)).toList(),
        labelStyle: AppTextStyles.title(color: AppColors.ink),
        unselectedLabelStyle: AppTextStyles.body(color: AppColors.mist),
        labelColor: AppColors.ink,
        unselectedLabelColor: AppColors.mist,
        indicatorColor: AppColors.canopyGreen,
        indicatorWeight: 3,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: AppColors.hairline,
        dividerHeight: 1,
        splashBorderRadius: BorderRadius.circular(4),
      ),
    );
  }
}
