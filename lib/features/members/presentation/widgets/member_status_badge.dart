import 'package:flutter/material.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/theme/app_text_styles.dart';

class MemberStatusBadge extends StatelessWidget {
  final String status;
  const MemberStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = _config(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: AppTextStyles.badge(color: fg)),
    );
  }

  static (String, Color, Color) _config(String status) {
    return switch (status) {
      'pending' => ('Pending', AppColors.pendingBg, AppColors.statusPending),
      'active' => ('Active', AppColors.activeBg, AppColors.statusActive),
      'rejected' => ('Rejected', AppColors.rejectedBg, AppColors.statusRejected),
      'suspended' => ('Suspended', AppColors.suspendedBg, AppColors.statusSuspended),
      _ => ('Unknown', AppColors.surfaceVariant, AppColors.textMuted),
    };
  }
}
