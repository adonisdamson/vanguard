import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../application/location_providers.dart';
import '../../application/offline_queue.dart';
import '../../application/registration_form_notifier.dart';
import '../../data/capture_metadata_service.dart';
import '../../data/member_repository.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/theme/app_radii.dart';
import '../../../../shared/theme/app_shadows.dart';
import '../../../../shared/theme/app_text_styles.dart';
import '../../../../shared/widgets/form_scaffold.dart';
import '../../../../shared/widgets/lottie_loader.dart';
import 'registration_tab_electoral.dart';
import 'registration_tab_party.dart';
import 'registration_tab_personal.dart';

const _tabLabels = ['Personal', 'Electoral', 'Party & Livelihood'];

class RegistrationScreen extends ConsumerStatefulWidget {
  /// When set, the screen edits an existing (pending) member instead of
  /// creating a new one. Personnel may only edit their own pending records.
  final String? memberId;
  const RegistrationScreen({super.key, this.memberId});

  @override
  ConsumerState<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends ConsumerState<RegistrationScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  int _sessionCount = 0;
  bool _submitting = false;
  String? _submitError;

  bool get _isEdit => widget.memberId != null;
  bool _loadingMember = false;
  String? _loadError;

  final _formKeys = List.generate(3, (_) => GlobalKey<FormState>());

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _tabs.addListener(() => setState(() {}));
    if (_isEdit) {
      _loadingMember = true;
      _loadForEdit();
    }
  }

  // Fetch the member row and seed the form BEFORE the tabs build, so each tab's
  // initState reads the prefilled values (the electoral tab restores its
  // cascading dropdowns from the seeded *_id fields).
  Future<void> _loadForEdit() async {
    try {
      final row = await MemberRepository().fetchFullMember(widget.memberId!);
      if (!mounted) return;
      ref
          .read(registrationFormProvider.notifier)
          .seed(RegistrationFormData.fromMember(row));
      setState(() => _loadingMember = false);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingMember = false;
        _loadError =
            "Couldn't load this submission. Check your connection and try again.";
      });
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  bool _validateTab(int i) => _formKeys[i].currentState?.validate() ?? false;

  bool _validateAll() {
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
            'Phone ${data.phone} matches an existing record: '
            '${res['first_name']} ${res['last_name']}.',
          );
          if (!proceed) return false;
        }
      } catch (e) {
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
            '${data.firstName} ${data.lastName} with that date of birth '
            'already exists.',
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
                    style:
                        AppTextStyles.bodyMedium(color: AppColors.umbrellaRed)),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<(String?, bool)> _doInsert(
      RegistrationFormData formData, String userId, MemberRepository repo) async {
    bool photoFailed = false;
    if (formData.photoLocalPath != null) {
      try {
        final storagePath =
            await repo.uploadPhoto(formData.photoLocalPath!, userId);
        ref
            .read(registrationFormProvider.notifier)
            .setPhotoStoragePath(storagePath);
      } catch (_) {
        photoFailed = true;
      }
    }
    final updatedForm = ref.read(registrationFormProvider);
    final result = await repo.insertMember(updatedForm.toInsertMap(userId));
    return (result['id'], photoFailed);
  }

  // Save edits to an existing pending member. No duplicate check, no metadata
  // capture, no offline queue — editing requires connectivity.
  Future<void> _submitEdit() async {
    if (!_validateAll()) {
      setState(() => _submitError = 'Please fix errors before saving.');
      return;
    }
    _saveAll();

    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      setState(() =>
          _submitError = 'Your session has expired. Sign in again to save.');
      return;
    }

    setState(() {
      _submitting = true;
      _submitError = null;
    });

    final repo = MemberRepository();
    try {
      final form = ref.read(registrationFormProvider);
      var photoFailed = false;
      // Upload only if the operator picked a NEW photo this session.
      if (form.photoLocalPath != null) {
        try {
          final path = await repo.uploadPhoto(form.photoLocalPath!, session.user.id);
          ref.read(registrationFormProvider.notifier).setPhotoStoragePath(path);
        } catch (_) {
          photoFailed = true;
        }
      }
      final updated = ref.read(registrationFormProvider);
      await repo.updateMember(widget.memberId!, updated.toUpdateMap());

      if (!mounted) return;
      HapticFeedback.mediumImpact();
      ref.read(registrationFormProvider.notifier).reset();
      if (photoFailed) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
            'Changes saved — but the new photo failed to upload. Try again later.',
            style: AppTextStyles.bodyMedium(color: AppColors.surface),
          ),
          backgroundColor: AppColors.umbrellaRed,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
        ));
      }
      context.pop(true); // signal my-submissions to refresh
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _submitError = _isNetworkError(e)
            ? 'You appear to be offline. Reconnect to save your changes.'
            : 'Could not save changes. Please try again.';
      });
    }
  }

  void _captureMetadata(String memberId) async {
    final pos = await CaptureMetadataService.requestLocation();
    CaptureMetadataService.capture(memberId,
            lat: pos?.latitude, lng: pos?.longitude)
        .ignore();
  }

  Future<void> _submit({bool addAnother = false}) async {
    if (!_validateAll()) {
      setState(() =>
          _submitError = 'Please fix errors in all tabs before submitting.');
      return;
    }
    _saveAll();

    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      setState(() =>
          _submitError = 'Your session has expired. Sign in again to submit.');
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: AppColors.statusPending,
      content: Row(children: [
        const PhosphorIcon(PhosphorIconsFill.cloudSlash,
            size: 18, color: AppColors.surface),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            "Saved offline — will sync when you're back online.",
            style: AppTextStyles.body(color: AppColors.surface),
          ),
        ),
      ]),
      duration: const Duration(seconds: 4),
    ));
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
        content:
            Text('Your progress will be lost.', style: AppTextStyles.body()),
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
            child: Text('Discard',
                style:
                    AppTextStyles.bodyMedium(color: AppColors.umbrellaRed)),
          ),
        ],
      ),
    );
    if (exit == true && context.mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    if (_isEdit && _loadingMember) {
      return const Scaffold(
        backgroundColor: AppColors.canvas,
        body: Center(child: LottieLoader(size: 96)),
      );
    }
    if (_isEdit && _loadError != null) {
      return Scaffold(
        backgroundColor: AppColors.canvas,
        appBar: AppBar(
          backgroundColor: AppColors.deepCanopy,
          elevation: 0,
          leading: IconButton(
            tooltip: 'Back',
            icon: const PhosphorIcon(PhosphorIconsRegular.arrowLeft,
                color: AppColors.surface, size: 22),
            onPressed: () => context.pop(),
          ),
          title: Text('Edit member', style: AppTextStyles.appBarTitle()),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const PhosphorIcon(PhosphorIconsRegular.warningCircle,
                    size: 48, color: AppColors.inkMuted),
                const SizedBox(height: 16),
                Text(_loadError!,
                    textAlign: TextAlign.center, style: AppTextStyles.body()),
                const SizedBox(height: 20),
                OutlinedButton(
                  onPressed: () => setState(() {
                    _loadError = null;
                    _loadingMember = true;
                    _loadForEdit();
                  }),
                  child: const Text('Try again'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return FormScaffold(
      appBar: AppBar(
        backgroundColor: AppColors.deepCanopy,
        elevation: 0,
        leading: _tabs.index > 0
            ? IconButton(
                tooltip: 'Previous step',
                icon: const PhosphorIcon(PhosphorIconsRegular.arrowLeft,
                    color: AppColors.surface, size: 22),
                onPressed: _prevTab,
              )
            : IconButton(
                tooltip: 'Discard registration',
                icon: const PhosphorIcon(PhosphorIconsRegular.x,
                    color: AppColors.surface, size: 22),
                onPressed: () => _confirmExit(context),
              ),
        title: _isEdit
            ? Text('Edit member', style: AppTextStyles.appBarTitle())
            : _sessionCount > 0
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Register member',
                          style: AppTextStyles.appBarTitle()),
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
        // No swipe: forces Continue (which validates before advancing).
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _scrollable(RegistrationTabPersonal(formKey: _formKeys[0])),
          _scrollable(RegistrationTabElectoral(formKey: _formKeys[1])),
          _scrollable(RegistrationTabParty(formKey: _formKeys[2])),
        ],
      ),
      actionBar: FormActionBar(
        primaryLabel: _tabs.index == 2
            ? (_isEdit ? 'Save changes' : 'Submit')
            : 'Continue',
        onPrimary: _tabs.index == 2
            ? () => (_isEdit ? _submitEdit() : _submit())
            : _nextTab,
        loading: _submitting,
        primaryIcon: PhosphorIcon(
            _tabs.index == 2
                ? PhosphorIconsFill.check
                : PhosphorIconsFill.arrowLineRight,
            size: 18,
            color: AppColors.surface),
        onBack: _tabs.index > 0 ? _prevTab : null,
        error: _submitError,
        secondaryAction: (_tabs.index == 2 && !_isEdit)
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

  Widget _scrollable(Widget child) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: child,
      );
}

// ── Step progress strip ───────────────────────────────────────────────────────

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
            final stepIndex = i ~/ 2;
            final completed = stepIndex < current;
            return Expanded(
              child: Container(
                height: 2,
                color: completed ? AppColors.canopyGreen : AppColors.hairline,
                margin: const EdgeInsets.symmetric(horizontal: 6),
              ),
            );
          }
          final stepIndex = i ~/ 2;
          return _StepDot(
            index: stepIndex,
            isActive: stepIndex == current,
            isCompleted: stepIndex < current,
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
    if (isCompleted || isActive) {
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
                ? const PhosphorIcon(PhosphorIconsFill.check,
                    size: 14, color: AppColors.surface)
                : Text('${index + 1}',
                    style: AppTextStyles.badge(color: textColor)),
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

// ── Save success overlay ──────────────────────────────────────────────────────

class _SaveSuccessOverlay extends StatefulWidget {
  final String message;
  const _SaveSuccessOverlay({required this.message});

  @override
  State<_SaveSuccessOverlay> createState() => _SaveSuccessOverlayState();
}

class _SaveSuccessOverlayState extends State<_SaveSuccessOverlay> {
  Timer? _fallback;

  @override
  void initState() {
    super.initState();
    // If Lottie's onComplete never fires (missing asset, render issue),
    // dismiss automatically after 2.5 s so the dialog can't get stuck.
    _fallback = Timer(const Duration(milliseconds: 2500), _dismiss);
  }

  @override
  void dispose() {
    _fallback?.cancel();
    super.dispose();
  }

  void _dismiss() {
    if (mounted) Navigator.of(context).pop();
  }

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
              LottieSuccess(size: 72, onComplete: _dismiss),
              const SizedBox(height: 12),
              Text(widget.message,
                  style: AppTextStyles.body(), textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
