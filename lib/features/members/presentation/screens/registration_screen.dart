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
import '../../../../shared/theme/app_shadows.dart';
import '../../../../shared/widgets/form_scaffold.dart';
import '../../../../shared/widgets/ndc_button.dart';
import '../../../../shared/widgets/ndc_text_field.dart';
import '../../../../shared/widgets/lottie_loader.dart';

const _tabLabels = ['Personal', 'Electoral', 'Party & Livelihood'];

class RegistrationScreen extends ConsumerStatefulWidget {
  const RegistrationScreen({super.key});

  @override
  ConsumerState<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends ConsumerState<RegistrationScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  int _sessionCount = 0;
  bool _submitting = false;
  String? _submitError;

  final _formKeys = List.generate(3, (_) => GlobalKey<FormState>());

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _tabs.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  bool _validateTab(int i) => _formKeys[i].currentState?.validate() ?? false;

  bool _validateAll() {
    // Must validate all three to trigger error UI on every tab
    final t0 = _formKeys[0].currentState?.validate() ?? false;
    final t1 = _formKeys[1].currentState?.validate() ?? false;
    final t2 = _formKeys[2].currentState?.validate() ?? false;
    return t0 && t1 && t2;
  }

  void _saveAll() {
    for (final k in _formKeys) {
      k.currentState?.save();
    }
  }

  void _nextTab() {
    // Never fail silently: a validation failure must say so in the pinned
    // action bar (always visible), or the button just looks dead — the field
    // errors alone can sit above the fold where the user can't see them.
    if (!_validateTab(_tabs.index)) {
      HapticFeedback.heavyImpact();
      setState(() => _submitError =
          'Complete the required fields marked in red above, then tap Continue.');
      return;
    }
    _formKeys[_tabs.index].currentState!.save();
    setState(() => _submitError = null);
    if (_tabs.index < 2) _tabs.animateTo(_tabs.index + 1);
  }

  void _prevTab() {
    setState(() => _submitError = null);
    if (_tabs.index > 0) _tabs.animateTo(_tabs.index - 1);
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
      } catch (e) {
        // Fail open by design (a flaky network must not block registration),
        // but never swallow invisibly.
        debugPrint('[duplicate check phone] $e');
      }
    }
    if (data.dateOfBirth != null) {
      final dob = data.dateOfBirth!;
      final dobStr =
          '${dob.year}-${dob.month.toString().padLeft(2, '0')}-${dob.day.toString().padLeft(2, '0')}';
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
      } catch (e) {
        debugPrint('[duplicate check name+dob] $e');
      }
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
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel')),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text('Register anyway',
                    style: AppTextStyles.bodyMedium(color: AppColors.umbrellaRed)),
              ),
            ],
          ),
        ) ??
        false;
  }

  // Returns (memberId, photoUploadFailed) — member is always saved, photo is best-effort.
  Future<(String?, bool)> _doInsert(
      RegistrationFormData formData, String userId, MemberRepository repo) async {
    bool photoFailed = false;
    if (formData.photoLocalPath != null) {
      try {
        final storagePath = await repo.uploadPhoto(formData.photoLocalPath!, userId);
        ref.read(registrationFormProvider.notifier).setPhotoStoragePath(storagePath);
      } catch (_) {
        photoFailed = true;
      }
    }
    final updatedForm = ref.read(registrationFormProvider);
    final result = await repo.insertMember(updatedForm.toInsertMap(userId));
    return (result['id'], photoFailed);
  }

  void _captureMetadata(String memberId) async {
    final pos = await CaptureMetadataService.requestLocation();
    CaptureMetadataService.capture(memberId,
            lat: pos?.latitude, lng: pos?.longitude)
        .ignore();
  }

  Future<void> _submit({bool addAnother = false}) async {
    if (!_validateAll()) {
      setState(() => _submitError = 'Please fix errors in all tabs before submitting.');
      return;
    }
    _saveAll();

    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      // Never a silent dead button — tell the user what's wrong.
      setState(() => _submitError =
          'Your session has expired. Sign in again to submit.');
      return;
    }

    final formData = ref.read(registrationFormProvider);
    final proceed = await _checkDuplicates(formData);
    if (!proceed || !mounted) return;

    setState(() {
      _submitting = true;
      _submitError = null;
    });

    final repo = MemberRepository();
    bool isOffline = false;
    String? memberId;
    bool photoFailed = false;

    try {
      (memberId, photoFailed) = await _doInsert(formData, session.user.id, repo);
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

    if (photoFailed && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          'Member saved — photo upload failed. Reconnect and reopen to retry.',
          style: AppTextStyles.bodyMedium(color: AppColors.surface),
        ),
        backgroundColor: AppColors.umbrellaRed,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
      ));
    }

    if (addAnother) {
      final retention = LocationRetention(
        region: null,
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
        _sessionCount++;
        _submitting = false;
        _submitError = null;
      });
      _tabs.animateTo(0);
      if (mounted) {
        _showSaveSuccess('Saved — member $_sessionCount of this session. Location kept.');
      }
    } else {
      ref.read(registrationFormProvider.notifier).reset();
      ref.read(locationRetentionProvider.notifier).state = null;
      setState(() => _submitting = false);
      if (isOffline) {
        _showOfflineSaved();
      } else {
        context.go('/home');
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
            const PhosphorIcon(PhosphorIconsFill.cloudSlash,
                size: 18, color: AppColors.surface),
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

  Future<void> _confirmExit(BuildContext context) async {
    final exit = await showDialog<bool>(
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
            child: Text('Discard', style: AppTextStyles.bodyMedium(color: AppColors.umbrellaRed)),
          ),
        ],
      ),
    );
    if (exit == true && context.mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return FormScaffold(
      appBar: AppBar(
        backgroundColor: AppColors.deepCanopy,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Discard registration',
          icon: const PhosphorIcon(PhosphorIconsRegular.x,
              color: AppColors.surface, size: 22),
          onPressed: () => _confirmExit(context),
        ),
        title: _sessionCount > 0
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Register member', style: AppTextStyles.appBarTitle()),
                  Text(
                    'Session · $_sessionCount saved',
                    style: AppTextStyles.caption(
                        color: AppColors.surface.withValues(alpha: 0.7)),
                  ),
                ],
              )
            : Text('Register member', style: AppTextStyles.appBarTitle()),
      ),
      header: _TabStrip(controller: _tabs),
      body: TabBarView(
        controller: _tabs,
        // No swipe — forces Continue button (validates before advancing)
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _scrollable(_Tab1Personal(formKey: _formKeys[0])),
          _scrollable(_Tab2Electoral(formKey: _formKeys[1])),
          _scrollable(_Tab3Party(formKey: _formKeys[2])),
        ],
      ),
      actionBar: FormActionBar(
        primaryLabel: _tabs.index == 2 ? 'Submit' : 'Continue',
        onPrimary: _tabs.index == 2 ? () => _submit() : _nextTab,
        loading: _submitting,
        primaryIcon: PhosphorIcon(
            _tabs.index == 2
                ? PhosphorIconsFill.check
                : PhosphorIconsFill.arrowRight,
            size: 18,
            color: AppColors.surface),
        onBack: _tabs.index > 0 ? _prevTab : null,
        error: _submitError,
        secondaryAction: _tabs.index == 2
            ? SizedBox(
                width: double.infinity,
                height: 44,
                child: OutlinedButton.icon(
                  onPressed:
                      _submitting ? null : () => _submit(addAnother: true),
                  icon: const PhosphorIcon(PhosphorIconsFill.userPlus,
                      size: 16, color: AppColors.canopyGreen),
                  label: Text('Save & add another',
                      style: AppTextStyles.bodyMedium(
                          color: AppColors.canopyGreen)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.canopyGreen),
                    shape: RoundedRectangleBorder(
                        borderRadius: AppRadii.borderSm),
                  ),
                ),
              )
            : null,
      ),
    );
  }

  // Bottom padding no longer needs to clear a floating bar — the action bar
  // is pinned outside the scroll area by FormScaffold.
  Widget _scrollable(Widget child) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: child,
      );
}

// ─── Tab Strip ────────────────────────────────────────────────────────────────

class _TabStrip extends StatelessWidget {
  final TabController controller;
  const _TabStrip({required this.controller});

  @override
  Widget build(BuildContext context) {
    final current = controller.index;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.hairline)),
      ),
      child: Row(
        children: List.generate(_tabLabels.length * 2 - 1, (i) {
          if (i.isOdd) {
            // Connector line between steps
            final stepIndex = i ~/ 2;
            final completed = stepIndex < current;
            return Expanded(
              child: Container(
                height: 2,
                color: completed ? AppColors.canopyGreen : AppColors.hairline,
                margin: const EdgeInsets.symmetric(horizontal: 6), // intentional: step connector gap
              ),
            );
          }
          final stepIndex = i ~/ 2;
          final isActive = stepIndex == current;
          final isCompleted = stepIndex < current;
          return _StepDot(
            index: stepIndex,
            isActive: isActive,
            isCompleted: isCompleted,
            label: _tabLabels[stepIndex],
          );
        }),
      ),
    );
  }
}

class _StepDot extends StatelessWidget {
  final int index;
  final bool isActive;
  final bool isCompleted;
  final String label;

  const _StepDot({
    required this.index,
    required this.isActive,
    required this.isCompleted,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color textColor;
    final Color borderColor;
    if (isCompleted) {
      bg = AppColors.canopyGreen;
      textColor = AppColors.surface;
      borderColor = AppColors.canopyGreen;
    } else if (isActive) {
      bg = AppColors.canopyGreen;
      textColor = AppColors.surface;
      borderColor = AppColors.canopyGreen;
    } else {
      bg = AppColors.fillMuted;
      textColor = AppColors.mist;
      borderColor = AppColors.hairline;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: bg,
            border: Border.all(color: borderColor, width: 2),
          ),
          child: Center(
            child: isCompleted
                ? const PhosphorIcon(PhosphorIconsFill.check, size: 14, color: AppColors.surface)
                : Text(
                    '${index + 1}',
                    style: AppTextStyles.badge(color: textColor),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: AppTextStyles.caption(
            color: isActive ? AppColors.canopyGreen : AppColors.mist,
          ).copyWith(fontWeight: isActive ? FontWeight.w600 : FontWeight.w400),
        ),
      ],
    );
  }
}

// ─── Tab 1: Personal ──────────────────────────────────────────────────────────

class _Tab1Personal extends ConsumerStatefulWidget {
  final GlobalKey<FormState> formKey;
  const _Tab1Personal({required this.formKey});

  @override
  ConsumerState<_Tab1Personal> createState() => _Tab1PersonalState();
}

class _Tab1PersonalState extends ConsumerState<_Tab1Personal>
    with AutomaticKeepAliveClientMixin {
  // Keep every tab mounted: _validateAll()/_saveAll() need all three
  // Form states alive, and Back must not wipe unsaved field edits.
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
    final months = [
      'Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec'
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // required by AutomaticKeepAliveClientMixin
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
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'First name is required' : null,
            onChanged: (_) {},
          ),
          const SizedBox(height: 16),

          NdcTextField(
            label: 'Last Name *',
            hint: 'e.g. Mensah',
            icon: PhosphorIconsRegular.person,
            controller: _lastName,
            textInputAction: TextInputAction.next,
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'Last name is required' : null,
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
                      const PhosphorIcon(PhosphorIconsRegular.calendarBlank,
                          size: 20, color: AppColors.textMuted),
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
            textInputAction: TextInputAction.next,
            validator: (v) {
              if (v != null && v.isNotEmpty && !v.contains('@')) {
                return 'Enter a valid email';
              }
              return null;
            },
            onChanged: (_) {},
          ),
          const SizedBox(height: 16),

          NdcTextField(
            label: 'Ghana Card / Voter ID',
            hint: 'GHA-XXXXXXXXX-X',
            icon: PhosphorIconsRegular.identificationCard,
            controller: _ghanaCardId,
            keyboardType: TextInputType.text,
            textInputAction: TextInputAction.done,
            onChanged: (_) {},
          ),

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

// ─── Tab 2: Electoral ─────────────────────────────────────────────────────────

class _Tab2Electoral extends ConsumerStatefulWidget {
  final GlobalKey<FormState> formKey;
  const _Tab2Electoral({required this.formKey});

  @override
  ConsumerState<_Tab2Electoral> createState() => _Tab2ElectoralState();
}

class _Tab2ElectoralState extends ConsumerState<_Tab2Electoral>
    with AutomaticKeepAliveClientMixin {
  // Keep every tab mounted: _validateAll()/_saveAll() need all three
  // Form states alive, and Back must not wipe unsaved field edits.
  @override
  bool get wantKeepAlive => true;

  late TextEditingController _ward;
  late TextEditingController _branch;
  late TextEditingController _residentialAddress;
  late TextEditingController _residenceTown;

  Region? _region;
  District? _district;
  Constituency? _constituency;
  PollingStation? _pollingStation;

  @override
  void initState() {
    super.initState();
    final d = ref.read(registrationFormProvider);
    _ward = TextEditingController(text: d.ward ?? '');
    _branch = TextEditingController(text: d.branch ?? '');
    _residentialAddress = TextEditingController(text: d.residentialAddress ?? '');
    _residenceTown = TextEditingController(text: d.residenceTown ?? '');

    if (d.regionId != null) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _restoreLocationObjects());
    }
  }

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
    super.build(context); // required by AutomaticKeepAliveClientMixin
    final regionsAsync = ref.watch(regionsProvider);
    final districtsAsync = ref.watch(districtsProvider);
    final constituenciesAsync = ref.watch(constituenciesProvider);
    final pollingStationsAsync = ref.watch(pollingStationsProvider);

    return Form(
      key: widget.formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Electoral Location', style: AppTextStyles.h2()),
          const SizedBox(height: 4),
          Text('Select the member\'s registration location',
              style: AppTextStyles.small()),
          const SizedBox(height: 24),

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
                _pollingStation = null;
              });
              ref.read(selectedRegionIdProvider.notifier).state = r?.id;
              ref.read(selectedDistrictIdProvider.notifier).state = null;
              ref.read(selectedConstituencyIdProvider.notifier).state = null;
              ref.read(selectedElectoralAreaProvider.notifier).state = null;
            },
            validator: () => _region == null ? 'Please select a region' : null,
            onRetry: () => ref.invalidate(regionsProvider),
          ),
          const SizedBox(height: 16),

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
                _pollingStation = null;
              });
              ref.read(selectedDistrictIdProvider.notifier).state = d?.id;
              ref.read(selectedConstituencyIdProvider.notifier).state = null;
              ref.read(selectedElectoralAreaProvider.notifier).state = null;
            },
            validator: () =>
                _district == null && _region != null ? 'Please select a district' : null,
            onRetry: () => ref.invalidate(districtsProvider),
          ),
          const SizedBox(height: 16),

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
                _pollingStation = null;
              });
              ref.read(selectedConstituencyIdProvider.notifier).state = c?.id;
              ref.read(selectedElectoralAreaProvider.notifier).state = null;
            },
            validator: () => _constituency == null && _district != null
                ? 'Please select a constituency'
                : null,
            onRetry: () => ref.invalidate(constituenciesProvider),
          ),
          const SizedBox(height: 16),

          _PollingStationField(
            asyncData: pollingStationsAsync,
            selected: _pollingStation,
            enabled: _constituency != null,
            onChanged: (p) => setState(() => _pollingStation = p),
            validator: () => _pollingStation == null && _constituency != null
                ? 'Please select a polling station'
                : null,
            onRetry: () => ref.invalidate(pollingStationsProvider),
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
            // This is the safety net when a dropdown is in a loading/error
            // state (its own FormField isn't in the tree then, so its
            // validator never runs). It must render its error VISIBLY —
            // an invisible failing validator makes Continue look dead.
            builder: (field) => field.hasError
                ? Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Row(
                      children: [
                        const PhosphorIcon(PhosphorIconsFill.warningCircle,
                            size: 16, color: AppColors.umbrellaRed),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(field.errorText!,
                              style: AppTextStyles.small(
                                  color: AppColors.umbrellaRed)),
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
            validator: (_) {
              if (_region == null) return 'Select a region to continue';
              if (_district == null) return 'Select a district to continue';
              if (_constituency == null) {
                return 'Select a constituency to continue';
              }
              if (_pollingStation == null) {
                return 'Select a polling station to continue';
              }
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
                residentialAddress: _residentialAddress.text.trim().isEmpty
                    ? null
                    : _residentialAddress.text.trim(),
                residenceTown: _residenceTown.text.trim().isEmpty
                    ? null
                    : _residenceTown.text.trim(),
              );
              return null;
            },
          ),
        ],
      ),
    );
  }
}

// ─── Tab 3: Party & Livelihood (+ Photo) ─────────────────────────────────────

class _Tab3Party extends ConsumerStatefulWidget {
  final GlobalKey<FormState> formKey;
  const _Tab3Party({required this.formKey});

  @override
  ConsumerState<_Tab3Party> createState() => _Tab3PartyState();
}

class _Tab3PartyState extends ConsumerState<_Tab3Party>
    with AutomaticKeepAliveClientMixin {
  // Keep every tab mounted: _validateAll()/_saveAll() need all three
  // Form states alive, and Back must not wipe unsaved field edits.
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
        ref.read(registrationFormProvider.notifier).setPhotoLocalPath(image.path);
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
    super.build(context); // required by AutomaticKeepAliveClientMixin
    final formData = ref.watch(registrationFormProvider);

    return Form(
      key: widget.formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Party & Livelihood', style: AppTextStyles.h2()),
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
          const SizedBox(height: 28),

          // ── Member Photo ──────────────────────────────────────────────────
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
            onRemove: () =>
                ref.read(registrationFormProvider.notifier).setPhotoLocalPath(null),
          ),

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

// ─── Photo Picker ─────────────────────────────────────────────────────────────

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
                    padding: const EdgeInsets.all(6), // intentional: tight circle remove-button
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
      height: 140,
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

// ─── Shared: Dropdown widgets ─────────────────────────────────────────────────

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
  final VoidCallback? onRetry;

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
    this.onRetry,
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
            final effectiveSelected =
                (selected != null && items.contains(selected)) ? selected : null;
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
          error: (_, _) => _RetryField(
            message: "Couldn't load ${label.replaceAll(' *', '').toLowerCase()}s",
            onRetry: onRetry,
          ),
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
          Expanded(
              child: Text(text,
                  style: AppTextStyles.bodyLarge(color: AppColors.mist))),
        ],
      ),
    );
  }
}

/// Load-failure state for a lookup field: says what failed and retries on
/// tap — never a dead "Error loading options" box the user can't act on.
class _RetryField extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  const _RetryField({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onRetry,
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          border: Border.all(
              color: AppColors.umbrellaRed.withValues(alpha: 0.5)),
          borderRadius: AppRadii.borderSm,
          color: AppColors.redTint,
        ),
        child: Row(
          children: [
            const PhosphorIcon(PhosphorIconsRegular.arrowClockwise,
                size: 20, color: AppColors.umbrellaRed),
            const SizedBox(width: 12),
            Expanded(
              child: Text('$message — tap to retry',
                  style:
                      AppTextStyles.bodyLarge(color: AppColors.umbrellaRed),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Polling station: searchable picker ──────────────────────────────────────

class _PollingStationField extends StatelessWidget {
  final AsyncValue<List<PollingStation>> asyncData;
  final PollingStation? selected;
  final bool enabled;
  final void Function(PollingStation?) onChanged;
  final String? Function() validator;
  final VoidCallback? onRetry;

  const _PollingStationField({
    required this.asyncData,
    required this.selected,
    required this.enabled,
    required this.onChanged,
    required this.validator,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Polling Station *', style: AppTextStyles.label()),
        const SizedBox(height: 6),
        FormField<PollingStation>(
          validator: (_) => validator(),
          builder: (field) => asyncData.when(
            data: (stations) {
              final label = selected == null
                  ? (enabled ? 'Search polling station' : 'Select constituency first')
                  : (selected!.stationCode != null
                      ? '${selected!.stationCode} — ${selected!.name}'
                      : selected!.name);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: enabled && stations.isNotEmpty
                        ? () async {
                            final picked = await showModalBottomSheet<PollingStation>(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: AppColors.surface,
                              shape: const RoundedRectangleBorder(borderRadius: AppRadii.sheetTop),
                              builder: (_) => _StationSearchSheet(stations: stations, selected: selected),
                            );
                            if (picked != null) {
                              onChanged(picked);
                              field.didChange(picked);
                            }
                          }
                        : null,
                    child: Container(
                      height: 52,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: field.hasError ? AppColors.umbrellaRed : AppColors.hairline,
                        ),
                        borderRadius: AppRadii.borderSm,
                        color: enabled ? AppColors.surface : AppColors.fillMuted,
                      ),
                      child: Row(
                        children: [
                          const PhosphorIcon(PhosphorIconsRegular.buildings,
                              size: 20, color: AppColors.textMuted),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              label,
                              style: selected == null
                                  ? AppTextStyles.bodyLarge(color: AppColors.textMuted)
                                  : AppTextStyles.bodyLarge(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (enabled)
                            const PhosphorIcon(PhosphorIconsRegular.magnifyingGlass,
                                size: 18, color: AppColors.mist),
                        ],
                      ),
                    ),
                  ),
                  if (field.hasError) ...[
                    const SizedBox(height: 6),
                    Text(field.errorText!, style: AppTextStyles.small(color: AppColors.umbrellaRed)),
                  ],
                ],
              );
            },
            loading: () => _stationField('Loading polling stations…'),
            error: (_, _) => _RetryField(
                message: "Couldn't load polling stations", onRetry: onRetry),
          ),
        ),
      ],
    );
  }

  Widget _stationField(String text) {
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
          const PhosphorIcon(PhosphorIconsRegular.buildings, size: 20, color: AppColors.mist),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: AppTextStyles.bodyLarge(color: AppColors.mist))),
        ],
      ),
    );
  }
}

class _StationSearchSheet extends StatefulWidget {
  final List<PollingStation> stations;
  final PollingStation? selected;
  const _StationSearchSheet({required this.stations, required this.selected});

  @override
  State<_StationSearchSheet> createState() => _StationSearchSheetState();
}

class _StationSearchSheetState extends State<_StationSearchSheet> {
  final _searchCtrl = TextEditingController();
  late List<PollingStation> _filtered;

  @override
  void initState() {
    super.initState();
    _filtered = widget.stations;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearch(String q) {
    final query = q.trim().toLowerCase();
    setState(() {
      _filtered = query.isEmpty
          ? widget.stations
          : widget.stations
              .where((s) =>
                  s.name.toLowerCase().contains(query) ||
                  (s.stationCode?.toLowerCase().contains(query) ?? false))
              .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: AppColors.hairline, borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Row(
                children: [
                  Expanded(child: Text('Polling station', style: AppTextStyles.h2())),
                  Text('${_filtered.length}', style: AppTextStyles.caption()),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _searchCtrl,
                autofocus: true,
                onChanged: _onSearch,
                decoration: const InputDecoration(
                  hintText: 'Search by name or code (e.g. COMM.2 or C240101)',
                  prefixIcon: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: PhosphorIcon(PhosphorIconsRegular.magnifyingGlass,
                        size: 20, color: AppColors.mist),
                  ),
                  prefixIconConstraints: BoxConstraints(minWidth: 44),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _filtered.isEmpty
                  ? Center(
                      child: Text('No matching station',
                          style: AppTextStyles.body(color: AppColors.mist)))
                  : ListView.builder(
                      controller: scrollController,
                      itemCount: _filtered.length,
                      itemBuilder: (_, i) {
                        final s = _filtered[i];
                        final isSel = s.id == widget.selected?.id;
                        return ListTile(
                          onTap: () => Navigator.pop(context, s),
                          leading: PhosphorIcon(
                            isSel ? PhosphorIconsFill.checkCircle : PhosphorIconsRegular.mapPin,
                            color: isSel ? AppColors.canopyGreen : AppColors.mist,
                            size: 22,
                          ),
                          title: Text(s.name, style: AppTextStyles.bodyMedium()),
                          subtitle: s.stationCode != null
                              ? Text(s.stationCode!, style: AppTextStyles.memberNumber())
                              : null,
                        );
                      },
                    ),
            ),
          ],
        ),
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

// ─── Save success overlay ─────────────────────────────────────────────────────

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
                  style: AppTextStyles.body(), textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
