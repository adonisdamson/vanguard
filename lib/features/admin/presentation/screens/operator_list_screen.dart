import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../application/operator_providers.dart';
import '../../data/operator_repository.dart';
import '../../../../../features/auth/application/user_role_provider.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/theme/app_text_styles.dart';
import '../../../../shared/widgets/ndc_flag_stripe.dart';
import '../../../../shared/widgets/skeleton_loader.dart';

class OperatorListScreen extends ConsumerWidget {
  const OperatorListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final operatorsAsync = ref.watch(operatorsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.ndcBlack,
        elevation: 0,
        leading: IconButton(
          icon: const PhosphorIcon(PhosphorIconsRegular.arrowLeft, color: AppColors.ndcWhite, size: 22),
          onPressed: () => context.pop(),
        ),
        title: Text('Operator Accounts', style: AppTextStyles.appBarTitle()),
        actions: [
          IconButton(
            icon: const PhosphorIcon(PhosphorIconsRegular.arrowCounterClockwise, color: AppColors.ndcWhite, size: 20),
            onPressed: () => ref.invalidate(operatorsProvider),
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(4),
          child: NdcFlagStripe(height: 4),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.ndcGreen,
        icon: const PhosphorIcon(PhosphorIconsFill.userPlus, color: AppColors.ndcWhite, size: 20),
        label: Text('New Operator', style: AppTextStyles.small(color: AppColors.ndcWhite)),
        onPressed: () async {
          await context.push('/admin/operators/create');
          ref.invalidate(operatorsProvider);
        },
      ),
      body: RefreshIndicator(
        color: AppColors.ndcGreen,
        onRefresh: () async => ref.invalidate(operatorsProvider),
        child: operatorsAsync.when(
          data: (operators) => operators.isEmpty
              ? const _EmptyOperators()
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                  itemCount: operators.length,
                  itemBuilder: (_, i) => _OperatorTile(
                    operator: operators[i],
                    onChanged: () => ref.invalidate(operatorsProvider),
                  ),
                ),
          loading: () => ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: 6,
            itemBuilder: (_, __) => const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: MemberTileSkeleton(),
            ),
          ),
          error: (e, _) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const PhosphorIcon(PhosphorIconsFill.warningCircle, size: 40, color: AppColors.ndcRed),
                const SizedBox(height: 12),
                Text('Failed to load operators', style: AppTextStyles.h3()),
                const SizedBox(height: 8),
                TextButton(onPressed: () => ref.invalidate(operatorsProvider), child: const Text('Retry')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OperatorTile extends StatelessWidget {
  final OperatorDetail operator;
  final VoidCallback onChanged;

  const _OperatorTile({required this.operator, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: operator.isActive ? AppColors.border : AppColors.ndcRed.withValues(alpha: 0.3)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: operator.isActive ? AppColors.greenLight : AppColors.redLight,
            shape: BoxShape.circle,
          ),
          child: PhosphorIcon(
            _roleIcon(operator.role),
            size: 22,
            color: operator.isActive ? AppColors.ndcGreen : AppColors.ndcRed,
          ),
        ),
        title: Row(
          children: [
            Expanded(child: Text(operator.fullName, style: AppTextStyles.bodyMedium())),
            _RoleBadge(role: operator.role),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(operator.email, style: AppTextStyles.small()),
            if (!operator.isActive)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text('SUSPENDED', style: AppTextStyles.badge(color: AppColors.ndcRed)),
              ),
          ],
        ),
        trailing: _OperatorMenu(operator: operator, onChanged: onChanged),
      ),
    );
  }

  IconData _roleIcon(AppUserRole role) {
    switch (role) {
      case AppUserRole.admin:
        return PhosphorIconsFill.shieldStar;
      case AppUserRole.higherAuthority:
        return PhosphorIconsFill.userCircleCheck;
      case AppUserRole.personnel:
        return PhosphorIconsFill.userCircle;
    }
  }
}

class _RoleBadge extends StatelessWidget {
  final AppUserRole role;
  const _RoleBadge({required this.role});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (role) {
      AppUserRole.admin => ('Admin', AppColors.ndcRed),
      AppUserRole.higherAuthority => ('Coord.', AppColors.ndcGold),
      AppUserRole.personnel => ('Personnel', AppColors.ndcGreen),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label, style: AppTextStyles.badge(color: color)),
    );
  }
}

class _OperatorMenu extends StatelessWidget {
  final OperatorDetail operator;
  final VoidCallback onChanged;

  const _OperatorMenu({required this.operator, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_OperatorAction>(
      icon: const PhosphorIcon(PhosphorIconsRegular.dotsThreeVertical, size: 20, color: AppColors.textMuted),
      onSelected: (action) => _handleAction(context, action),
      itemBuilder: (_) => [
        PopupMenuItem(
          value: _OperatorAction.changeRole,
          child: Row(children: [
            const PhosphorIcon(PhosphorIconsFill.arrowsLeftRight, size: 16, color: AppColors.textSecondary),
            const SizedBox(width: 10),
            Text('Change Role', style: AppTextStyles.body()),
          ]),
        ),
        PopupMenuDivider(height: 1),
        if (operator.isActive)
          PopupMenuItem(
            value: _OperatorAction.suspend,
            child: Row(children: [
              const PhosphorIcon(PhosphorIconsFill.prohibit, size: 16, color: AppColors.ndcRed),
              const SizedBox(width: 10),
              Text('Suspend', style: AppTextStyles.body(color: AppColors.ndcRed)),
            ]),
          )
        else
          PopupMenuItem(
            value: _OperatorAction.reactivate,
            child: Row(children: [
              const PhosphorIcon(PhosphorIconsFill.checkCircle, size: 16, color: AppColors.ndcGreen),
              const SizedBox(width: 10),
              Text('Reactivate', style: AppTextStyles.body(color: AppColors.ndcGreen)),
            ]),
          ),
      ],
    );
  }

  Future<void> _handleAction(BuildContext context, _OperatorAction action) async {
    if (action == _OperatorAction.changeRole) {
      await _showChangeRoleDialog(context);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
          action == _OperatorAction.suspend ? 'Suspend ${operator.fullName}?' : 'Reactivate ${operator.fullName}?',
          style: AppTextStyles.h3(),
        ),
        content: Text(
          action == _OperatorAction.suspend
              ? 'This operator will no longer be able to log in.'
              : 'This operator will be able to log in again.',
          style: AppTextStyles.body(),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              action == _OperatorAction.suspend ? 'Suspend' : 'Reactivate',
              style: TextStyle(color: action == _OperatorAction.suspend ? AppColors.ndcRed : AppColors.ndcGreen),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      if (action == _OperatorAction.suspend) {
        await OperatorRepository().suspendOperator(operator.id);
      } else {
        await OperatorRepository().reactivateOperator(operator.id);
      }
      HapticFeedback.mediumImpact();
      onChanged();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: action == _OperatorAction.suspend ? AppColors.ndcRed : AppColors.ndcGreen,
          content: Text(
            action == _OperatorAction.suspend
                ? '${operator.fullName} suspended.'
                : '${operator.fullName} reactivated.',
            style: AppTextStyles.body(color: AppColors.ndcWhite),
          ),
        ));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _showChangeRoleDialog(BuildContext context) async {
    String selected = roleToString(operator.role);
    final newRole = await showDialog<String>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text('Change Role', style: AppTextStyles.h3()),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Current role: ${roleToString(operator.role)}', style: AppTextStyles.body()),
              const SizedBox(height: 16),
              ...['personnel', 'higher_authority', 'admin'].map((r) => RadioListTile<String>(
                    value: r,
                    groupValue: selected,
                    title: Text(_roleLabel(r), style: AppTextStyles.body()),
                    activeColor: AppColors.ndcGreen,
                    onChanged: (v) => setState(() => selected = v!),
                  )),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            TextButton(
              onPressed: () => Navigator.pop(context, selected),
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );

    if (newRole == null || newRole == roleToString(operator.role) || !context.mounted) return;

    try {
      await OperatorRepository().changeRole(operator.id, newRole);
      HapticFeedback.mediumImpact();
      onChanged();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: AppColors.ndcGreen,
          content: Text('Role updated to ${_roleLabel(newRole)}.', style: AppTextStyles.body(color: AppColors.ndcWhite)),
        ));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'admin':
        return 'Administrator';
      case 'higher_authority':
        return 'Higher Authority (Coordinator)';
      default:
        return 'Personnel';
    }
  }
}

enum _OperatorAction { suspend, reactivate, changeRole }

class _EmptyOperators extends StatelessWidget {
  const _EmptyOperators();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const PhosphorIcon(PhosphorIconsFill.usersThree, size: 48, color: AppColors.textMuted),
          const SizedBox(height: 16),
          Text('No operators yet', style: AppTextStyles.h3()),
          const SizedBox(height: 8),
          Text('Create the first operator account using the button below.',
              style: AppTextStyles.body(color: AppColors.textSecondary),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
