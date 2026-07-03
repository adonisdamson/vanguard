import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class NdcFlagStripe extends StatelessWidget {
  final double height;

  const NdcFlagStripe({super.key, this.height = 5});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Row(
        children: [
          Expanded(child: ColoredBox(color: AppColors.stripeBlack)),
          Expanded(child: ColoredBox(color: AppColors.stripeRed)),
          Expanded(child: ColoredBox(color: AppColors.stripeWhite)),
          Expanded(child: ColoredBox(color: AppColors.stripeGreen)),
        ],
      ),
    );
  }
}
