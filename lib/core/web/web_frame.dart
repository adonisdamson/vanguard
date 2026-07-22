import 'package:flutter/material.dart';

import '../../shared/theme/app_colors.dart';

/// On wide (desktop/tablet) web viewports, the app — which is designed for a
/// phone — is centered inside a fixed-width "device" frame on a calm NDC-tinted
/// backdrop, instead of stretching edge-to-edge and overlapping. On phones and
/// narrow windows it fills the screen normally.
class WebFrame extends StatelessWidget {
  final Widget child;
  const WebFrame({super.key, required this.child});

  // Below this width we treat the window as a phone and fill it.
  static const _phoneMax = 620.0;
  // The framed app column width on large screens.
  static const _frameWidth = 460.0;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width <= _phoneMax) return child;

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0A3D2A), Color(0xFF06301F)],
        ),
      ),
      child: Center(
        child: Container(
          width: _frameWidth,
          margin: const EdgeInsets.symmetric(vertical: 20),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppColors.paper,
            borderRadius: BorderRadius.circular(26),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 48,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: MediaQuery(
            // Report the framed size to the app so layout maths stays correct.
            data: MediaQuery.of(context).copyWith(
              size: Size(_frameWidth, MediaQuery.sizeOf(context).height - 40),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
