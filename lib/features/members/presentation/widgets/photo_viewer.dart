import '../../../../core/net/authed_image.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../../core/net/photo_service.dart';
import '../../../../shared/widgets/lottie_loader.dart';

/// Opens the full-screen viewer for a stored member/operator photo [photoPath].
/// No-op when there is no photo. Immersive dark backdrop, pinch-to-zoom, and a
/// clear close affordance — deliberately not a default Material dialog.
Future<void> openPhotoViewer(
  BuildContext context,
  String? photoPath, {
  String? label,
}) {
  if (photoPath == null || photoPath.isEmpty) return Future.value();
  return Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black.withValues(alpha: 0.93),
      barrierDismissible: true,
      transitionDuration: const Duration(milliseconds: 220),
      reverseTransitionDuration: const Duration(milliseconds: 170),
      pageBuilder: (_, _, _) =>
          _PhotoViewer(photoPath: photoPath, label: label),
      transitionsBuilder: (_, anim, _, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween(begin: 0.94, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
    ),
  );
}

class _PhotoViewer extends StatefulWidget {
  final String photoPath;
  final String? label;
  const _PhotoViewer({required this.photoPath, this.label});

  @override
  State<_PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<_PhotoViewer> {
  final _controller = TransformationController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _close() => Navigator.of(context).maybePop();

  bool get _isZoomed => _controller.value.getMaxScaleOnAxis() > 1.05;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Zoomable image. A plain tap (only when not zoomed in) dismisses,
          // so the empty letterbox area behaves like a scrim.
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                if (!_isZoomed) _close();
              },
              child: InteractiveViewer(
                transformationController: _controller,
                minScale: 1.0,
                maxScale: 5.0,
                child: Center(
                  child: Image(
                    image: AuthedNetworkImage(
                        PhotoService.viewUrl(widget.photoPath),
                        PhotoService.authHeaders()),
                    fit: BoxFit.contain,
                    gaplessPlayback: true,
                    errorBuilder: (_, _, _) => _error(),
                    loadingBuilder: (_, child, p) =>
                        p == null ? child : const LottieLoader(size: 96),
                  ),
                ),
              ),
            ),
          ),

          // Member/operator name, if provided.
          if (widget.label != null && widget.label!.trim().isNotEmpty)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: IgnorePointer(
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
                    child: Text(
                      widget.label!,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // Close affordance — 44x44 touch target, top-right.
          Positioned(
            top: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Semantics(
                  button: true,
                  label: 'Close photo',
                  child: InkResponse(
                    onTap: _close,
                    radius: 28,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.14),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.22)),
                      ),
                      child: const PhosphorIcon(
                        PhosphorIconsRegular.x,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _error() => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PhosphorIcon(
            PhosphorIconsRegular.imageBroken,
            color: Colors.white.withValues(alpha: 0.85),
            size: 56,
          ),
          const SizedBox(height: 14),
          const Text(
            "Couldn't load this photo",
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      );
}
