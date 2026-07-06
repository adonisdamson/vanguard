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
    // LOCKED: outlined pill, colored text — never a filled pastel chip.
    final (fg, label) = switch (status) {
      MemberStatus.pending   => (AppColors.warning, 'Pending'),
      MemberStatus.active    => (AppColors.success, 'Active'),
      MemberStatus.rejected  => (AppColors.danger,  'Rejected'),
      MemberStatus.suspended => (AppColors.inkMuted, 'Suspended'),
    };

    return Semantics(
      label: 'Status: $label',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadii.borderPill,
          border: Border.all(color: fg.withValues(alpha: 0.45)),
        ),
        child: ExcludeSemantics(
          child: Text(label, style: AppTextStyles.badge(color: fg)),
        ),
      ),
    );
  }
}
