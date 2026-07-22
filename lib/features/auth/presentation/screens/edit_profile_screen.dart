import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/app_error_mapper.dart';
import '../../application/user_role_provider.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/theme/app_text_styles.dart';
import '../../../../shared/widgets/form_scaffold.dart';
import '../../../../shared/widgets/ndc_text_field.dart';

/// Self-service profile edit for every signed-in user (mobile + web).
/// Updates the user's own full_name + contact phone. (Login phone/role are
/// managed by an admin; a user can't change their own role or login identity.)
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  bool _seeded = false;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await Supabase.instance.client.from('app_users').update({
        'full_name': _nameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
      }).eq('id', uid);
      ref.invalidate(appUserProvider);
      HapticFeedback.mediumImpact();
      if (mounted) context.pop(true);
    } catch (e, st) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = AppErrorMapper.forDataLoad(e, st);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(appUserProvider);
    // Seed the fields once from the loaded user.
    userAsync.whenData((u) {
      if (!_seeded && u != null) {
        _seeded = true;
        _nameCtrl.text = u.fullName;
        _phoneCtrl.text = u.phone ?? '';
      }
    });

    return FormScaffold(
      appBar: AppBar(
        backgroundColor: AppColors.deepCanopy,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Back',
          icon: const PhosphorIcon(PhosphorIconsRegular.arrowLeft,
              color: AppColors.surface, size: 22),
          onPressed: () => context.pop(),
        ),
        title: Text('Edit profile', style: AppTextStyles.appBarTitle()),
      ),
      actionBar: FormActionBar(
        primaryLabel: 'Save changes',
        loading: _saving,
        error: _error,
        onPrimary: _save,
        primaryIcon: const PhosphorIcon(PhosphorIconsFill.check,
            size: 18, color: AppColors.surface),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              NdcTextField(
                label: 'Full name',
                hint: 'Your name',
                controller: _nameCtrl,
                icon: PhosphorIconsRegular.user,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Full name is required' : null,
              ),
              const SizedBox(height: 16),
              NdcTextField(
                label: 'Contact phone',
                hint: 'e.g. 0244123456',
                controller: _phoneCtrl,
                icon: PhosphorIconsRegular.phone,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 14),
              Text(
                'To change the phone number you sign in with, ask an administrator.',
                style: AppTextStyles.small(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
