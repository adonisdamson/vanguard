import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_shadows.dart';
import '../theme/app_text_styles.dart';

class AppListTile extends StatelessWidget {
  final IconData leadingIcon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final EdgeInsets? margin;

  const AppListTile({
    super.key,
    required this.leadingIcon,
    this.iconColor = AppColors.canopyGreen,
    this.iconBg = AppColors.greenTint,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin ?? const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.borderMd,
        boxShadow: AppShadows.e1,
        border: Border.all(color: AppColors.hairline, width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: AppRadii.borderMd,
        child: InkWell(
          borderRadius: AppRadii.borderMd,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: AppRadii.borderSm,
                  ),
                  child: Icon(leadingIcon, color: iconColor, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTextStyles.title(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          style: AppTextStyles.body(color: AppColors.mist),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                trailing ??
                    const PhosphorIcon(
                      PhosphorIconsRegular.caretRight,
                      size: 16,
                      color: AppColors.mist,
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
