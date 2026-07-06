import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_text_styles.dart';
import 'ndc_button.dart';

/// The one scaffold every form/wizard screen uses.
///
/// Rule it enforces: the primary action is PINNED below the scrolling content,
/// inside the body column. Never Scaffold.bottomNavigationBar (Flutter renders
/// that BEHIND the keyboard) and never a button inside a scroll view (it hides
/// below the fold once the keyboard opens). With resizeToAvoidBottomInset the
/// whole column is inset above the keyboard, so the action bar stays visible
/// and tappable while typing.
class FormScaffold extends StatelessWidget {
  final PreferredSizeWidget? appBar;

  /// Pinned between the app bar and the scrolling area (e.g. a step strip).
  final Widget? header;

  /// The scrollable content. The caller provides its own scroll view.
  final Widget body;

  /// Usually a [FormActionBar].
  final Widget actionBar;

  final Color backgroundColor;

  const FormScaffold({
    super.key,
    this.appBar,
    this.header,
    required this.body,
    required this.actionBar,
    this.backgroundColor = AppColors.paper,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      resizeToAvoidBottomInset: true,
      appBar: appBar,
      body: Column(
        children: [
          ?header,
          Expanded(child: body),
          actionBar,
        ],
      ),
    );
  }
}

/// Pinned action bar: optional inline error, optional Back, full-width
/// primary button (disabled + spinner while submitting), optional secondary
/// action below. SafeArea keeps it above gesture-nav; when the keyboard is
/// open the view inset replaces that padding automatically.
class FormActionBar extends StatelessWidget {
  final String primaryLabel;
  final VoidCallback? onPrimary;
  final bool loading;
  final Widget? primaryIcon;

  /// Renders a square Back button at the leading edge when non-null.
  final VoidCallback? onBack;

  /// Inline error line shown above the buttons.
  final String? error;

  /// Full-width widget below the primary row (e.g. "Save & add another",
  /// or a "Sign in instead" link) — stays visible with the keyboard open.
  final Widget? secondaryAction;

  const FormActionBar({
    super.key,
    required this.primaryLabel,
    required this.onPrimary,
    this.loading = false,
    this.primaryIcon,
    this.onBack,
    this.error,
    this.secondaryAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.hairline)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (error != null) ...[
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.redTint,
                    borderRadius: AppRadii.borderSm,
                  ),
                  child: Text(error!,
                      style: AppTextStyles.small(color: AppColors.umbrellaRed)),
                ),
                const SizedBox(height: 10),
              ],
              Row(
                children: [
                  if (onBack != null) ...[
                    // Width MUST be bounded: this button is a non-flex Row
                    // child (unbounded width). With the old theme-wide
                    // infinite minimumSize this demanded infinite width and
                    // release builds painted the whole bar blank.
                    SizedBox(
                      width: 64,
                      height: 52,
                      child: OutlinedButton(
                        onPressed: loading ? null : onBack,
                        style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.zero),
                        child: const PhosphorIcon(PhosphorIconsFill.arrowLeft,
                            size: 20, color: AppColors.canopyGreen),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: NdcButton(
                      label: primaryLabel,
                      onPressed: loading ? null : onPrimary,
                      loading: loading,
                      icon: primaryIcon,
                    ),
                  ),
                ],
              ),
              if (secondaryAction != null) ...[
                const SizedBox(height: 8),
                secondaryAction!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
