import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../../core/errors/app_error_mapper.dart';
import '../../../../core/net/authed_image.dart';
import '../../../../core/net/photo_service.dart';
import '../../data/operator_repository.dart';
import '../../../auth/application/user_role_provider.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/theme/app_radii.dart';
import '../../../../shared/theme/app_shadows.dart';
import '../../../../shared/theme/app_spacing.dart';
import '../../../../shared/theme/app_text_styles.dart';

/// Full operator profile. Reachable by admins AND coordinators / higher
/// authorities — everyone who can see the operator list can open a record and
/// read who the person is (name, phone/login ID, role, party position, branch).
/// Management actions (change role, reset password, suspend) render only for
/// admins; coordinators get a read-only view.
///
/// Pops with `true` when a mutation succeeded, so the list reloads.
class OperatorDetailScreen extends StatefulWidget {
  final OperatorDetail operator;
  final bool isAdmin;
  const OperatorDetailScreen({
    super.key,
    required this.operator,
    required this.isAdmin,
  });

  @override
  State<OperatorDetailScreen> createState() => _OperatorDetailScreenState();
}

class _OperatorDetailScreenState extends State<OperatorDetailScreen> {
  late OperatorDetail _op = widget.operator;
  bool _changed = false;

  String _initials() {
    final parts = _op.fullName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.characters.take(2).toString().toUpperCase();
    }
    return (parts.first.characters.first + parts.last.characters.first)
        .toUpperCase();
  }

  static String _roleLabel(AppUserRole r) => switch (r) {
    AppUserRole.admin => 'System Administrator',
    AppUserRole.manager => 'Administrator',
    AppUserRole.higherAuthority => 'Coordinator',
    AppUserRole.personnel => 'Personnel',
  };

  static String _roleLabelFromString(String r) => switch (r) {
    'admin' => 'System Administrator',
    'manager' => 'Administrator',
    'higher_authority' => 'Coordinator',
    _ => 'Personnel',
  };

  static String _fmtDate(DateTime d) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_changed);
      },
      child: Scaffold(
        backgroundColor: AppColors.paper,
        appBar: AppBar(
          backgroundColor: AppColors.deepCanopy,
          elevation: 0,
          leading: IconButton(
            tooltip: 'Back',
            icon: const PhosphorIcon(PhosphorIconsRegular.arrowLeft,
                color: AppColors.surface, size: 22),
            onPressed: () => Navigator.of(context).pop(_changed),
          ),
          title: Text('Operator', style: AppTextStyles.appBarTitle()),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenH, AppSpacing.lg, AppSpacing.screenH, AppSpacing.h2),
          children: [
            _header(),
            const SizedBox(height: AppSpacing.xl),
            _infoCard(),
            if (widget.isAdmin) ...[
              const SizedBox(height: AppSpacing.xl),
              _actions(),
            ],
          ],
        ),
      ),
    );
  }

  // ── Header: identity crest ──────────────────────────────────────────────
  Widget _header() {
    final active = _op.isActive;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.borderLg,
        boxShadow: AppShadows.e1,
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        children: [
          _OperatorAvatar(avatarPath: _op.avatarPath, initials: _initials(), size: 76),
          const SizedBox(height: 14),
          Text(_op.fullName,
              style: AppTextStyles.h2(), textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _RoleBadge(role: _op.role),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: active ? AppColors.canopyGreen : AppColors.umbrellaRed,
                  borderRadius: AppRadii.borderPill,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PhosphorIcon(
                      active
                          ? PhosphorIconsFill.checkCircle
                          : PhosphorIconsFill.prohibit,
                      size: 12,
                      color: AppColors.surface,
                    ),
                    const SizedBox(width: 4),
                    Text(active ? 'Active' : 'Suspended',
                        style: AppTextStyles.badge(color: AppColors.surface)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Info rows ───────────────────────────────────────────────────────────
  Widget _infoCard() {
    final rows = <Widget>[
      _InfoRow(
        icon: PhosphorIconsRegular.phone,
        label: 'Phone (login ID)',
        value: _op.phone ?? '—',
      ),
      _InfoRow(
        icon: PhosphorIconsRegular.identificationBadge,
        label: 'Party position',
        value: (_op.partyPosition?.isNotEmpty ?? false)
            ? _op.partyPosition!
            : 'Not specified',
      ),
      _InfoRow(
        icon: PhosphorIconsRegular.mapPin,
        label: 'Branch',
        value: (_op.branch?.isNotEmpty ?? false) ? _op.branch! : 'Not assigned',
      ),
      _InfoRow(
        icon: PhosphorIconsRegular.shieldCheck,
        label: 'Access level',
        value: _roleLabel(_op.role),
      ),
      _InfoRow(
        icon: PhosphorIconsRegular.calendarPlus,
        label: 'Account created',
        value: _fmtDate(_op.createdAt),
      ),
      _InfoRow(
        icon: PhosphorIconsRegular.clockCounterClockwise,
        label: 'Last sign-in',
        value:
            _op.lastLoginAt != null ? _fmtDate(_op.lastLoginAt!) : 'Never',
        last: true,
      ),
    ];
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.borderMd,
        boxShadow: AppShadows.e1,
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(children: rows),
    );
  }

  // ── Admin actions ───────────────────────────────────────────────────────
  Widget _actions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Container(width: 3, height: 14, color: AppColors.canopyGreen,
              margin: const EdgeInsets.only(right: 8)),
          Text('Manage', style: AppTextStyles.h3()),
        ]),
        const SizedBox(height: AppSpacing.md),
        _ActionRow(
          icon: PhosphorIconsRegular.arrowsLeftRight,
          label: 'Change role',
          color: AppColors.canopyGreen,
          onTap: _changeRole,
        ),
        const SizedBox(height: AppSpacing.sm),
        _ActionRow(
          icon: PhosphorIconsRegular.password,
          label: 'Reset password',
          color: AppColors.canopyGreen,
          onTap: _resetPassword,
        ),
        const SizedBox(height: AppSpacing.sm),
        _op.isActive
            ? _ActionRow(
                icon: PhosphorIconsRegular.prohibit,
                label: 'Suspend account',
                color: AppColors.umbrellaRed,
                onTap: () => _toggleActive(suspend: true),
              )
            : _ActionRow(
                icon: PhosphorIconsRegular.checkCircle,
                label: 'Reactivate account',
                color: AppColors.canopyGreen,
                onTap: () => _toggleActive(suspend: false),
              ),
      ],
    );
  }

  void _snackErr(Object e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: AppColors.umbrellaRed,
      content: Text(AppErrorMapper.forAdminAction(e),
          style: AppTextStyles.body(color: AppColors.surface)),
    ));
  }

  Future<void> _toggleActive({required bool suspend}) async {
    try {
      if (suspend) {
        await OperatorRepository().suspendOperator(_op.id);
      } else {
        await OperatorRepository().reactivateOperator(_op.id);
      }
      HapticFeedback.mediumImpact();
      if (!mounted) return;
      setState(() {
        _op = _op.copyWith(isActive: !suspend);
        _changed = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(suspend
            ? '${_op.fullName} suspended.'
            : '${_op.fullName} reactivated.'),
      ));
    } catch (e) {
      _snackErr(e);
    }
  }

  Future<void> _changeRole() async {
    String selected = roleToString(_op.role);
    final newRole = await showDialog<String>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: AppRadii.borderLg),
          title: Text('Change role', style: AppTextStyles.h3()),
          content: RadioGroup<String>(
            groupValue: selected,
            onChanged: (v) => setLocal(() => selected = v!),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: ['personnel', 'higher_authority', 'manager', 'admin']
                  .map((r) => RadioListTile<String>(
                        value: r,
                        title: Text(_roleLabelFromString(r),
                            style: AppTextStyles.body()),
                        activeColor: AppColors.canopyGreen,
                      ))
                  .toList(),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            TextButton(
              onPressed: () => Navigator.pop(ctx, selected),
              child: Text('Apply', style: TextStyle(color: AppColors.canopyGreen)),
            ),
          ],
        ),
      ),
    );
    if (newRole == null || newRole == roleToString(_op.role) || !mounted) return;
    try {
      await OperatorRepository().changeRole(_op.id, newRole);
      HapticFeedback.mediumImpact();
      if (!mounted) return;
      setState(() {
        _op = _op.copyWith(role: _parse(newRole));
        _changed = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${_op.fullName} is now ${_roleLabelFromString(newRole)}.'),
      ));
    } catch (e) {
      _snackErr(e);
    }
  }

  AppUserRole _parse(String r) => switch (r) {
    'admin' => AppUserRole.admin,
    'manager' => AppUserRole.manager,
    'higher_authority' => AppUserRole.higherAuthority,
    _ => AppUserRole.personnel,
  };

  Future<void> _resetPassword() async {
    final seed = DateTime.now().microsecondsSinceEpoch;
    final ctrl = TextEditingController(text: 'NDC-${seed % 900000 + 100000}');
    final password = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppRadii.borderLg),
        title: Text('Reset password', style: AppTextStyles.h3()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Set a new password for ${_op.fullName}. It takes effect '
              'immediately — share it with them securely.',
              style: AppTextStyles.body(),
            ),
            const SizedBox(height: 12),
            TextField(
                controller: ctrl,
                autofocus: true,
                style: AppTextStyles.bodyLarge()),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              if (ctrl.text.length < 8) return;
              Navigator.pop(ctx, ctrl.text);
            },
            child:
                Text('Set password', style: TextStyle(color: AppColors.canopyGreen)),
          ),
        ],
      ),
    );
    if (password == null || !mounted) return;
    try {
      await OperatorRepository().setOperatorPassword(_op.id, password);
      HapticFeedback.mediumImpact();
      if (mounted) {
        await _showPasswordResultDialog(_op.fullName, password);
      }
    } catch (e) {
      _snackErr(e);
    }
  }

  Future<void> _showPasswordResultDialog(String name, String password) async {
    bool revealed = false;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: AppRadii.borderLg),
          title: Text('Password updated', style: AppTextStyles.h3()),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "New password for $name takes effect immediately. Share it "
                "securely — it won't be shown again after you close this.",
                style: AppTextStyles.body(),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.paper,
                  borderRadius: AppRadii.borderSm,
                  border: Border.all(color: AppColors.line),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        revealed ? password : '•' * password.length,
                        style: AppTextStyles.bodyLarge()
                            .copyWith(letterSpacing: revealed ? 0.5 : 2),
                      ),
                    ),
                    IconButton(
                      tooltip: revealed ? 'Hide' : 'Reveal',
                      icon: PhosphorIcon(
                        revealed
                            ? PhosphorIconsRegular.eyeSlash
                            : PhosphorIconsRegular.eye,
                        size: 20,
                        color: AppColors.mist,
                      ),
                      onPressed: () => setLocal(() => revealed = !revealed),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: password));
                HapticFeedback.selectionClick();
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                    content: Text('Password copied'),
                    duration: Duration(seconds: 2),
                  ));
                }
              },
              child: Text('Copy', style: TextStyle(color: AppColors.canopyGreen)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Done', style: TextStyle(color: AppColors.canopyGreen)),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool last;
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.last = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.base, vertical: 14),
      decoration: BoxDecoration(
        border: last
            ? null
            : const Border(bottom: BorderSide(color: AppColors.hairline)),
      ),
      child: Row(
        children: [
          PhosphorIcon(icon, size: 18, color: AppColors.mist),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label, style: AppTextStyles.caption()),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              style: AppTextStyles.bodyMedium(),
              textAlign: TextAlign.right,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// Shows operator avatar photo if available, falls back to initials circle.
class _OperatorAvatar extends StatelessWidget {
  final String? avatarPath;
  final String initials;
  final double size;
  const _OperatorAvatar({this.avatarPath, required this.initials, required this.size});

  @override
  Widget build(BuildContext context) {
    if (avatarPath != null && avatarPath!.isNotEmpty) {
      return ClipOval(
        child: SizedBox(
          width: size,
          height: size,
          child: Image(
            image: AuthedNetworkImage(avatarPath!, PhotoService.authHeaders()),
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _fallback(),
          ),
        ),
      );
    }
    return _fallback();
  }

  Widget _fallback() => Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          color: AppColors.deepCanopy,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Text(initials,
            style: TextStyle(
              color: AppColors.surface,
              fontSize: size * 0.28,
              fontWeight: FontWeight.w700,
            )),
      );
}

class _RoleBadge extends StatelessWidget {
  final AppUserRole role;
  const _RoleBadge({required this.role});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (role) {
      AppUserRole.admin => ('Admin', AppColors.umbrellaRed),
      AppUserRole.manager => ('Administrator', AppColors.deepCanopy),
      AppUserRole.higherAuthority => ('Coordinator', AppColors.canopyGreen),
      AppUserRole.personnel => ('Personnel', AppColors.inkMuted),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color, borderRadius: AppRadii.borderPill),
      child: Text(label, style: AppTextStyles.badge(color: AppColors.surface)),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionRow({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: AppRadii.borderMd,
      child: InkWell(
        borderRadius: AppRadii.borderMd,
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: AppRadii.borderMd,
            border: Border.all(color: AppColors.hairline),
          ),
          child: Row(
            children: [
              PhosphorIcon(icon, size: 20, color: color),
              const SizedBox(width: 12),
              Expanded(
                  child: Text(label,
                      style: AppTextStyles.bodyMedium().copyWith(color: color))),
              const PhosphorIcon(PhosphorIconsRegular.caretRight,
                  size: 16, color: AppColors.mist),
            ],
          ),
        ),
      ),
    );
  }
}
