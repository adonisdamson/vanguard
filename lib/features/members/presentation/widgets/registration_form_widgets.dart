import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/theme/app_radii.dart';
import '../../../../shared/theme/app_text_styles.dart';

// ── Section title (green accent bar + heading) ────────────────────────────────
// Used by all three registration tabs. Single source so the bar width,
// spacing, and colour can't drift between tabs.

class RegistrationSectionTitle extends StatelessWidget {
  final String title;
  final String? subtitle;

  const RegistrationSectionTitle(this.title, {super.key, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 3,
              height: 20,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                color: AppColors.brand,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(title, style: AppTextStyles.h1()),
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(subtitle!, style: AppTextStyles.small()),
        ],
      ],
    );
  }
}

// ── Retry field ───────────────────────────────────────────────────────────────
// Load-failure state for a lookup field: says what failed and retries on tap.

class RegistrationRetryField extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const RegistrationRetryField({
    super.key,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onRetry,
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.umbrellaRed.withValues(alpha: 0.5)),
          borderRadius: AppRadii.borderSm,
          color: AppColors.redTint,
        ),
        child: Row(
          children: [
            const PhosphorIcon(PhosphorIconsRegular.arrowClockwise,
                size: 20, color: AppColors.umbrellaRed),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '$message — tap to retry',
                style: AppTextStyles.bodyLarge(color: AppColors.umbrellaRed),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Styled dropdown ───────────────────────────────────────────────────────────
// Matches NdcTextField visually: Phosphor icon, hairline border, brand focus.

class RegistrationDropdown<T> extends StatelessWidget {
  final String hint;
  final T? value;
  final PhosphorIconData icon;
  final List<T> items;
  final String Function(T) itemLabel;
  final void Function(T?) onChanged;
  final String? Function(T?)? validator;
  final bool enabled;

  const RegistrationDropdown({
    super.key,
    required this.hint,
    required this.value,
    required this.icon,
    required this.items,
    required this.itemLabel,
    required this.onChanged,
    this.validator,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      hint: Text(hint, style: AppTextStyles.bodyLarge(color: AppColors.textMuted)),
      decoration: InputDecoration(
        prefixIcon: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: PhosphorIcon(icon, size: 20, color: AppColors.textMuted),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 48),
      ),
      items: enabled
          ? items
              .map((item) => DropdownMenuItem<T>(
                    value: item,
                    child: Text(itemLabel(item), style: AppTextStyles.bodyLarge()),
                  ))
              .toList()
          : [],
      onChanged: enabled ? onChanged : null,
      validator: validator != null ? (v) => validator!(v) : null,
      isExpanded: true,
    );
  }
}

// ── Async dropdown ────────────────────────────────────────────────────────────
// Wraps RegistrationDropdown with loading/error/retry states for
// data loaded from a Riverpod provider. Pass asyncData from the call site.

class RegistrationAsyncDropdown<T> extends StatelessWidget {
  final String label;
  final PhosphorIconData icon;
  final String hint;
  final AsyncValue<List<T>> asyncData;
  final T? selected;
  final String Function(T) itemLabel;
  final void Function(T?) onChanged;
  final String? Function()? validator;
  final bool enabled;
  final VoidCallback? onRetry;

  const RegistrationAsyncDropdown({
    super.key,
    required this.label,
    required this.icon,
    required this.hint,
    required this.asyncData,
    required this.selected,
    required this.itemLabel,
    required this.onChanged,
    this.validator,
    this.enabled = true,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.label()),
        const SizedBox(height: 6),
        asyncData.when(
          data: (items) {
            final effectiveSelected =
                (selected != null && items.contains(selected)) ? selected : null;
            return RegistrationDropdown<T>(
              hint: hint,
              value: effectiveSelected,
              icon: icon,
              items: items,
              itemLabel: itemLabel,
              onChanged: onChanged,
              enabled: enabled && items.isNotEmpty,
              validator: validator != null ? (_) => validator!() : null,
            );
          },
          loading: () => _loadingField(),
          error: (_, _) => RegistrationRetryField(
            message: "Couldn't load ${label.replaceAll(' *', '').toLowerCase()}s",
            onRetry: onRetry,
          ),
        ),
      ],
    );
  }

  Widget _loadingField() {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.hairline),
        borderRadius: AppRadii.borderSm,
        color: AppColors.fillMuted,
      ),
      child: Row(
        children: [
          PhosphorIcon(icon, size: 20, color: AppColors.mist),
          const SizedBox(width: 12),
          Expanded(
            child: Text(hint, style: AppTextStyles.bodyLarge(color: AppColors.mist)),
          ),
        ],
      ),
    );
  }
}
