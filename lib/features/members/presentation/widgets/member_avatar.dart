import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../application/member_providers.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/theme/app_radii.dart';

/// The one member avatar for list rows: real photo via a signed URL when
/// photo_path exists, otherwise the single app-wide fallback style
/// (greenTint square + canopyGreen person icon). Never per-screen variants.
class MemberAvatar extends ConsumerWidget {
  final String? photoPath;
  final double size;

  const MemberAvatar({super.key, required this.photoPath, this.size = 44});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (photoPath == null || photoPath!.isEmpty) return _fallback();

    final urlAsync = ref.watch(photoUrlProvider(photoPath!));
    return urlAsync.when(
      data: (url) => url == null
          ? _fallback()
          : ClipRRect(
              borderRadius: AppRadii.borderSm,
              child: CachedNetworkImage(
                imageUrl: url,
                width: size,
                height: size,
                fit: BoxFit.cover,
                placeholder: (_, _) => _fallback(),
                errorWidget: (_, _, _) => _fallback(),
              ),
            ),
      loading: _fallback,
      error: (_, _) => _fallback(),
    );
  }

  Widget _fallback() => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppColors.greenTint,
          borderRadius: AppRadii.borderSm,
        ),
        child: PhosphorIcon(PhosphorIconsRegular.person,
            size: size * 0.5, color: AppColors.canopyGreen),
      );
}
