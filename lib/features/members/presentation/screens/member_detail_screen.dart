import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../application/review_providers.dart';
import '../../application/member_providers.dart';
import '../../data/review_repository.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/theme/app_text_styles.dart';
import '../../../../shared/widgets/ndc_button.dart';
import '../../../../shared/widgets/ndc_flag_stripe.dart';
import '../../../../shared/widgets/skeleton_loader.dart';
import '../widgets/member_status_badge.dart';

class MemberDetailScreen extends ConsumerWidget {
  final String memberId;
  const MemberDetailScreen({super.key, required this.memberId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(memberDetailProvider(memberId));
    final auditAsync = ref.watch(auditHistoryProvider(memberId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.ndcGreen,
        elevation: 0,
        leading: IconButton(
          icon: const PhosphorIcon(PhosphorIconsRegular.arrowLeft, color: AppColors.ndcWhite, size: 22),
          onPressed: () => context.pop(),
        ),
        title: Text('Member Details', style: AppTextStyles.appBarTitle()),
        actions: [
          IconButton(
            icon: const PhosphorIcon(PhosphorIconsRegular.arrowCounterClockwise, color: AppColors.ndcWhite, size: 20),
            onPressed: () {
              ref.invalidate(memberDetailProvider(memberId));
              ref.invalidate(auditHistoryProvider(memberId));
            },
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(4),
          child: NdcFlagStripe(height: 4),
        ),
      ),
      body: detailAsync.when(
        data: (member) => _DetailBody(member: member, auditAsync: auditAsync),
        loading: () => const _LoadingSkeleton(),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const PhosphorIcon(PhosphorIconsFill.warningCircle, size: 40, color: AppColors.ndcRed),
              const SizedBox(height: 12),
              Text('Could not load member', style: AppTextStyles.h3()),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => ref.invalidate(memberDetailProvider(memberId)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailBody extends ConsumerStatefulWidget {
  final MemberDetail member;
  final AsyncValue<List<AuditEntry>> auditAsync;
  const _DetailBody({required this.member, required this.auditAsync});

  @override
  ConsumerState<_DetailBody> createState() => _DetailBodyState();
}

class _DetailBodyState extends ConsumerState<_DetailBody> {
  bool _submitting = false;

  Future<void> _approve() async {
    final confirmed = await _confirmDialog(
      'Approve ${widget.member.fullName}?',
      'This will mark the member as active in the registry.',
      'Approve',
      AppColors.ndcGreen,
    );
    if (!confirmed || !mounted) return;

    setState(() => _submitting = true);
    try {
      await ReviewRepository().approveMember(widget.member.id);
      HapticFeedback.mediumImpact();
      if (mounted) {
        ref.invalidate(memberDetailProvider(widget.member.id));
        ref.invalidate(reviewQueueProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.ndcGreen,
            content: Text('Member approved.', style: AppTextStyles.body(color: AppColors.ndcWhite)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _reject() async {
    final ctrl = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text('Reject Member', style: AppTextStyles.h3()),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Provide a reason for rejection:', style: AppTextStyles.body()),
              const SizedBox(height: 10),
              TextField(
                controller: ctrl,
                maxLines: 3,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'e.g. Incomplete information, duplicate entry...',
                  hintStyle: AppTextStyles.body(color: AppColors.textMuted),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            TextButton(
              onPressed: () {
                if (ctrl.text.trim().isEmpty) return;
                Navigator.pop(context, ctrl.text.trim());
              },
              child: Text('Reject', style: TextStyle(color: AppColors.ndcRed)),
            ),
          ],
        ),
      ),
    );

    if (reason == null || !mounted) return;
    setState(() => _submitting = true);
    try {
      await ReviewRepository().rejectMember(widget.member.id, reason);
      HapticFeedback.mediumImpact();
      if (mounted) {
        ref.invalidate(memberDetailProvider(widget.member.id));
        ref.invalidate(reviewQueueProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.ndcRed,
            content: Text('Member rejected.', style: AppTextStyles.body(color: AppColors.ndcWhite)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<bool> _confirmDialog(String title, String body, String action, Color color) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title, style: AppTextStyles.h3()),
        content: Text(body, style: AppTextStyles.body()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(action, style: TextStyle(color: color)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final member = widget.member;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        // Header card: photo + name + status
        _HeaderCard(member: member),
        const SizedBox(height: 16),

        // Approve/Reject actions (only if pending)
        if (member.status == 'pending') ...[
          Row(
            children: [
              Expanded(
                child: NdcButton(
                  label: 'Approve',
                  loading: _submitting,
                  icon: const PhosphorIcon(PhosphorIconsFill.checkCircle, size: 18, color: AppColors.ndcWhite),
                  onPressed: _approve,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: NdcButton(
                  label: 'Reject',
                  variant: NdcButtonVariant.danger,
                  loading: _submitting,
                  onPressed: _reject,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],

        // Rejection reason (if rejected)
        if (member.status == 'rejected' && member.rejectionReason != null) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.redLight,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.ndcRed.withValues(alpha: 0.2)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const PhosphorIcon(PhosphorIconsFill.xCircle, size: 18, color: AppColors.ndcRed),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Rejection Reason', style: AppTextStyles.bodyMedium(color: AppColors.ndcRed)),
                      const SizedBox(height: 4),
                      Text(member.rejectionReason!, style: AppTextStyles.body()),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Personal info
        _Section(
          title: 'Personal Information',
          icon: PhosphorIconsFill.person,
          rows: [
            _Row('Full Name', member.fullName),
            if (member.memberNumber != null) _Row('Member No.', member.memberNumber!),
            if (member.dateOfBirth != null) _Row('Date of Birth', member.dateOfBirth!),
            if (member.gender != null) _Row('Gender', member.gender!),
            if (member.phone != null) _Row('Phone', member.phone!),
            if (member.email != null) _Row('Email', member.email!),
          ],
        ),
        const SizedBox(height: 12),

        // Location
        _Section(
          title: 'Location',
          icon: PhosphorIconsFill.mapPin,
          rows: [
            if (member.regionName != null) _Row('Region', member.regionName!),
            if (member.districtName != null) _Row('District', member.districtName!),
            if (member.constituencyName != null) _Row('Constituency', member.constituencyName!),
            if (member.pollingStationName != null) _Row('Polling Station', member.pollingStationName!),
            if (member.ward != null) _Row('Ward', member.ward!),
            if (member.branch != null) _Row('Branch', member.branch!),
          ],
        ),
        const SizedBox(height: 12),

        // Membership
        _Section(
          title: 'Membership',
          icon: PhosphorIconsFill.identificationCard,
          rows: [
            if (member.membershipType != null) _Row('Type', member.membershipType!.replaceAll('_', ' ')),
            if (member.preferredRole != null) _Row('Preferred Role', member.preferredRole!),
            if (member.profession != null) _Row('Profession', member.profession!),
            if (member.employmentStatus != null) _Row('Employment', member.employmentStatus!),
            if (member.highestAcademicQualification != null) _Row('Qualification', member.highestAcademicQualification!),
            if (member.skills.isNotEmpty) _Row('Skills', member.skills.join(', ')),
          ],
        ),
        const SizedBox(height: 12),

        // Audit history
        _AuditSection(auditAsync: widget.auditAsync),
      ],
    );
  }
}

class _HeaderCard extends ConsumerWidget {
  final MemberDetail member;
  const _HeaderCard({required this.member});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          _PhotoAvatar(photoPath: member.photoPath, ref: ref),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(member.fullName, style: AppTextStyles.h2()),
                if (member.memberNumber != null)
                  Text(member.memberNumber!, style: AppTextStyles.memberNumber()),
                const SizedBox(height: 6),
                MemberStatusBadge(status: member.status),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoAvatar extends StatelessWidget {
  final String? photoPath;
  final WidgetRef ref;

  const _PhotoAvatar({required this.photoPath, required this.ref});

  @override
  Widget build(BuildContext context) {
    if (photoPath == null || photoPath!.isEmpty) return _placeholder();

    final urlAsync = ref.watch(photoUrlProvider(photoPath!));
    return urlAsync.when(
      data: (url) => url != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(40),
              child: Image.network(url, width: 80, height: 80, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _placeholder()),
            )
          : _placeholder(),
      loading: () => Container(
        width: 80, height: 80,
        decoration: const BoxDecoration(color: AppColors.surfaceVariant, shape: BoxShape.circle),
      ),
      error: (_, __) => _placeholder(),
    );
  }

  Widget _placeholder() => Container(
    width: 80, height: 80,
    decoration: const BoxDecoration(color: AppColors.greenLight, shape: BoxShape.circle),
    child: const PhosphorIcon(PhosphorIconsFill.person, size: 40, color: AppColors.ndcGreen),
  );
}

class _Section extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<_Row> rows;

  const _Section({required this.title, required this.icon, required this.rows});

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PhosphorIcon(icon, size: 16, color: AppColors.ndcGreen),
              const SizedBox(width: 8),
              Text(title, style: AppTextStyles.h3()),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          ...rows,
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  const _Row(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 110, child: Text(label, style: AppTextStyles.small())),
          Expanded(child: Text(value, style: AppTextStyles.bodyMedium())),
        ],
      ),
    );
  }
}

class _AuditSection extends StatelessWidget {
  final AsyncValue<List<AuditEntry>> auditAsync;
  const _AuditSection({required this.auditAsync});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const PhosphorIcon(PhosphorIconsFill.scroll, size: 16, color: AppColors.ndcGreen),
              const SizedBox(width: 8),
              Text('Audit History', style: AppTextStyles.h3()),
            ],
          ),
          const SizedBox(height: 12),
          auditAsync.when(
            data: (entries) => entries.isEmpty
                ? Text('No audit events yet.', style: AppTextStyles.body(color: AppColors.textMuted))
                : Column(
                    children: entries.map((e) => _AuditEntry(entry: e)).toList(),
                  ),
            loading: () => Column(
              children: [1, 2, 3]
                  .map((_) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: SkeletonLoader(height: 44),
                      ))
                  .toList(),
            ),
            error: (_, __) => Text('Could not load audit history.', style: AppTextStyles.small()),
          ),
        ],
      ),
    );
  }
}

class _AuditEntry extends StatelessWidget {
  final AuditEntry entry;
  const _AuditEntry({required this.entry});

  @override
  Widget build(BuildContext context) {
    final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final d = entry.createdAt;
    final dateStr = '${d.day} ${months[d.month - 1]} ${d.year}, ${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')}';

    String detail = '';
    final meta = entry.metadata;
    if (meta['old_status'] != null && meta['new_status'] != null) {
      detail = '${meta['old_status']} → ${meta['new_status']}';
    } else if (meta['status'] != null) {
      detail = 'Status: ${meta['status']}';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 8, height: 8,
            margin: const EdgeInsets.only(top: 5, right: 10),
            decoration: const BoxDecoration(color: AppColors.ndcGreen, shape: BoxShape.circle),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.humanAction, style: AppTextStyles.bodyMedium()),
                if (detail.isNotEmpty) Text(detail, style: AppTextStyles.small()),
                Text(dateStr, style: AppTextStyles.caption()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingSkeleton extends StatelessWidget {
  const _LoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SkeletonLoader(height: 110, borderRadius: BorderRadius.all(Radius.circular(12))),
        const SizedBox(height: 16),
        for (int i = 0; i < 3; i++) ...[
          SkeletonLoader(height: 120, borderRadius: const BorderRadius.all(Radius.circular(12))),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}
