import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../../core/errors/app_error_mapper.dart';
import '../../data/operator_repository.dart';
import '../../../members/data/location_repository.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/theme/app_radii.dart';
import '../../../../shared/theme/app_spacing.dart';
import '../../../../shared/theme/app_text_styles.dart';
import '../../../../shared/widgets/form_scaffold.dart';
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
  final _passCtrl = TextEditingController();
  String _selectedRole = 'personnel';
  bool _loading = false;

  // Readable temp password: NDC- + 6 digits (10 chars, meets the 8+ rule).
  void _generatePassword() {
    final seed = DateTime.now().microsecondsSinceEpoch;
    final digits = (seed % 900000 + 100000).toString();
    setState(() => _passCtrl.text = 'NDC-$digits');
  }

  // Jurisdiction — optional; null means national/unrestricted scope
  final _locationRepo = LocationRepository();
  List<Region> _regions = [];
  List<District> _districts = [];
  List<Constituency> _constituencies = [];
  Region? _region;
  District? _district;
  Constituency? _constituency;
  bool _loadingRegions = true;
  bool _loadingDistricts = false;
  bool _loadingConstituencies = false;

  @override
  void initState() {
    super.initState();
    _loadingRegions = true;
    _locationRepo.fetchRegions().then((regions) {
      if (mounted) setState(() { _regions = regions; _loadingRegions = false; });
    }).catchError((_) {
      if (mounted) setState(() => _loadingRegions = false);
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _onRegionChanged(Region? r) async {
    setState(() {
      _region = r;
      _district = null;
      _constituency = null;
      _districts = [];
      _constituencies = [];
    });
    if (r == null) return;
    setState(() => _loadingDistricts = true);
    try {
      final d = await _locationRepo.fetchDistricts(r.id);
      if (mounted) setState(() { _districts = d; _loadingDistricts = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingDistricts = false);
    }
  }

  Future<void> _onDistrictChanged(District? d) async {
    setState(() {
      _district = d;
      _constituency = null;
      _constituencies = [];
    });
    if (d == null) return;
    setState(() => _loadingConstituencies = true);
    try {
      final c = await _locationRepo.fetchConstituencies(d.id);
      if (mounted) setState(() { _constituencies = c; _loadingConstituencies = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingConstituencies = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      await OperatorRepository().createOperator(
        fullName: _nameCtrl.text.trim(),
        email: _emailCtrl.text.trim().toLowerCase(),
        role: _selectedRole,
        password: _passCtrl.text,
        phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        assignedRegionId: _region?.id,
        assignedDistrictId: _district?.id,
        assignedConstituencyId: _constituency?.id,
      );
      HapticFeedback.mediumImpact();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: AppColors.canopyGreen,
          content: Text(
            'Account created. ${_emailCtrl.text.trim()} can sign in now with the temporary password.',
            style: AppTextStyles.body(color: AppColors.surface),
          ),
          duration: const Duration(seconds: 6),
        ));
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: AppColors.umbrellaRed,
          content: Text(AppErrorMapper.forAdminAction(e), style: AppTextStyles.body(color: AppColors.surface)),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FormScaffold(
      appBar: AppBar(
        backgroundColor: AppColors.deepCanopy,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Back',
          icon: const PhosphorIcon(PhosphorIconsRegular.arrowLeft, color: AppColors.surface, size: 22),
          onPressed: () => context.pop(),
        ),
        title: Text('Create operator', style: AppTextStyles.appBarTitle()),
      ),
      actionBar: FormActionBar(
        primaryLabel: 'Create Operator Account',
        onPrimary: _submit,
        loading: _loading,
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
                        'The account works immediately — share the temporary password with the operator securely and ask them to change it after first sign-in. No operator can self-register.',
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
              const SizedBox(height: 16),

              NdcTextField(
                label: 'Temporary Password',
                hint: 'At least 8 characters',
                controller: _passCtrl,
                icon: PhosphorIconsRegular.password,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Set a temporary password';
                  if (v.length < 8) return 'Use at least 8 characters';
                  return null;
                },
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _generatePassword,
                  icon: const PhosphorIcon(PhosphorIconsRegular.arrowsClockwise,
                      size: 14, color: AppColors.canopyGreen),
                  label: Text('Generate',
                      style: AppTextStyles.label(color: AppColors.canopyGreen)),
                ),
              ),
              const SizedBox(height: 8),

              Text('Role', style: AppTextStyles.h3()),
              const SizedBox(height: 8),
              Text('Assign the correct role — this determines what the operator can see and do.',
                  style: AppTextStyles.small()),
              const SizedBox(height: 14),

              RadioGroup<String>(
                groupValue: _selectedRole,
                onChanged: (v) => setState(() => _selectedRole = v!),
                child: Column(
                  children: [
                    _RoleOption(
                      value: 'personnel',
                      selected: _selectedRole == 'personnel',
                      title: 'Personnel',
                      subtitle: 'Register and manage own member submissions',
                      icon: PhosphorIconsFill.userCircle,
                      color: AppColors.canopyGreen,
                      onTap: () => setState(() => _selectedRole = 'personnel'),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _RoleOption(
                      value: 'higher_authority',
                      selected: _selectedRole == 'higher_authority',
                      title: 'Higher Authority (Coordinator)',
                      subtitle: 'Review pending registrations, view all members, export data',
                      icon: PhosphorIconsFill.userCircleCheck,
                      color: AppColors.statusPending,
                      onTap: () => setState(() => _selectedRole = 'higher_authority'),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _RoleOption(
                      value: 'admin',
                      selected: _selectedRole == 'admin',
                      title: 'Administrator',
                      subtitle: 'Full system access including operator management',
                      icon: PhosphorIconsFill.shieldStar,
                      color: AppColors.umbrellaRed,
                      onTap: () => setState(() => _selectedRole = 'admin'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Jurisdiction section
              Text('Jurisdiction (optional)', style: AppTextStyles.h3()),
              const SizedBox(height: 8),
              Text(
                'Scope this operator to a specific area. Leave blank for national/unrestricted access.',
                style: AppTextStyles.small(),
              ),
              const SizedBox(height: 14),

              _JurisdictionDropdown<Region>(
                label: 'Region',
                icon: PhosphorIconsRegular.mapTrifold,
                hint: _loadingRegions ? 'Loading regions…' : 'Select region (optional)',
                items: _regions,
                selected: _region,
                enabled: !_loadingRegions && _regions.isNotEmpty,
                itemLabel: (r) => r.name,
                onChanged: _onRegionChanged,
              ),
              const SizedBox(height: 12),

              _JurisdictionDropdown<District>(
                label: 'District',
                icon: PhosphorIconsRegular.buildings,
                hint: _region == null
                    ? 'Select region first'
                    : _loadingDistricts
                        ? 'Loading districts…'
                        : 'Select district (optional)',
                items: _districts,
                selected: _district,
                enabled: _region != null && !_loadingDistricts && _districts.isNotEmpty,
                itemLabel: (d) => d.name,
                onChanged: _onDistrictChanged,
              ),
              const SizedBox(height: 12),

              _JurisdictionDropdown<Constituency>(
                label: 'Constituency',
                icon: PhosphorIconsRegular.mapPin,
                hint: _district == null
                    ? 'Select district first'
                    : _loadingConstituencies
                        ? 'Loading constituencies…'
                        : 'Select constituency (optional)',
                items: _constituencies,
                selected: _constituency,
                enabled: _district != null && !_loadingConstituencies && _constituencies.isNotEmpty,
                itemLabel: (c) => c.name,
                onChanged: (c) => setState(() => _constituency = c),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _JurisdictionDropdown<T> extends StatelessWidget {
  final String label;
  final PhosphorIconData icon;
  final String hint;
  final List<T> items;
  final T? selected;
  final bool enabled;
  final String Function(T) itemLabel;
  final void Function(T?) onChanged;

  const _JurisdictionDropdown({
    required this.label,
    required this.icon,
    required this.hint,
    required this.items,
    required this.selected,
    required this.enabled,
    required this.itemLabel,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.label()),
        const SizedBox(height: 6),
        DropdownButtonFormField<T>(
          initialValue: (selected != null && items.contains(selected)) ? selected : null,
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
          isExpanded: true,
        ),
      ],
    );
  }
}

class _RoleOption extends StatelessWidget {
  final String value;
  final bool selected;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _RoleOption({
    required this.value,
    required this.selected,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
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
              activeColor: color,
              // groupValue and onChanged provided by RadioGroup ancestor
            ),
          ],
        ),
      ),
    );
  }
}
