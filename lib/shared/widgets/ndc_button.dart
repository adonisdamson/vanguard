import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

enum NdcButtonVariant { primary, secondary, danger, ghost }

/// Tactile NDC button. Primary/danger read as a physical key: a crisp coloured
/// "ledge" beneath the face + a soft ambient glow; pressing translates the face
/// down onto the ledge (90ms) so taps feel real, not flat. Secondary is a
/// weighted outline; ghost is a quiet text action. Deliberately not a default
/// Material button.
class NdcButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final Widget? icon;
  final NdcButtonVariant variant;
  final double? width;

  const NdcButton({
    super.key,
    required this.label,
    this.onPressed,
    this.loading = false,
    this.icon,
    this.variant = NdcButtonVariant.primary,
    this.width,
  });

  @override
  State<NdcButton> createState() => _NdcButtonState();
}

class _NdcButtonState extends State<NdcButton> {
  bool _pressed = false;

  bool get _disabled => widget.onPressed == null || widget.loading;

  void _tap() {
    HapticFeedback.lightImpact();
    widget.onPressed?.call();
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.variant;
    final solid = v == NdcButtonVariant.primary || v == NdcButtonVariant.danger;

    // Face / ledge / label colours per variant.
    late Color face, ledge, labelColor;
    Color? borderColor;
    switch (v) {
      case NdcButtonVariant.primary:
        face = AppColors.canopyGreen;
        ledge = AppColors.deepCanopy;
        labelColor = AppColors.surface;
        break;
      case NdcButtonVariant.danger:
        face = AppColors.umbrellaRed;
        ledge = const Color(0xFF8E0B1A);
        labelColor = AppColors.surface;
        break;
      case NdcButtonVariant.secondary:
        face = AppColors.surface;
        ledge = AppColors.canopyGreen;
        labelColor = AppColors.canopyGreen;
        borderColor = AppColors.canopyGreen;
        break;
      case NdcButtonVariant.ghost:
        face = Colors.transparent;
        ledge = Colors.transparent;
        labelColor = AppColors.inkMuted;
        break;
    }

    final pressed = _pressed && !_disabled;
    final drop = solid ? 4.0 : 3.0; // resting ledge depth

    Widget content = widget.loading
        ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2.5, color: labelColor),
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.icon != null) ...[widget.icon!, const SizedBox(width: 9)],
              Text(
                widget.label,
                style: AppTextStyles.buttonText(color: labelColor)
                    .copyWith(letterSpacing: 0.3, fontWeight: FontWeight.w700),
              ),
            ],
          );

    final face_ = AnimatedContainer(
      duration: const Duration(milliseconds: 90),
      curve: Curves.easeOut,
      height: 54,
      transform: Matrix4.translationValues(0, pressed ? drop : 0, 0),
      decoration: BoxDecoration(
        color: _disabled ? face.withValues(alpha: v == NdcButtonVariant.ghost ? 1 : 0.55) : face,
        borderRadius: BorderRadius.circular(16),
        border: borderColor != null
            ? Border.all(color: _disabled ? borderColor.withValues(alpha: 0.4) : borderColor, width: 1.6)
            : null,
        boxShadow: (v == NdcButtonVariant.ghost || _disabled)
            ? null
            : [
                // crisp ledge — no blur, gives the physical key edge
                BoxShadow(color: ledge, offset: Offset(0, pressed ? (drop - 3) : drop), blurRadius: 0),
                // soft ambient glow in the brand colour
                BoxShadow(
                  color: (solid ? face : ledge).withValues(alpha: 0.28),
                  offset: Offset(0, pressed ? 3 : 9),
                  blurRadius: pressed ? 8 : 18,
                ),
              ],
      ),
      alignment: Alignment.center,
      child: content,
    );

    return SizedBox(
      width: widget.width ?? double.infinity,
      // Reserve room for the ledge so layout doesn't jump.
      height: 54 + drop + 4,
      child: GestureDetector(
        onTapDown: _disabled ? null : (_) => setState(() => _pressed = true),
        onTapUp: _disabled ? null : (_) => setState(() => _pressed = false),
        onTapCancel: _disabled ? null : () => setState(() => _pressed = false),
        onTap: _disabled ? null : _tap,
        behavior: HitTestBehavior.opaque,
        child: Align(alignment: Alignment.topCenter, child: face_),
      ),
    );
  }
}
