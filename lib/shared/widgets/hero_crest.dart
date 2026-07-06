import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// The NDC strength emblem — a circular crest anchored at the top-right of
/// the greeting hero. Deliberately a contained badge, not a full-bleed
/// background: the band stays calm, the crest carries the identity.
class HeroCrest extends StatelessWidget {
  final double size;

  const HeroCrest({super.key, this.size = 68});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
            color: AppColors.surface.withValues(alpha: 0.35), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipOval(
        child: Image.asset('assets/images/ndc_strength.png', fit: BoxFit.cover),
      ),
    );
  }
}
