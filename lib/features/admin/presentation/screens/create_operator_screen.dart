import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../data/operator_repository.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/theme/app_radii.dart';
import '../../../../shared/theme/app_spacing.dart';
import '../../../../shared/theme/app_text_styles.dart';
import '../../../../shared/widgets/canopy_arc.dart';
import '../../../../shared/widgets/ndc_button.dart';
import '../../../../shared/widgets/ndc_text_field.dart';

class CreateOperatorScreen extends StatefulWidget {
  const CreateOperatorScreen({super.key});

  @override
  State<CreateOperatorScreen> createState() => _CreateOperatorScreenState();
}

class _CreateOperatorScreenState extends State<CreateOperatorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  String _selectedRole = 'personnel';
  bool _loading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      await OperatorRepository().createOperator(
        fullName: _nameCtrl.text.trim(),
        email: _emailCtrl.text.trim().toLowerCase(),
        role: _selectedRole,
        phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
      );
      HapticFeedback.mediumImpact();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: AppColors.canopyGreen,
          content: Text(
            'Operator account created. A temporary password will be sent to ${_emailCtrl.text.trim()}.',
            style: AppTextStyles.body(color: AppColors.surface),
          ),
          duration: const Duration(seconds: 5),
        ));
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: AppColors.umbrellaRed,
          content: Text('Failed to create operator: $e', style: AppTextStyles.body(color: AppColors.surface)),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        backgroundColor: AppColors.deepCanopy,
        elevation: 0,
        leading: IconButton(
          icon: const PhosphorIcon(PhosphorIconsRegular.arrowLeft, color: AppColors.surface, size: 22),
          onPressed: () => context.pop(),
        ),
        title: Text('Create operator', style: AppTextStyles.appBarTitle()),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(4),
          child: CanopyStripe(height: 4),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Notice banner
              Container(
                padding: const EdgeInsets.all(AppSpacing.base),
                decoration: BoxDecoration(
                  color: AppColors.greenTint,
                  borderRadius: AppRadii.borderMd,
                  border: Border.all(color: AppColors.canopyGreen.withValues(alpha: 0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const PhosphorIcon(PhosphorIconsRegular.info, size: 18, color: AppColors.canopyGreen),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'A Supabase Auth account will be created and the operator will receive a password reset email. No operator can self-register.',
                        style: AppTextStyles.small(color: AppColors.canopyGreen),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              Text('Personal details', style: AppTextStyles.h3()),
              const SizedBox(height: 14),

              NdcTextField(
                label: 'Full Name',
                hint: 'e.g. Kwame Mensah',
                controller: _nameCtrl,
                icon: PhosphorIconsRegular.user,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Full name is required' : null,
              ),
              const SizedBox(height: 16),

              NdcTextField(
                label: 'Email Address',
                hint: 'operator@ndc.gh',
                controller: _emailCtrl,
                icon: PhosphorIconsRegular.envelope,
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Email is required';
                  if (!v.contains('@') || !v.contains('.')) return 'Enter a valid email';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              NdcTextField(
                label: 'Phone Number (optional)',
                hint: '+233 XX XXX XXXX',
                controller: _phoneCtrl,
                icon: PhosphorIconsRegular.phone,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 24),

              Text('Role', style: AppTextStyles.h3()),
              const SizedBox(height: 8),
              Text('Assign the correct role — this determines what the operator can see and do.',
                  style: AppTextStyles.small()),
              const SizedBox(height: 14),

              _RoleOption(
                value: 'personnel',
                groupValue: _selectedRole,
                title: 'Personnel',
                subtitle: 'Register and manage own member submissions',
                icon: PhosphorIconsFill.userCircle,
                color: AppColors.canopyGreen,
                onChanged: (v) => setState(() => _selectedRole = v!),
              ),
              const SizedBox(height: AppSpacing.sm),
              _RoleOption(
                value: 'higher_authority',
                groupValue: _selectedRole,
                title: 'Higher Authority (Coordinator)',
                subtitle: 'Review pending registrations, view all members, export data',
                icon: PhosphorIconsFill.userCircleCheck,
                color: AppColors.statusPending,
                onChanged: (v) => setState(() => _selectedRole = v!),
              ),
              const SizedBox(height: AppSpacing.sm),
              _RoleOption(
                value: 'admin',
                groupValue: _selectedRole,
                title: 'Administrator',
                subtitle: 'Full system access including operator management',
                icon: PhosphorIconsFill.shieldStar,
                color: AppColors.umbrellaRed,
                onChanged: (v) => setState(() => _selectedRole = v!),
              ),
              const SizedBox(height: 32),

              NdcButton(
                label: 'Create Operator Account',
                loading: _loading,
                onPressed: _loading ? null : _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleOption extends StatelessWidget {
  final String value;
  final String groupValue;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final void Function(String?) onChanged;

  const _RoleOption({
    required this.value,
    required this.groupValue,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final selected = value == groupValue;
    return GestureDetector(
      onTap: () => onChanged(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(AppSpacing.base),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.06) : AppColors.surface,
          borderRadius: AppRadii.borderMd,
          border: Border.all(
            color: selected ? color : AppColors.hairline,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: selected ? 0.15 : 0.08),
                borderRadius: AppRadii.borderSm,
              ),
              child: PhosphorIcon(icon, size: 20, color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.bodyMedium(color: selected ? color : AppColors.textPrimary)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: AppTextStyles.small()),
                ],
              ),
            ),
            Radio<String>(
              value: value,
              groupValue: groupValue,
              onChanged: onChanged,
              activeColor: color,
            ),
          ],
        ),
      ),
    );
  }
}
