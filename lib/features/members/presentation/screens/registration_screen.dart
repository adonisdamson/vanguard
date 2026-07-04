import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../application/registration_form_notifier.dart';
import '../../application/location_providers.dart';
import '../../application/offline_queue.dart';
import '../../data/member_repository.dart';
import '../../data/capture_metadata_service.dart';
import '../../data/location_repository.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/theme/app_radii.dart';
import '../../../../shared/theme/app_spacing.dart';
import '../../../../shared/theme/app_text_styles.dart';
import '../../../../shared/widgets/canopy_arc.dart';
import '../../../../shared/theme/app_shadows.dart';
import '../../../../shared/widgets/ndc_button.dart';
import '../../../../shared/widgets/ndc_text_field.dart';
import '../../../../shared/widgets/lottie_loader.dart';

const _stepTitles = [
  'Personal Info',
  'Location',
  'Membership',
  'Photo & Review',
];

class RegistrationScreen extends ConsumerStatefulWidget {
  const RegistrationScreen({super.key});

  @override
  ConsumerState<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends ConsumerState<RegistrationScreen> {
  int _step = 0;
  int _sessionCount = 0;
  bool _submitting = false;
  String? _submitError;

  final _formKeys = List.generate(4, (_) => GlobalKey<FormState>());

  bool _validateStep() => _formKeys[_step].currentState?.validate() ?? false;

  void _next() {
    if (!_validateStep()) return;
    _formKeys[_step].currentState!.save();
    if (_step < 3) setState(() => _step++);
  }

  void _back() {
    if (_step > 0) setState(() => _step--);
  }

  Future<bool> _checkDuplicates(RegistrationFormData data) async {
    final db = Supabase.instance.client;
    if (data.phone.isNotEmpty) {
      try {
        final res = await db
            .from('members')
            .select('id, first_name, last_name')
            .eq('phone', data.phone)
            .limit(1)
            .maybeSingle();
        if (res != null && mounted) {
          final proceed = await _showDuplicateWarning(
            'Phone ${data.phone} matches an existing record: ${res['first_name']} ${res['last_name']}.',
          );
          if (!proceed) return false;
        }
      } catch (_) {}
    }
    if (data.dateOfBirth != null) {
      final dob = data.dateOfBirth!;
      final dobStr = '${dob.year}-${dob.month.toString().padLeft(2, '0')}-${dob.day.toString().padLeft(2, '0')}';
      try {
        final res = await db
            .from('members')
            .select('id, first_name, last_name')
            .eq('first_name', data.firstName)
            .eq('last_name', data.lastName)
            .eq('date_of_birth', dobStr)
            .limit(1)
            .maybeSingle();
        if (res != null && mounted) {
          final proceed = await _showDuplicateWarning(
            '${data.firstName} ${data.lastName} with that date of birth already exists.',
          );
          if (!proceed) return false;
        }
      } catch (_) {}
    }
    return true;
  }

  Future<bool> _showDuplicateWarning(String message) async {
    if (!mounted) return false;
    return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: AppRadii.borderLg),
            title: Text('Possible duplicate', style: AppTextStyles.h3()),
            content: Text(message, style: AppTextStyles.body()),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text('Register anyway', style: TextStyle(color: AppColors.umbrellaRed)),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<String?> _doInsert(RegistrationFormData formData, String userId, MemberRepository repo) async {
    String? storagePath;
    if (formData.photoLocalPath != null) {
      try {
        storagePath = await repo.uploadPhoto(formData.photoLocalPath!, userId);
        ref.read(registrationFormProvider.notifier).setPhotoStoragePath(storagePath);
      } catch (_) {}
    }
    final updatedForm = ref.read(registrationFormProvider);
    final result = await repo.insertMember(updatedForm.toInsertMap(userId));
    return result['id'];
  }

  void _captureMetadata(String memberId) async {
    final pos = await CaptureMetadataService.requestLocation();
    CaptureMetadataService.capture(memberId, lat: pos?.latitude, lng: pos?.longitude).ignore();
  }

  Future<void> _submit({bool addAnother = false}) async {
    if (!_validateStep()) return;
    _formKeys[_step].currentState!.save();

    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) return;

    final formData = ref.read(registrationFormProvider);

    // Duplicate guard — warn but let the operator decide
    final proceed = await _checkDuplicates(formData);
    if (!proceed || !mounted) return;

    setState(() {
      _submitting = true;
      _submitError = null;
    });

    final repo = MemberRepository();
    bool isOffline = false;
    String? memberId;

    try {
      memberId = await _doInsert(formData, session.user.id, repo);
    } catch (e) {
      if (_isNetworkError(e)) {
        isOffline = true;
        await OfflineQueue.enqueue(OfflineRegistration(
          insertData: formData.toOfflineJson(session.user.id),
          photoLocalPath: formData.photoLocalPath,
          registeredBy: session.user.id,
          enqueuedAt: DateTime.now().toIso8601String(),
        ));
      } else {
        setState(() {
          _submitError = 'Registration failed. Please try again.';
          _submitting = false;
        });
        return;
      }
    }

    if (memberId != null) _captureMetadata(memberId);

    if (!mounted) return;
    HapticFeedback.mediumImpact();

    if (addAnother) {
      // Save current location for retention before resetting
      final retention = LocationRetention(
        region: null, // objects not tracked in form; step2 stores IDs
        district: null,
        constituency: null,
        pollingStation: null,
        electoralArea: ref.read(selectedElectoralAreaProvider),
        ward: formData.ward,
        branch: formData.branch,
        residentialAddress: formData.residentialAddress,
        residenceTown: formData.residenceTown,
      );
      ref.read(locationRetentionProvider.notifier).state = retention;
      ref.read(registrationFormProvider.notifier).resetPersonalOnly();
      setState(() {
        _step = 0;
        _sessionCount++;
        _submitting = false;
        _submitError = null;
      });
      if (mounted) {
        _showSaveSuccess(
            'Saved — member $_sessionCount of this session. Location kept.');
      }
    } else {
      ref.read(registrationFormProvider.notifier).reset();
      ref.read(locationRetentionProvider.notifier).state = null;
      setState(() => _submitting = false);
      if (isOffline) {
        _showOfflineSaved();
      } else {
        context.go('/my-submissions');
      }
    }
  }

  bool _isNetworkError(Object e) {
    final msg = e.toString().toLowerCase();
    return msg.contains('socket') ||
        msg.contains('connection') ||
        msg.contains('network') ||
        msg.contains('timeout') ||
        msg.contains('host lookup');
  }

  void _showOfflineSaved() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.statusPending,
        content: Row(
          children: [
            const PhosphorIcon(PhosphorIconsFill.cloudSlash, size: 18, color: AppColors.surface),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Saved offline — will sync when you\'re back online.',
                style: AppTextStyles.body(color: AppColors.surface),
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 4),
      ),
    );
    context.go('/home');
  }

  void _showSaveSuccess(String message) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black26,
      barrierDismissible: false,
      builder: (_) => _SaveSuccessOverlay(message: message),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        backgroundColor: AppColors.deepCanopy,
        elevation: 0,
        leading: IconButton(
          icon: const PhosphorIcon(PhosphorIconsRegular.x, color: AppColors.surface, size: 22),
          onPressed: () => _confirmExit(context),
        ),
        title: _sessionCount > 0
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Register member', style: AppTextStyles.appBarTitle()),
                  Text('Session · $_sessionCount saved', style: AppTextStyles.caption(color: AppColors.surface.withValues(alpha: 0.7))),
                ],
              )
            : Text('Register member', style: AppTextStyles.appBarTitle()),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(4),
          child: CanopyStripe(height: 4),
        ),
      ),
      body: Column(
        children: [
          _StepProgress(currentStep: _step),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
              child: _buildCurrentStep(),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _BottomNav(
        step: _step,
        submitting: _submitting,
        error: _submitError,
        onBack: _back,
        onNext: _step < 3 ? _next : () => _submit(),
        onSaveAndAnother: _step == 3 ? () => _submit(addAnother: true) : null,
      ),
    );
  }

  Widget _buildCurrentStep() {
    return switch (_step) {
      0 => _Step1Personal(formKey: _formKeys[0]),
      1 => _Step2Location(formKey: _formKeys[1]),
      2 => _Step3Membership(formKey: _formKeys[2]),
      3 => _Step4PhotoReview(formKey: _formKeys[3]),
      _ => const SizedBox.shrink(),
    };
  }

  void _confirmExit(BuildContext context) {
    showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Discard registration?', style: AppTextStyles.h3()),
        content: Text('Your progress will be lost.', style: AppTextStyles.body()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep editing'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context, true);
              ref.read(registrationFormProvider.notifier).reset();
            },
            child: Text('Discard', style: TextStyle(color: AppColors.umbrellaRed)),
          ),
        ],
      ),
    ).then((exit) {
      if (exit == true && mounted) context.pop();
    });
  }
}

// ─── Step Progress ──────────────────────────────────────────────────────────

class _StepProgress extends StatelessWidget {
  final int currentStep;
  const _StepProgress({required this.currentStep});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: List.generate(4, (i) => Expanded(
              child: Container(
                margin: EdgeInsets.only(right: i < 3 ? 6 : 0),
                height: 4,
                decoration: BoxDecoration(
                  color: i <= currentStep ? AppColors.canopyGreen : AppColors.hairline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            )),
          ),
          const SizedBox(height: 8),
          Text(
            'Step ${currentStep + 1} of 4 — ${_stepTitles[currentStep]}',
            style: AppTextStyles.small(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

// ─── Bottom Nav ─────────────────────────────────────────────────────────────

class _BottomNav extends StatelessWidget {
  final int step;
  final bool submitting;
  final String? error;
  final VoidCallback onBack;
  final VoidCallback onNext;
  final VoidCallback? onSaveAndAnother;

  const _BottomNav({
    required this.step,
    required this.submitting,
    required this.error,
    required this.onBack,
    required this.onNext,
    this.onSaveAndAnother,
  });

  @override
  Widget build(BuildContext context) {
    final isFinalStep = step == 3;
    return Container(
      color: AppColors.surface,
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + MediaQuery.of(context).padding.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (error != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.redTint,
                borderRadius: AppRadii.borderSm,
              ),
              child: Text(error!, style: AppTextStyles.small(color: AppColors.umbrellaRed)),
            ),
            const SizedBox(height: 10),
          ],
          // Primary row: back + main action
          Row(
            children: [
              if (step > 0) ...[
                SizedBox(
                  height: 52,
                  child: OutlinedButton(
                    onPressed: submitting ? null : onBack,
                    child: const PhosphorIcon(PhosphorIconsFill.arrowLeft, size: 20, color: AppColors.canopyGreen),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: NdcButton(
                  label: isFinalStep ? 'Save & Add Another' : 'Continue',
                  onPressed: isFinalStep ? onSaveAndAnother : onNext,
                  loading: submitting,
                  icon: isFinalStep
                      ? const PhosphorIcon(PhosphorIconsFill.userPlus, size: 18, color: AppColors.surface)
                      : const PhosphorIcon(PhosphorIconsFill.arrowRight, size: 18, color: AppColors.surface),
                ),
              ),
            ],
          ),
          // Secondary: plain "Save" on final step
          if (isFinalStep) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton.icon(
                onPressed: submitting ? null : onNext,
                icon: const PhosphorIcon(PhosphorIconsFill.check, size: 16, color: AppColors.canopyGreen),
                label: Text('Save only', style: AppTextStyles.bodyMedium(color: AppColors.canopyGreen)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.canopyGreen),
                  shape: RoundedRectangleBorder(borderRadius: AppRadii.borderSm),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Step 1: Personal Info ───────────────────────────────────────────────────

class _Step1Personal extends ConsumerStatefulWidget {
  final GlobalKey<FormState> formKey;
  const _Step1Personal({required this.formKey});

  @override
  ConsumerState<_Step1Personal> createState() => _Step1PersonalState();
}

class _Step1PersonalState extends ConsumerState<_Step1Personal> {
  late TextEditingController _firstName;
  late TextEditingController _lastName;
  late TextEditingController _phone;
  late TextEditingController _email;
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
    _dob = d.dateOfBirth;
    _gender = d.gender;
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  void _pickDob(BuildContext context) async {
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
    final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: widget.formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Personal Information', style: AppTextStyles.h2()),
          const SizedBox(height: 4),
          Text('Required fields are marked with *', style: AppTextStyles.small()),
          const SizedBox(height: 24),

          NdcTextField(
            label: 'First Name *',
            hint: 'e.g. Kwame',
            icon: PhosphorIconsRegular.person,
            controller: _firstName,
            textInputAction: TextInputAction.next,
            validator: (v) => v == null || v.trim().isEmpty ? 'First name is required' : null,
            onChanged: (_) {},
          ),
          const SizedBox(height: 16),

          NdcTextField(
            label: 'Last Name *',
            hint: 'e.g. Mensah',
            icon: PhosphorIconsRegular.person,
            controller: _lastName,
            textInputAction: TextInputAction.next,
            validator: (v) => v == null || v.trim().isEmpty ? 'Last name is required' : null,
            onChanged: (_) {},
          ),
          const SizedBox(height: 16),

          // Date of Birth
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
                      const PhosphorIcon(PhosphorIconsRegular.calendarBlank, size: 20, color: AppColors.textMuted),
                      const SizedBox(width: 12),
                      Text(
                        _formatDob(_dob),
                        style: _dob != null
                            ? AppTextStyles.bodyLarge()
                            : AppTextStyles.bodyLarge(color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Gender — segmented control (male/female per gender_type enum)
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
          const SizedBox(height: 16),

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
            onChanged: (_) {},
          ),
          const SizedBox(height: 16),

          NdcTextField(
            label: 'Email Address',
            hint: 'Optional',
            icon: PhosphorIconsRegular.envelope,
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            validator: (v) {
              if (v != null && v.isNotEmpty && !v.contains('@')) return 'Enter a valid email';
              return null;
            },
            onChanged: (_) {},
          ),

          // Hidden FormField to save to notifier on validate
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
              );
              return null;
            },
          ),
        ],
      ),
    );
  }
}

// ─── Step 2: Location ────────────────────────────────────────────────────────

class _Step2Location extends ConsumerStatefulWidget {
  final GlobalKey<FormState> formKey;
  const _Step2Location({required this.formKey});

  @override
  ConsumerState<_Step2Location> createState() => _Step2LocationState();
}

class _Step2LocationState extends ConsumerState<_Step2Location> {
  late TextEditingController _ward;
  late TextEditingController _branch;
  late TextEditingController _residentialAddress;
  late TextEditingController _residenceTown;

  Region? _region;
  District? _district;
  Constituency? _constituency;
  PollingStation? _pollingStation;
  String? _electoralArea;

  @override
  void initState() {
    super.initState();
    final d = ref.read(registrationFormProvider);
    _ward = TextEditingController(text: d.ward ?? '');
    _branch = TextEditingController(text: d.branch ?? '');
    _residentialAddress = TextEditingController(text: d.residentialAddress ?? '');
    _residenceTown = TextEditingController(text: d.residenceTown ?? '');

    // Restore electoral area from Save & Add Another retention
    final retention = ref.read(locationRetentionProvider);
    if (retention?.electoralArea != null) {
      _electoralArea = retention!.electoralArea;
      // provider is not reset by resetPersonalOnly so it already matches, no need to re-set
    }

    // Restore dropdown objects if re-entering step 2 after Save & Add Another
    if (d.regionId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _restoreLocationObjects());
    }
  }

  // Match form IDs back to live objects from cached providers.
  // Providers aren't invalidated on Save & Add Another, so data is already cached.
  void _restoreLocationObjects() {
    if (!mounted) return;
    final d = ref.read(registrationFormProvider);

    ref.read(regionsProvider).whenData((regions) {
      final r = regions.where((x) => x.id == d.regionId).firstOrNull;
      if (r != null && mounted) setState(() => _region = r);
    });
    ref.read(districtsProvider).whenData((districts) {
      final r = districts.where((x) => x.id == d.districtId).firstOrNull;
      if (r != null && mounted) setState(() => _district = r);
    });
    ref.read(constituenciesProvider).whenData((constituencies) {
      final r = constituencies.where((x) => x.id == d.constituencyId).firstOrNull;
      if (r != null && mounted) setState(() => _constituency = r);
    });
    ref.read(pollingStationsProvider).whenData((stations) {
      final r = stations.where((x) => x.id == d.pollingStationId).firstOrNull;
      if (r != null && mounted) setState(() => _pollingStation = r);
    });
  }

  @override
  void dispose() {
    _ward.dispose();
    _branch.dispose();
    _residentialAddress.dispose();
    _residenceTown.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final regionsAsync = ref.watch(regionsProvider);
    final districtsAsync = ref.watch(districtsProvider);
    final constituenciesAsync = ref.watch(constituenciesProvider);
    final electoralAreasAsync = ref.watch(electoralAreasProvider);
    final pollingStationsAsync = ref.watch(pollingStationsProvider);

    return Form(
      key: widget.formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Location Details', style: AppTextStyles.h2()),
          const SizedBox(height: 4),
          Text('Select the member\'s registration location', style: AppTextStyles.small()),
          const SizedBox(height: 24),

          // Region
          _AsyncDropdown<Region>(
            label: 'Region *',
            icon: PhosphorIconsRegular.mapTrifold,
            hint: 'Select region',
            asyncData: regionsAsync,
            selected: _region,
            itemLabel: (r) => r.name,
            onChanged: (r) {
              setState(() {
                _region = r;
                _district = null;
                _constituency = null;
                _electoralArea = null;
                _pollingStation = null;
              });
              ref.read(selectedRegionIdProvider.notifier).state = r?.id;
              ref.read(selectedDistrictIdProvider.notifier).state = null;
              ref.read(selectedConstituencyIdProvider.notifier).state = null;
              ref.read(selectedElectoralAreaProvider.notifier).state = null;
            },
            validator: () => _region == null ? 'Please select a region' : null,
          ),
          const SizedBox(height: 16),

          // District
          _AsyncDropdown<District>(
            label: 'District *',
            icon: PhosphorIconsRegular.buildings,
            hint: _region == null ? 'Select region first' : 'Select district',
            asyncData: districtsAsync,
            selected: _district,
            enabled: _region != null,
            itemLabel: (d) => d.name,
            onChanged: (d) {
              setState(() {
                _district = d;
                _constituency = null;
                _electoralArea = null;
                _pollingStation = null;
              });
              ref.read(selectedDistrictIdProvider.notifier).state = d?.id;
              ref.read(selectedConstituencyIdProvider.notifier).state = null;
              ref.read(selectedElectoralAreaProvider.notifier).state = null;
            },
            validator: () => _district == null && _region != null ? 'Please select a district' : null,
          ),
          const SizedBox(height: 16),

          // Constituency
          _AsyncDropdown<Constituency>(
            label: 'Constituency *',
            icon: PhosphorIconsRegular.mapPin,
            hint: _district == null ? 'Select district first' : 'Select constituency',
            asyncData: constituenciesAsync,
            selected: _constituency,
            enabled: _district != null,
            itemLabel: (c) => c.name,
            onChanged: (c) {
              setState(() {
                _constituency = c;
                _electoralArea = null;
                _pollingStation = null;
              });
              ref.read(selectedConstituencyIdProvider.notifier).state = c?.id;
              ref.read(selectedElectoralAreaProvider.notifier).state = null;
            },
            validator: () => _constituency == null && _district != null ? 'Please select a constituency' : null,
          ),
          const SizedBox(height: 16),

          // Electoral Area — optional filter, only shown when constituency is chosen
          if (_constituency != null) ...[
            _AsyncDropdown<String>(
              label: 'Electoral Area',
              icon: PhosphorIconsRegular.mapPin,
              hint: 'Filter by electoral area (optional)',
              asyncData: electoralAreasAsync,
              selected: _electoralArea,
              itemLabel: (ea) => ea,
              onChanged: (ea) {
                setState(() {
                  _electoralArea = ea;
                  _pollingStation = null;
                });
                ref.read(selectedElectoralAreaProvider.notifier).state = ea;
              },
            ),
            const SizedBox(height: 16),
          ],

          // Polling Station
          _AsyncDropdown<PollingStation>(
            label: 'Polling Station *',
            icon: PhosphorIconsRegular.buildings,
            hint: _constituency == null ? 'Select constituency first' : 'Select polling station',
            asyncData: pollingStationsAsync,
            selected: _pollingStation,
            enabled: _constituency != null,
            itemLabel: (p) => p.name,
            onChanged: (p) => setState(() => _pollingStation = p),
            validator: () => _pollingStation == null && _constituency != null ? 'Please select a polling station' : null,
          ),
          const SizedBox(height: 16),

          NdcTextField(
            label: 'Ward',
            hint: 'Optional',
            icon: PhosphorIconsRegular.mapPin,
            controller: _ward,
            textInputAction: TextInputAction.next,
            onChanged: (_) {},
          ),
          const SizedBox(height: 16),

          NdcTextField(
            label: 'Branch',
            hint: 'Optional',
            icon: PhosphorIconsRegular.tag,
            controller: _branch,
            textInputAction: TextInputAction.next,
            onChanged: (_) {},
          ),
          const SizedBox(height: 16),

          NdcTextField(
            label: 'Residential Address',
            hint: 'Optional — house number and street',
            icon: PhosphorIconsRegular.house,
            controller: _residentialAddress,
            textInputAction: TextInputAction.next,
            onChanged: (_) {},
          ),
          const SizedBox(height: 16),

          NdcTextField(
            label: 'Town / City of Residence',
            hint: 'Optional',
            icon: PhosphorIconsRegular.city,
            controller: _residenceTown,
            textInputAction: TextInputAction.done,
            onChanged: (_) {},
          ),

          FormField<void>(
            builder: (_) => const SizedBox.shrink(),
            validator: (_) {
              if (_region == null) return 'Region is required';
              ref.read(registrationFormProvider.notifier).updateStep2(
                regionId: _region?.id,
                regionName: _region?.name,
                districtId: _district?.id,
                districtName: _district?.name,
                constituencyId: _constituency?.id,
                constituencyName: _constituency?.name,
                pollingStationId: _pollingStation?.id,
                pollingStationName: _pollingStation?.name,
                ward: _ward.text.trim().isEmpty ? null : _ward.text.trim(),
                branch: _branch.text.trim().isEmpty ? null : _branch.text.trim(),
                residentialAddress: _residentialAddress.text.trim().isEmpty ? null : _residentialAddress.text.trim(),
                residenceTown: _residenceTown.text.trim().isEmpty ? null : _residenceTown.text.trim(),
              );
              return null;
            },
          ),
        ],
      ),
    );
  }
}

// ─── Step 3: Membership ──────────────────────────────────────────────────────

class _Step3Membership extends ConsumerStatefulWidget {
  final GlobalKey<FormState> formKey;
  const _Step3Membership({required this.formKey});

  @override
  ConsumerState<_Step3Membership> createState() => _Step3MembershipState();
}

class _Step3MembershipState extends ConsumerState<_Step3Membership> {
  late TextEditingController _profession;
  late TextEditingController _partyPosition;
  late TextEditingController _otherParty;
  String? _membershipType;
  String? _preferredRole;
  String? _employmentStatus;
  String? _highestQualification;
  List<String> _skills = [];

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

  @override
  Widget build(BuildContext context) {
    return Form(
      key: widget.formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Membership Details', style: AppTextStyles.h2()),
          const SizedBox(height: 24),

          // Membership Type
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Membership Type *', style: AppTextStyles.label()),
              const SizedBox(height: 6),
              _DropdownField<String>(
                hint: 'Select type',
                value: _membershipType,
                icon: PhosphorIconsRegular.identificationCard,
                items: _membershipTypes.keys.toList(),
                itemLabel: (k) => _membershipTypes[k]!,
                validator: (v) => v == null ? 'Membership type is required' : null,
                onChanged: (v) => setState(() => _membershipType = v),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Preferred Role
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Preferred Role', style: AppTextStyles.label()),
              const SizedBox(height: 6),
              _DropdownField<String>(
                hint: 'Select role',
                value: _preferredRole,
                icon: PhosphorIconsRegular.star,
                items: _roles.keys.toList(),
                itemLabel: (k) => _roles[k]!,
                onChanged: (v) => setState(() => _preferredRole = v),
              ),
            ],
          ),
          const SizedBox(height: 16),

          NdcTextField(
            label: 'Profession',
            hint: 'e.g. Teacher, Farmer, Trader',
            icon: PhosphorIconsRegular.briefcase,
            controller: _profession,
            textInputAction: TextInputAction.next,
            onChanged: (_) {},
          ),
          const SizedBox(height: 16),

          NdcTextField(
            label: 'Party Position Held',
            hint: 'Optional — e.g. Branch Secretary',
            icon: PhosphorIconsRegular.medal,
            controller: _partyPosition,
            textInputAction: TextInputAction.next,
            onChanged: (_) {},
          ),
          const SizedBox(height: 16),

          NdcTextField(
            label: 'Previously a Member of Another Party?',
            hint: 'Optional — name of party',
            icon: PhosphorIconsRegular.flag,
            controller: _otherParty,
            textInputAction: TextInputAction.done,
            onChanged: (_) {},
          ),
          const SizedBox(height: 16),

          // Employment Status
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Employment Status', style: AppTextStyles.label()),
              const SizedBox(height: 6),
              _DropdownField<String>(
                hint: 'Select status',
                value: _employmentStatus,
                icon: PhosphorIconsRegular.briefcase,
                items: _employmentStatuses,
                itemLabel: (v) => v,
                onChanged: (v) => setState(() => _employmentStatus = v),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Highest Qualification
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Highest Academic Qualification', style: AppTextStyles.label()),
              const SizedBox(height: 6),
              _DropdownField<String>(
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

          // Skills
          Text('Skills', style: AppTextStyles.label()),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _skillOptions.map((skill) {
              final selected = _skills.contains(skill);
              return GestureDetector(
                onTap: () {
                  setState(() {
                    if (selected) {
                      _skills.remove(skill);
                    } else {
                      _skills.add(skill);
                    }
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.canopyGreen : AppColors.fillMuted,
                    borderRadius: AppRadii.borderPill,
                    border: Border.all(
                      color: selected ? AppColors.canopyGreen : AppColors.hairline,
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

          FormField<void>(
            builder: (_) => const SizedBox.shrink(),
            validator: (_) {
              if (_membershipType == null) return 'Membership type is required';
              ref.read(registrationFormProvider.notifier).updateStep3(
                membershipType: _membershipType,
                preferredRole: _preferredRole,
                profession: _profession.text.trim().isEmpty ? null : _profession.text.trim(),
                partyPosition: _partyPosition.text.trim().isEmpty ? null : _partyPosition.text.trim(),
                otherParty: _otherParty.text.trim().isEmpty ? null : _otherParty.text.trim(),
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

// ─── Step 4: Photo & Review ──────────────────────────────────────────────────

class _Step4PhotoReview extends ConsumerStatefulWidget {
  final GlobalKey<FormState> formKey;
  const _Step4PhotoReview({required this.formKey});

  @override
  ConsumerState<_Step4PhotoReview> createState() => _Step4PhotoReviewState();
}

class _Step4PhotoReviewState extends ConsumerState<_Step4PhotoReview> {
  final _picker = ImagePicker();
  bool _pickingPhoto = false;

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
        ref.read(registrationFormProvider.notifier).setPhotoLocalPath(image.path);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not access camera/gallery: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _pickingPhoto = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final formData = ref.watch(registrationFormProvider);

    return Form(
      key: widget.formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Photo & Review', style: AppTextStyles.h2()),
          const SizedBox(height: 4),
          Text('Add a photo and review your details before submitting.', style: AppTextStyles.small()),
          const SizedBox(height: 24),

          // Photo picker
          _PhotoPicker(
            localPath: formData.photoLocalPath,
            picking: _pickingPhoto,
            onCamera: () => _pickPhoto(ImageSource.camera),
            onGallery: () => _pickPhoto(ImageSource.gallery),
            onRemove: () => ref.read(registrationFormProvider.notifier).setPhotoLocalPath(null),
          ),
          const SizedBox(height: 24),

          // Summary card
          _ReviewSummary(data: formData),
        ],
      ),
    );
  }
}

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
        Text('Member Photo', style: AppTextStyles.label()),
        const SizedBox(height: 10),
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
                  errorBuilder: (_, __, ___) => _buildPlaceholder(),
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
                    child: const PhosphorIcon(PhosphorIconsFill.trash, size: 16, color: AppColors.surface),
                  ),
                ),
              ),
            ],
          )
        else
          _buildPlaceholder(),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: NdcButton(
                label: 'Camera',
                variant: NdcButtonVariant.secondary,
                loading: picking,
                icon: const PhosphorIcon(PhosphorIconsFill.camera, size: 16, color: AppColors.canopyGreen),
                onPressed: onCamera,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: NdcButton(
                label: 'Gallery',
                variant: NdcButtonVariant.secondary,
                icon: const PhosphorIcon(PhosphorIconsFill.image, size: 16, color: AppColors.canopyGreen),
                onPressed: onGallery,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      height: 140,
      decoration: BoxDecoration(
        color: AppColors.fillMuted,
        borderRadius: AppRadii.borderMd,
        border: Border.all(color: AppColors.hairline, style: BorderStyle.solid),
      ),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PhosphorIcon(PhosphorIconsRegular.camera, size: 36, color: AppColors.textMuted),
            SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _ReviewSummary extends StatelessWidget {
  final RegistrationFormData data;
  const _ReviewSummary({required this.data});

  @override
  Widget build(BuildContext context) {
    final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final dob = data.dateOfBirth;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.borderMd,
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Summary', style: AppTextStyles.h3()),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          _Row('Name', '${data.firstName} ${data.lastName}'),
          _Row('Phone', data.phone.isNotEmpty ? data.phone : '—'),
          if (dob != null) _Row('Date of Birth', '${dob.day} ${months[dob.month - 1]} ${dob.year}'),
          if (data.gender != null) _Row('Gender', data.gender!),
          if (data.regionName != null) _Row('Region', data.regionName!),
          if (data.districtName != null) _Row('District', data.districtName!),
          if (data.constituencyName != null) _Row('Constituency', data.constituencyName!),
          if (data.pollingStationName != null) _Row('Polling Station', data.pollingStationName!),
          if (data.residentialAddress != null) _Row('Address', data.residentialAddress!),
          if (data.residenceTown != null) _Row('Town', data.residenceTown!),
          if (data.membershipType != null) _Row('Membership', data.membershipType!.replaceAll('_', ' ')),
          if (data.preferredRole != null) _Row('Preferred Role', data.preferredRole!),
          if (data.partyPosition != null) _Row('Party Position', data.partyPosition!),
          if (data.otherParty != null) _Row('Previous Party', data.otherParty!),
          if (data.skills.isNotEmpty) _Row('Skills', data.skills.join(', ')),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  const _Row(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: AppTextStyles.small()),
          ),
          Expanded(child: Text(value, style: AppTextStyles.bodyMedium())),
        ],
      ),
    );
  }
}

// ─── Shared: Dropdown widgets ────────────────────────────────────────────────

class _DropdownField<T> extends StatelessWidget {
  final String hint;
  final T? value;
  final PhosphorIconData icon;
  final List<T> items;
  final String Function(T) itemLabel;
  final void Function(T?) onChanged;
  final String? Function(T?)? validator;
  final bool enabled;

  const _DropdownField({
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
      value: value,
      hint: Text(hint, style: AppTextStyles.bodyLarge(color: AppColors.textMuted)),
      decoration: InputDecoration(
        prefixIcon: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: PhosphorIcon(icon, size: 20, color: AppColors.textMuted),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 48),
      ),
      items: enabled
          ? items.map((item) => DropdownMenuItem<T>(
                value: item,
                child: Text(itemLabel(item), style: AppTextStyles.bodyLarge()),
              )).toList()
          : [],
      onChanged: enabled ? onChanged : null,
      validator: validator != null ? (v) => validator!(v) : null,
      isExpanded: true,
    );
  }
}

class _AsyncDropdown<T> extends ConsumerWidget {
  final String label;
  final PhosphorIconData icon;
  final String hint;
  final AsyncValue<List<T>> asyncData;
  final T? selected;
  final String Function(T) itemLabel;
  final void Function(T?) onChanged;
  final String? Function()? validator;
  final bool enabled;

  const _AsyncDropdown({
    required this.label,
    required this.icon,
    required this.hint,
    required this.asyncData,
    required this.selected,
    required this.itemLabel,
    required this.onChanged,
    this.validator,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.label()),
        const SizedBox(height: 6),
        asyncData.when(
          data: (items) {
            // Guard: if selected is not in the loaded list, treat as null to
            // prevent DropdownButtonFormField assertion errors.
            final effectiveSelected = (selected != null && items.contains(selected)) ? selected : null;
            return _DropdownField<T>(
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
          loading: () => _loadingField(hint),
          error: (_, __) => _loadingField('Error loading options'),
        ),
      ],
    );
  }

  Widget _loadingField(String text) {
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
          Expanded(child: Text(text, style: AppTextStyles.bodyLarge(color: AppColors.mist))),
        ],
      ),
    );
  }
}

// ─── Gender segmented control ─────────────────────────────────────────────────

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
          onTap: () => onChanged('male'),
        ),
        const SizedBox(width: AppSpacing.sm),
        _GenderPill(
          label: 'Female',
          selected: value == 'female',
          onTap: () => onChanged('female'),
        ),
      ],
    );
  }
}

class _GenderPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _GenderPill({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 11),
        decoration: BoxDecoration(
          color: selected ? AppColors.canopyGreen : AppColors.fillMuted,
          borderRadius: AppRadii.borderPill,
          border: Border.all(
            color: selected ? AppColors.canopyGreen : AppColors.hairline,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.label(
            color: selected ? AppColors.surface : AppColors.mist,
          ),
        ),
      ),
    );
  }
}

// ── Save success overlay (Lottie checkmark → auto-dismiss) ───────────────────

class _SaveSuccessOverlay extends StatelessWidget {
  final String message;
  const _SaveSuccessOverlay({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 40),
          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadii.borderLg,
            boxShadow: AppShadows.e2,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LottieSuccess(
                size: 72,
                onComplete: () {
                  if (context.mounted) Navigator.of(context).pop();
                },
              ),
              const SizedBox(height: 12),
              Text(message,
                  style: AppTextStyles.body(),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
