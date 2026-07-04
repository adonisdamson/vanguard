import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

// Segmented-canopy arc — the signature brand device.
// A thin band of NDC colors (red / black / green) arcing across the top
// of splash, auth screens, and section headers. Used once per screen.
class CanopyArc extends StatelessWidget {
  final double height;

  const CanopyArc({super.key, this.height = 5});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(999),
        bottomRight: Radius.circular(999),
      ),
      child: SizedBox(
        height: height,
        child: Row(
          children: [
            Expanded(flex: 2, child: ColoredBox(color: AppColors.umbrellaRed)),
            Expanded(flex: 1, child: ColoredBox(color: AppColors.stripeBlack)),
            Expanded(flex: 3, child: ColoredBox(color: AppColors.canopyGreen)),
          ],
        ),
      ),
    );
  }
}

// Flat version (no arc clip) for use in scroll view contexts
class CanopyStripe extends StatelessWidget {
  final double height;

  const CanopyStripe({super.key, this.height = 4});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Row(
        children: [
          Expanded(flex: 2, child: ColoredBox(color: AppColors.umbrellaRed)),
          Expanded(flex: 1, child: ColoredBox(color: AppColors.stripeBlack)),
          Expanded(flex: 3, child: ColoredBox(color: AppColors.canopyGreen)),
        ],
      ),
    );
  }
}
