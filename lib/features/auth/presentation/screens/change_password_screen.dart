import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/errors/app_error_mapper.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/theme/app_spacing.dart';
import '../../../../shared/theme/app_text_styles.dart';
import '../../../../shared/widgets/form_scaffold.dart';
import '../../../../shared/widgets/ndc_text_field.dart';
import '../../application/user_role_provider.dart';

/// In-app password change for the signed-in user. No emails, no links, no
/// leaving the app — the session is already proof of identity.
class ChangePasswordScreen extends ConsumerStatefulWidget {
  /// Forced first-login change: the operator can't leave until they replace the
  /// admin-set password. No back button, and success routes them to their home
  /// after clearing the must_change_password flag.
  final bool forced;
  const ChangePasswordScreen({super.key, this.forced = false});

  @override
  ConsumerState<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final client = Supabase.instance.client;
      await client.auth.updateUser(UserAttributes(password: _passCtrl.text));

      if (widget.forced) {
        // Clear the flag on our own row (trigger allows self-updates that don't
        // touch role/is_active/email), then re-gate to the role home.
        final uid = client.auth.currentUser!.id;
        await client
            .from('app_users')
            .update({'must_change_password': false}).eq('id', uid);
        ref.invalidate(appUserProvider);
      }
      HapticFeedback.mediumImpact();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: AppColors.brand,
        content: Text(
            widget.forced
                ? 'Password set. Welcome to Tema West.'
                : 'Password updated. Use it on your next sign-in.',
            style: AppTextStyles.body(color: AppColors.surface)),
      ));
      if (widget.forced) {
        context.go('/resolving');
      } else {
        context.pop();
      }
    } catch (e, st) {
      if (mounted) {
        setState(() {
          _error = AppErrorMapper.forAuth(e, st) ??
              "Couldn't update the password. Try again.";
          _loading = false;
        });
      }
    } finally {
      if (mounted && _loading) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FormScaffold(
      appBar: AppBar(
        backgroundColor: AppColors.deepCanopy,
        elevation: 0,
        automaticallyImplyLeading: false,
        // No escape in forced mode — the operator must set their own password.
        leading: widget.forced
            ? null
            : IconButton(
                tooltip: 'Back',
                icon: const PhosphorIcon(PhosphorIconsRegular.arrowLeft,
                    color: AppColors.surface, size: 22),
                onPressed: () => context.pop(),
              ),
        title: Text(widget.forced ? 'Set your password' : 'Change password',
            style: AppTextStyles.appBarTitle()),
      ),
      actionBar: FormActionBar(
        primaryLabel: 'Update password',
        onPrimary: _submit,
        loading: _loading,
        error: _error,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.xl,
            AppSpacing.screenH, AppSpacing.h1),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.forced
                    ? 'Your account was created with a temporary password. Set '
                        'your own now to continue — only you should know it.'
                    : 'Choose a new password. It takes effect immediately — no email involved.',
                style: AppTextStyles.body(color: AppColors.inkMuted),
              ),
              const SizedBox(height: AppSpacing.xl),
              NdcTextField(
                label: 'New password',
                hint: 'At least 8 characters',
                icon: PhosphorIconsRegular.lock,
                controller: _passCtrl,
                obscureText: true,
                textInputAction: TextInputAction.next,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Password is required';
                  if (v.length < 8) return 'Use at least 8 characters';
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.base),
              NdcTextField(
                label: 'Confirm new password',
                hint: '••••••••',
                icon: PhosphorIconsRegular.lockKey,
                controller: _confirmCtrl,
                obscureText: true,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
                validator: (v) =>
                    v != _passCtrl.text ? "Passwords don't match" : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
