import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../application/member_providers.dart';
import '../../data/member_repository.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/theme/app_text_styles.dart';
import 'member_status_badge.dart';

class MemberListTile extends ConsumerWidget {
  final MemberSummary member;
  final VoidCallback? onTap;

  const MemberListTile({super.key, required this.member, this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            _Avatar(photoPath: member.photoPath, ref: ref),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(member.fullName, style: AppTextStyles.bodyMedium()),
                  const SizedBox(height: 3),
                  if (member.memberNumber != null && member.memberNumber!.isNotEmpty)
                    Text(member.memberNumber!, style: AppTextStyles.memberNumber())
                  else
                    Text(member.phone ?? '—', style: AppTextStyles.small()),
                  const SizedBox(height: 4),
                  Text(
                    _formatDate(member.createdAt),
                    style: AppTextStyles.caption(),
                  ),
                ],
              ),
            ),
            MemberStatusBadge(status: member.status),
          ],
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
              borderRadius: BorderRadius.circular(22),
              child: CachedNetworkImage(
                imageUrl: url,
                width: 44,
                height: 44,
                fit: BoxFit.cover,
                placeholder: (_, __) => _placeholder(),
                errorWidget: (_, __, ___) => _placeholder(),
              ),
            )
          : _placeholder(),
      loading: _placeholder,
      error: (_, __) => _placeholder(),
    );
  }

  Widget _placeholder() {
    return Container(
      width: 44,
      height: 44,
      decoration: const BoxDecoration(
        color: AppColors.greenLight,
        shape: BoxShape.circle,
      ),
      child: const PhosphorIcon(PhosphorIconsFill.person, size: 22, color: AppColors.ndcGreen),
    );
  }
}
