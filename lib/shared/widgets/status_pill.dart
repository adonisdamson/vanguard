import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_text_styles.dart';

enum MemberStatus { pending, active, rejected, suspended }

class StatusPill extends StatelessWidget {
  final MemberStatus status;

  const StatusPill(this.status, {super.key});

  factory StatusPill.fromString(String? s) {
    return StatusPill(switch (s) {
      'active'    => MemberStatus.active,
      'rejected'  => MemberStatus.rejected,
      'suspended' => MemberStatus.suspended,
      _           => MemberStatus.pending,
    });
  }

  @override
  Widget build(BuildContext context) {
    final (bg, fg, label) = switch (status) {
      MemberStatus.pending   => (AppColors.amberTint, AppColors.statusPending,   'Pending'),
      MemberStatus.active    => (AppColors.greenTint, AppColors.statusActive,    'Active'),
      MemberStatus.rejected  => (AppColors.redTint,   AppColors.statusRejected,  'Rejected'),
      MemberStatus.suspended => (AppColors.fillMuted, AppColors.statusSuspended, 'Suspended'),
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
