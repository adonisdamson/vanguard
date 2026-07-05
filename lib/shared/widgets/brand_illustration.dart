import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/app_colors.dart';

class BrandIllustration extends StatelessWidget {
  final String asset;
  final double size;

  const BrandIllustration(this.asset, {this.size = 160, super.key});

  @override
  Widget build(BuildContext context) {
    if (asset.endsWith('.svg')) {
      return SvgPicture.asset(asset, width: size, height: size, fit: BoxFit.contain);
    }
    final dpr = MediaQuery.of(context).devicePixelRatio;
    return Image.asset(
      asset,
      width: size,
      height: size,
      fit: BoxFit.contain,
      cacheWidth: (size * dpr).round(),
    );
  }
}

// Wraps BrandIllustration in a paper-colored container when the parent
// background is not paper (e.g. white Surface cards, green headers).
class BrandIllustrationOnCard extends StatelessWidget {
  final String asset;
  final double size;
  final double borderRadius;

  const BrandIllustrationOnCard(
    this.asset, {
    this.size = 160,
    this.borderRadius = 16,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: BrandIllustration(asset, size: size),
    );
  }
}
