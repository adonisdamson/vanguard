import '../../../../core/net/authed_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../application/member_providers.dart';
import '../../../../core/net/photo_service.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/theme/app_radii.dart';
import 'photo_viewer.dart';

/// The one member avatar for list rows: real photo via the Worker view URL when
/// photo_path exists, otherwise the single app-wide fallback style
/// (greenTint square + canopyGreen person icon). Never per-screen variants.
/// When a photo exists, tapping it opens the full-screen [openPhotoViewer].
class MemberAvatar extends ConsumerWidget {
  final String? photoPath;
  final double size;
  final String? viewerLabel;

  const MemberAvatar({
    super.key,
    required this.photoPath,
    this.size = 44,
    this.viewerLabel,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (photoPath == null || photoPath!.isEmpty) return _fallback();

    final urlAsync = ref.watch(photoUrlProvider(photoPath!));
    return urlAsync.when(
      data: (url) => url == null
          ? _fallback()
          : Semantics(
              button: true,
              label: viewerLabel != null
                  ? 'View photo of $viewerLabel'
                  : 'View photo',
              child: GestureDetector(
                onTap: () =>
                    openPhotoViewer(context, photoPath, label: viewerLabel),
                child: ClipRRect(
                  borderRadius: AppRadii.borderSm,
                  child: Image(
                    image: AuthedNetworkImage(url, PhotoService.authHeaders()),
                    width: size,
                    height: size,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                    errorBuilder: (_, _, _) => _fallback(),
                    loadingBuilder: (_, child, p) =>
                        p == null ? child : _fallback(),
                  ),
                ),
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
