import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../application/registration_form_notifier.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/theme/app_radii.dart';
import '../../../../shared/theme/app_spacing.dart';
import '../../../../shared/theme/app_text_styles.dart';
import '../../../../shared/widgets/ndc_text_field.dart';
import '../widgets/registration_form_widgets.dart';

class RegistrationTabPersonal extends ConsumerStatefulWidget {
  final GlobalKey<FormState> formKey;
  const RegistrationTabPersonal({super.key, required this.formKey});

  @override
  ConsumerState<RegistrationTabPersonal> createState() =>
      _RegistrationTabPersonalState();
}

class _RegistrationTabPersonalState
    extends ConsumerState<RegistrationTabPersonal>
    with AutomaticKeepAliveClientMixin {
  // Keep alive so _validateAll()/_saveAll() can reach this Form after the user
  // navigates to another tab.
  @override
  bool get wantKeepAlive => true;

  late TextEditingController _firstName;
  late TextEditingController _lastName;
  late TextEditingController _phone;
  late TextEditingController _email;
  late TextEditingController _ghanaCardId;
  DateTime? _dob;
  String? _gender;

  @override
  void initState() {
    super.initState();
    final d = ref.read(registrationFormProvider);
    _firstName = TextEditingController(text: d.firstName);
    _lastName = TextEditingController(text: d.lastName);
    _phone = TextEditingController(text: d.phone);
    _email = TextEditingController(text: d.email ?? '');
    _ghanaCardId = TextEditingController(text: d.ghanaCardId ?? '');
    _dob = d.dateOfBirth;
    _gender = d.gender;
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _phone.dispose();
    _email.dispose();
    _ghanaCardId.dispose();
    super.dispose();
  }

  Future<void> _pickDob(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(1990, 1, 1),
      firstDate: DateTime(1920),
      lastDate: DateTime.now().subtract(const Duration(days: 365 * 10)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.canopyGreen),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _dob = picked);
  }

  String _formatDob(DateTime? d) {
    if (d == null) return 'Select date';
    return DateFormat('d MMM y').format(d);
  }

  int? _age(DateTime? d) {
    if (d == null) return null;
    final today = DateTime.now();
    int age = today.year - d.year;
    if (today.month < d.month ||
        (today.month == d.month && today.day < d.day)) {
      age--;
    }
    return age;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Form(
      key: widget.formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const RegistrationSectionTitle(
            'Personal Information',
            subtitle: 'Required fields are marked with *',
          ),
          const SizedBox(height: 24),

          NdcTextField(
            label: 'First Name *',
            hint: 'e.g. Kwame',
            icon: PhosphorIconsRegular.person,
            controller: _firstName,
            textInputAction: TextInputAction.next,
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'First name is required' : null,
          ),
          const SizedBox(height: AppSpacing.base),

          NdcTextField(
            label: 'Last Name *',
            hint: 'e.g. Mensah',
            icon: PhosphorIconsRegular.person,
            controller: _lastName,
            textInputAction: TextInputAction.next,
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'Last name is required' : null,
          ),
          const SizedBox(height: AppSpacing.base),

          // Date of Birth + auto-calculated age
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Date of Birth', style: AppTextStyles.label()),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () => _pickDob(context),
                child: Container(
                  height: 52,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.hairline),
                    borderRadius: AppRadii.borderSm,
                    color: AppColors.surface,
                  ),
                  child: Row(
                    children: [
                      const PhosphorIcon(PhosphorIconsRegular.calendarBlank,
                          size: 20, color: AppColors.textMuted),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _formatDob(_dob),
                          style: _dob != null
                              ? AppTextStyles.bodyLarge()
                              : AppTextStyles.bodyLarge(color: AppColors.textMuted),
                        ),
                      ),
                      if (_age(_dob) != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.brandTint,
                            borderRadius: AppRadii.borderPill,
                          ),
                          child: Text(
                            'Age ${_age(_dob)}',
                            style: AppTextStyles.caption(
                                color: AppColors.canopyGreen),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.base),

          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Gender', style: AppTextStyles.label()),
              const SizedBox(height: 6),
              _GenderSegment(
                value: _gender,
                onChanged: (v) => setState(() => _gender = v),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.base),

          NdcTextField(
            label: 'Phone Number *',
            hint: '+233 XX XXX XXXX',
            icon: PhosphorIconsRegular.phone,
            controller: _phone,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Phone number is required';
              if (v.trim().length < 9) return 'Enter a valid phone number';
              return null;
            },
          ),
          const SizedBox(height: AppSpacing.base),

          NdcTextField(
            label: 'Email Address',
            hint: 'Optional',
            icon: PhosphorIconsRegular.envelope,
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            validator: (v) {
              if (v != null && v.isNotEmpty && !v.contains('@')) {
                return 'Enter a valid email';
              }
              return null;
            },
          ),
          const SizedBox(height: AppSpacing.base),

          NdcTextField(
            label: 'Ghana Card / Voter ID',
            hint: 'GHA-XXXXXXXXX-X',
            icon: PhosphorIconsRegular.identificationCard,
            controller: _ghanaCardId,
            keyboardType: TextInputType.text,
            textInputAction: TextInputAction.done,
          ),

          // Syncs all field values to the Riverpod provider on validation.
          FormField<void>(
            builder: (_) => const SizedBox.shrink(),
            validator: (_) {
              ref.read(registrationFormProvider.notifier).updateStep1(
                firstName: _firstName.text.trim(),
                lastName: _lastName.text.trim(),
                dateOfBirth: _dob,
                gender: _gender,
                phone: _phone.text.trim(),
                email: _email.text.trim().isEmpty ? null : _email.text.trim(),
                ghanaCardId: _ghanaCardId.text.trim().isEmpty
                    ? null
                    : _ghanaCardId.text.trim(),
              );
              return null;
            },
          ),
        ],
      ),
    );
  }
}

// ── Gender segmented control ──────────────────────────────────────────────────

class _GenderSegment extends StatelessWidget {
  final String? value;
  final void Function(String) onChanged;

  const _GenderSegment({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _GenderPill(
            label: 'Male',
            selected: value == 'male',
            onTap: () => onChanged('male')),
        const SizedBox(width: AppSpacing.sm),
        _GenderPill(
            label: 'Female',
            selected: value == 'female',
            onTap: () => onChanged('female')),
      ],
    );
  }
}

class _GenderPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _GenderPill(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? AppColors.canopyGreen : AppColors.fillMuted,
          borderRadius: AppRadii.borderPill,
          border: Border.all(
            color: selected ? AppColors.canopyGreen : AppColors.hairline,
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.label(
              color: selected ? AppColors.surface : AppColors.mist),
        ),
      ),
    );
  }
}
