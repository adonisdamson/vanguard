import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_shadows.dart';
import '../theme/app_text_styles.dart';

class ContextMenuAction {
  final IconData icon;
  final String label;
  final bool isDestructive;
  final VoidCallback onTap;

  const ContextMenuAction({
    required this.icon,
    required this.label,
    this.isDestructive = false,
    required this.onTap,
  });
}

Future<void> showContextMenuSheet(
  BuildContext context, {
  required String title,
  required List<ContextMenuAction> actions,
}) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => _ContextMenuSheet(title: title, actions: actions),
  );
}

class _ContextMenuSheet extends StatelessWidget {
  final String title;
  final List<ContextMenuAction> actions;

  const _ContextMenuSheet({required this.title, required this.actions});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.borderLg,
        boxShadow: AppShadows.e2,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.hairline,
                borderRadius: AppRadii.borderPill,
              ),
            ),
          ),
          // Title
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
            child: Text(title, style: AppTextStyles.title()),
          ),
          const Divider(height: 1),
          // Actions
          ...actions.map((action) => _ActionTile(action: action, context: context)),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final ContextMenuAction action;
  final BuildContext context;

  const _ActionTile({required this.action, required this.context});

  @override
  Widget build(BuildContext context) {
    final color = action.isDestructive ? AppColors.umbrellaRed : AppColors.ink;
    return InkWell(
      onTap: () {
        Navigator.pop(context);
        action.onTap();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            PhosphorIcon(action.icon, size: 20, color: color),
            const SizedBox(width: 14),
            Text(action.label, style: AppTextStyles.body(color: color)),
          ],
        ),
      ),
    );
  }
}
