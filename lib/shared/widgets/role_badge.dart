import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_text_styles.dart';

/// Role badge — LOCKED mapping, identical wherever a role appears:
///   Admin       → neutral/900 text on neutral/100 pill
///   Coordinator → white text on near-black pill (crisp, professional)
///   Personnel   → neutral/600 text on neutral/100 pill
/// Status colors (warning/success/danger) are NEVER used for roles.
class RoleBadge extends StatelessWidget {
  final String role; // 'admin' | 'higher_authority' | 'personnel'

  const RoleBadge(this.role, {super.key});

  @override
  Widget build(BuildContext context) {
    final (fg, bg, label) = switch (role) {
      'admin'            => (AppColors.ink, AppColors.fillMuted, 'Admin'),
      'higher_authority' => (AppColors.surface, AppColors.ink, 'Coordinator'),
      _                  => (AppColors.inkMuted, AppColors.fillMuted, 'Personnel'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: AppRadii.borderPill,
      ),
      child: Text(label, style: AppTextStyles.badge(color: fg)),
    );
  }
}
