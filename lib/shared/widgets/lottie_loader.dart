import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../theme/app_colors.dart';

// ── LottieLoader ──────────────────────────────────────────────────────────────
// Spinning arc in canopyGreen. Use for full-page loading states and inline
// loading placeholders. Loops continuously.
class LottieLoader extends StatelessWidget {
  final double size;
  const LottieLoader({super.key, this.size = 80});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Lottie.asset(
        'assets/lottie/loading.json',
        repeat: true,
        fit: BoxFit.contain,
      ),
    );
  }
}

// ── LottieSuccess ─────────────────────────────────────────────────────────────
// Animated checkmark. Plays once; call onComplete to react when done.
class LottieSuccess extends StatefulWidget {
  final double size;
  final VoidCallback? onComplete;
  const LottieSuccess({super.key, this.size = 80, this.onComplete});

  @override
  State<LottieSuccess> createState() => _LottieSuccessState();
}

class _LottieSuccessState extends State<LottieSuccess>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Lottie.asset(
        'assets/lottie/success.json',
        controller: _ctrl,
        repeat: false,
        fit: BoxFit.contain,
        onLoaded: (comp) {
          _ctrl
            ..duration = comp.duration
            ..forward().whenComplete(() => widget.onComplete?.call());
        },
      ),
    );
  }
}

// ── LottiePageLoader ─────────────────────────────────────────────────────────
// Full-screen loading overlay — centered spinner on paper background.
class LottiePageLoader extends StatelessWidget {
  const LottiePageLoader({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.paper,
      body: Center(child: LottieLoader(size: 96)),
    );
  }
}
