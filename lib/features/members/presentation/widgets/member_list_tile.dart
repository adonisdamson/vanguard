import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../application/member_providers.dart';
import '../../data/member_repository.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/theme/app_radii.dart';
import '../../../../shared/theme/app_shadows.dart';
import '../../../../shared/theme/app_spacing.dart';
import '../../../../shared/theme/app_text_styles.dart';
import '../../../../shared/widgets/status_pill.dart';

class MemberListTile extends ConsumerWidget {
  final MemberSummary member;
  final VoidCallback? onTap;

  const MemberListTile({super.key, required this.member, this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusLabel = switch (member.status) {
      'active'    => 'approved',
      'rejected'  => 'rejected',
      'suspended' => 'suspended',
      _           => 'pending review',
    };
    return Semantics(
      label: '${member.fullName}, ${member.memberNumber ?? member.phone ?? ''}, $statusLabel',
      button: onTap != null,
      child: GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base, vertical: AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadii.borderMd,
          boxShadow: AppShadows.e1,
          border: Border.all(color: AppColors.hairline),
        ),
        child: Row(
          children: [
            _Avatar(photoPath: member.photoPath, ref: ref),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(member.fullName, style: AppTextStyles.title(), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  if (member.memberNumber != null && member.memberNumber!.isNotEmpty)
                    Text(member.memberNumber!, style: AppTextStyles.memberNumber())
                  else
                    Text(member.phone ?? '—', style: AppTextStyles.small(), maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(_formatDate(member.createdAt), style: AppTextStyles.caption()),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            ExcludeSemantics(child: StatusPill.fromString(member.status)),
          ],
        ),
      ),
    ),
    );
  }

  String _formatDate(DateTime dt) {
    final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }
}

class _Avatar extends StatelessWidget {
  final String? photoPath;
  final WidgetRef ref;

  const _Avatar({required this.photoPath, required this.ref});

  @override
  Widget build(BuildContext context) {
    if (photoPath == null || photoPath!.isEmpty) {
      return _placeholder();
    }

    final urlAsync = ref.watch(photoUrlProvider(photoPath!));
    return urlAsync.when(
      data: (url) => url != null
          ? ClipRRect(
              borderRadius: AppRadii.borderSm,
              child: CachedNetworkImage(
                imageUrl: url,
                width: 44,
                height: 44,
                fit: BoxFit.cover,
                placeholder: (_, _) => _placeholder(),
                errorWidget: (_, _, _) => _placeholder(),
              ),
            )
          : _placeholder(),
      loading: _placeholder,
      error: (_, _) => _placeholder(),
    );
  }

  Widget _placeholder() {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.greenTint,
        borderRadius: AppRadii.borderSm,
      ),
      child: const PhosphorIcon(PhosphorIconsRegular.person, size: 22, color: AppColors.canopyGreen),
    );
  }
}
