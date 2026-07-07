import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_text_styles.dart';

enum NdcButtonVariant { primary, secondary, danger, ghost }

class NdcButton extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final isDisabled = onPressed == null || loading;

    return SizedBox(
      width: width ?? double.infinity,
      height: 54,
      child: switch (variant) {
        NdcButtonVariant.primary => _PrimaryButton(
            label: label,
            onPressed: isDisabled ? null : _handleTap,
            loading: loading,
            icon: icon,
          ),
        NdcButtonVariant.secondary => _SecondaryButton(
            label: label,
            onPressed: isDisabled ? null : _handleTap,
            loading: loading,
            icon: icon,
          ),
        NdcButtonVariant.danger => _DangerButton(
            label: label,
            onPressed: isDisabled ? null : _handleTap,
            loading: loading,
          ),
        NdcButtonVariant.ghost => _GhostButton(
            label: label,
            onPressed: isDisabled ? null : _handleTap,
            icon: icon,
          ),
      },
    );
  }

  void _handleTap() {
    HapticFeedback.lightImpact();
    onPressed?.call();
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final Widget? icon;

  const _PrimaryButton({required this.label, this.onPressed, required this.loading, this.icon});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        shape: RoundedRectangleBorder(borderRadius: AppRadii.borderSm),
      ),
      child: loading
          ? const SizedBox(
              width: 20, height: 20,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.surface),
            )
          : icon == null
              // No symbol — a clean, centred label.
              ? Center(child: Text(label, style: AppTextStyles.buttonText()))
              // With a symbol — label stays optically centred, the icon rides
              // in a soft circular chip pinned to the trailing edge. Reads as a
              // considered "proceed" affordance rather than a decoration.
              : Stack(
                  alignment: Alignment.center,
                  children: [
                    Text(label, style: AppTextStyles.buttonText()),
                    Positioned(
                      right: 4,
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: AppColors.surface.withValues(alpha: 0.16),
                          shape: BoxShape.circle,
                        ),
                        child: Center(child: icon!),
                      ),
                    ),
                  ],
                ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final Widget? icon;

  const _SecondaryButton({required this.label, this.onPressed, required this.loading, this.icon});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        shape: RoundedRectangleBorder(borderRadius: AppRadii.borderSm),
      ),
      child: loading
          ? const SizedBox(
              width: 20, height: 20,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            )
          : icon == null
              ? Center(
                  child: Text(label,
                      style: AppTextStyles.buttonText(color: AppColors.canopyGreen)))
              // Mirrors the primary CTA: centred label, symbol in a soft
              // brand-tinted chip on the trailing edge.
              : Stack(
                  alignment: Alignment.center,
                  children: [
                    Text(label,
                        style: AppTextStyles.buttonText(color: AppColors.canopyGreen)),
                    Positioned(
                      right: 4,
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: AppColors.brandTint,
                          shape: BoxShape.circle,
                        ),
                        child: Center(child: icon!),
                      ),
                    ),
                  ],
                ),
    );
  }
}

class _DangerButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  const _DangerButton({required this.label, this.onPressed, required this.loading});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.umbrellaRed,
        foregroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: AppRadii.borderSm),
      ),
      child: loading
          ? const SizedBox(
              width: 20, height: 20,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.surface),
            )
          : Text(label, style: AppTextStyles.buttonText()),
    );
  }
}

class _GhostButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final Widget? icon;

  const _GhostButton({required this.label, this.onPressed, this.icon});

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: AppColors.mist,
        shape: RoundedRectangleBorder(borderRadius: AppRadii.borderSm),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[icon!, const SizedBox(width: 8)],
          Text(label, style: AppTextStyles.buttonText(color: AppColors.mist)),
        ],
      ),
    );
  }
}
