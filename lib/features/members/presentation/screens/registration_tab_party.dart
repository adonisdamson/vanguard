import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../application/registration_form_notifier.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/theme/app_radii.dart';
import '../../../../shared/theme/app_spacing.dart';
import '../../../../shared/theme/app_text_styles.dart';
import '../../../../shared/widgets/ndc_button.dart';
import '../../../../shared/widgets/ndc_text_field.dart';
import '../widgets/registration_form_widgets.dart';

class RegistrationTabParty extends ConsumerStatefulWidget {
  final GlobalKey<FormState> formKey;
  const RegistrationTabParty({super.key, required this.formKey});

  @override
  ConsumerState<RegistrationTabParty> createState() =>
      _RegistrationTabPartyState();
}

class _RegistrationTabPartyState extends ConsumerState<RegistrationTabParty>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  late TextEditingController _profession;
  late TextEditingController _partyPosition;
  late TextEditingController _otherParty;

  String? _membershipType;
  String? _preferredRole;
  String? _employmentStatus;
  String? _highestQualification;
  List<String> _skills = [];

  final _picker = ImagePicker();
  bool _pickingPhoto = false;

  static const _skillOptions = [
    'Public Speaking', 'Canvassing', 'Social Media', 'Photography',
    'Event Planning', 'Data Entry', 'Fundraising', 'Legal',
    'Medical', 'Teaching', 'Engineering', 'Accounting',
  ];

  static const _membershipTypes = {
    'youth_member': 'Youth Member',
    'adult_member': 'Adult Member',
    'volunteer': 'Volunteer',
    'executive': 'Executive',
    'administration': 'Administration',
  };

  static const _roles = {
    'campaigning': 'Campaigning',
    'events': 'Events',
    'media': 'Media',
    'fundraising': 'Fundraising',
  };

  static const _employmentStatuses = [
    'Employed', 'Self-employed', 'Unemployed', 'Student', 'Retired',
  ];

  static const _qualifications = [
    'None', 'BECE', 'WASSCE', 'HND', "Bachelor's Degree",
    "Master's Degree", 'PhD', 'Professional Certificate',
  ];

  @override
  void initState() {
    super.initState();
    final d = ref.read(registrationFormProvider);
    _profession = TextEditingController(text: d.profession ?? '');
    _partyPosition = TextEditingController(text: d.partyPosition ?? '');
    _otherParty = TextEditingController(text: d.otherParty ?? '');
    _membershipType = d.membershipType;
    _preferredRole = d.preferredRole;
    _employmentStatus = d.employmentStatus;
    _highestQualification = d.highestQualification;
    _skills = List.from(d.skills);
  }

  @override
  void dispose() {
    _profession.dispose();
    _partyPosition.dispose();
    _otherParty.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto(ImageSource source) async {
    setState(() => _pickingPhoto = true);
    try {
      final image = await _picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 80,
      );
      if (image != null) {
        ref
            .read(registrationFormProvider.notifier)
            .setPhotoLocalPath(image.path);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
            'Camera or gallery not available. Check app permissions.',
            style: AppTextStyles.bodyMedium(color: AppColors.surface),
          ),
          backgroundColor: AppColors.umbrellaRed,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _pickingPhoto = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final formData = ref.watch(registrationFormProvider);

    return Form(
      key: widget.formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const RegistrationSectionTitle('Party & Livelihood'),
          const SizedBox(height: 24),

          // Membership Type *
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Membership Type *', style: AppTextStyles.label()),
              const SizedBox(height: 6),
              RegistrationDropdown<String>(
                hint: 'Select type',
                value: _membershipType,
                icon: PhosphorIconsRegular.identificationCard,
                items: _membershipTypes.keys.toList(),
                itemLabel: (k) => _membershipTypes[k]!,
                validator: (v) =>
                    v == null ? 'Membership type is required' : null,
                onChanged: (v) => setState(() => _membershipType = v),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.base),

          // Preferred Role
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Preferred Role', style: AppTextStyles.label()),
              const SizedBox(height: 6),
              RegistrationDropdown<String>(
                hint: 'Select role',
                value: _preferredRole,
                icon: PhosphorIconsRegular.star,
                items: _roles.keys.toList(),
                itemLabel: (k) => _roles[k]!,
                onChanged: (v) => setState(() => _preferredRole = v),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.base),

          NdcTextField(
            label: 'Profession',
            hint: 'e.g. Teacher, Farmer, Trader',
            icon: PhosphorIconsRegular.briefcase,
            controller: _profession,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: AppSpacing.base),

          NdcTextField(
            label: 'Party Position Held',
            hint: 'Optional — e.g. Branch Secretary',
            icon: PhosphorIconsRegular.medal,
            controller: _partyPosition,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: AppSpacing.base),

          NdcTextField(
            label: 'Previously a Member of Another Party?',
            hint: 'Optional — name of party',
            icon: PhosphorIconsRegular.flag,
            controller: _otherParty,
            textInputAction: TextInputAction.done,
          ),
          const SizedBox(height: AppSpacing.base),

          // Employment Status
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Employment Status', style: AppTextStyles.label()),
              const SizedBox(height: 6),
              RegistrationDropdown<String>(
                hint: 'Select status',
                value: _employmentStatus,
                icon: PhosphorIconsRegular.briefcase,
                items: _employmentStatuses,
                itemLabel: (v) => v,
                onChanged: (v) => setState(() => _employmentStatus = v),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.base),

          // Highest Qualification
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Highest Academic Qualification', style: AppTextStyles.label()),
              const SizedBox(height: 6),
              RegistrationDropdown<String>(
                hint: 'Select qualification',
                value: _highestQualification,
                icon: PhosphorIconsRegular.graduationCap,
                items: _qualifications,
                itemLabel: (v) => v,
                onChanged: (v) => setState(() => _highestQualification = v),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Skills toggle chips
          Text('Skills', style: AppTextStyles.label()),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _skillOptions.map((skill) {
              final selected = _skills.contains(skill);
              return GestureDetector(
                onTap: () => setState(() {
                  if (selected) {
                    _skills.remove(skill);
                  } else {
                    _skills.add(skill);
                  }
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.canopyGreen
                        : AppColors.fillMuted,
                    borderRadius: AppRadii.borderPill,
                    border: Border.all(
                      color: selected
                          ? AppColors.canopyGreen
                          : AppColors.hairline,
                    ),
                  ),
                  child: Text(
                    skill,
                    style: AppTextStyles.small(
                      color: selected ? AppColors.surface : AppColors.mist,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 28),

          // Member photo
          const Divider(height: 1),
          const SizedBox(height: 24),
          Text('Member Photo', style: AppTextStyles.h3()),
          const SizedBox(height: 4),
          Text('Optional — take a photo or pick from gallery',
              style: AppTextStyles.small()),
          const SizedBox(height: 16),
          _PhotoPicker(
            localPath: formData.photoLocalPath,
            picking: _pickingPhoto,
            onCamera: () => _pickPhoto(ImageSource.camera),
            onGallery: () => _pickPhoto(ImageSource.gallery),
            onRemove: () => ref
                .read(registrationFormProvider.notifier)
                .setPhotoLocalPath(null),
          ),

          // Syncs to provider on validation.
          FormField<void>(
            builder: (_) => const SizedBox.shrink(),
            validator: (_) {
              if (_membershipType == null) return 'Membership type is required';
              ref.read(registrationFormProvider.notifier).updateStep3(
                membershipType: _membershipType,
                preferredRole: _preferredRole,
                profession: _profession.text.trim().isEmpty
                    ? null
                    : _profession.text.trim(),
                partyPosition: _partyPosition.text.trim().isEmpty
                    ? null
                    : _partyPosition.text.trim(),
                otherParty: _otherParty.text.trim().isEmpty
                    ? null
                    : _otherParty.text.trim(),
                employmentStatus: _employmentStatus,
                highestQualification: _highestQualification,
                skills: _skills,
              );
              return null;
            },
          ),
        ],
      ),
    );
  }
}

// ── Photo picker ──────────────────────────────────────────────────────────────

class _PhotoPicker extends StatelessWidget {
  final String? localPath;
  final bool picking;
  final VoidCallback onCamera;
  final VoidCallback onGallery;
  final VoidCallback onRemove;

  const _PhotoPicker({
    required this.localPath,
    required this.picking,
    required this.onCamera,
    required this.onGallery,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (localPath != null)
          Stack(
            children: [
              ClipRRect(
                borderRadius: AppRadii.borderMd,
                child: Image.file(
                  File(localPath!),
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => _placeholder(),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: onRemove,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.ink.withValues(alpha: 0.7),
                      shape: BoxShape.circle,
                    ),
                    child: const PhosphorIcon(PhosphorIconsFill.trash,
                        size: 16, color: AppColors.surface),
                  ),
                ),
              ),
            ],
          )
        else
          _placeholder(),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: NdcButton(
                label: 'Camera',
                variant: NdcButtonVariant.secondary,
                loading: picking,
                icon: const PhosphorIcon(PhosphorIconsFill.camera,
                    size: 16, color: AppColors.canopyGreen),
                onPressed: onCamera,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: NdcButton(
                label: 'Gallery',
                variant: NdcButtonVariant.secondary,
                icon: const PhosphorIcon(PhosphorIconsFill.image,
                    size: 16, color: AppColors.canopyGreen),
                onPressed: onGallery,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _placeholder() {
    return Container(
      height: 180, // same height as the photo so layout doesn't jump
      decoration: BoxDecoration(
        color: AppColors.fillMuted,
        borderRadius: AppRadii.borderMd,
        border: Border.all(color: AppColors.hairline),
      ),
      child: const Center(
        child: PhosphorIcon(PhosphorIconsRegular.camera,
            size: 36, color: AppColors.textMuted),
      ),
    );
  }
}
