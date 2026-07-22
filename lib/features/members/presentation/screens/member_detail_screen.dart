import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../application/review_providers.dart';
import '../../application/member_providers.dart';
import '../../data/review_repository.dart';
import '../../../../core/errors/app_error_mapper.dart';
import '../../../../core/net/photo_service.dart';
import '../widgets/photo_viewer.dart';
import '../../../auth/application/user_role_provider.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/theme/app_radii.dart';
import '../../../../shared/theme/app_shadows.dart';
import '../../../../shared/theme/app_spacing.dart';
import '../../../../shared/theme/app_text_styles.dart';
import '../../../../shared/widgets/lottie_loader.dart';
import '../../../../shared/widgets/ndc_button.dart';
import '../../../../shared/widgets/skeleton_loader.dart';
import '../../../../shared/widgets/status_pill.dart';

class MemberDetailScreen extends ConsumerWidget {
  final String memberId;
  const MemberDetailScreen({super.key, required this.memberId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(memberDetailProvider(memberId));
    final auditAsync = ref.watch(auditHistoryProvider(memberId));

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        backgroundColor: AppColors.deepCanopy,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Back',
          icon: const PhosphorIcon(PhosphorIconsRegular.arrowLeft, color: AppColors.surface, size: 22),
          onPressed: () => context.pop(),
        ),
        title: Text('Member details', style: AppTextStyles.appBarTitle()),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const PhosphorIcon(PhosphorIconsRegular.arrowCounterClockwise, color: AppColors.surface, size: 20),
            onPressed: () {
              ref.invalidate(memberDetailProvider(memberId));
              ref.invalidate(auditHistoryProvider(memberId));
            },
          ),
        ],
      ),
      body: detailAsync.when(
        data: (member) => _DetailBody(member: member, auditAsync: auditAsync),
        loading: () => const _LoadingSkeleton(),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const PhosphorIcon(PhosphorIconsFill.warningCircle, size: 40, color: AppColors.umbrellaRed),
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

  static String _titleCase(String s) => s
      .split('_')
      .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');

  static String _fmtDate(DateTime d) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  Future<void> _approve() async {
    final confirmed = await _confirmDialog(
      'Approve ${widget.member.fullName}?',
      'This will mark the member as active in the registry.',
      'Approve',
      AppColors.canopyGreen,
    );
    if (!confirmed || !mounted) return;

    setState(() => _submitting = true);
    try {
      await ReviewRepository().approveMember(widget.member.id);
      HapticFeedback.mediumImpact();
      if (mounted) {
        ref.invalidate(memberDetailProvider(widget.member.id));
        ref.invalidate(reviewQueueProvider);
        await showDialog<void>(
          context: context,
          barrierColor: Colors.black26,
          barrierDismissible: false,
          builder: (_) => _ApprovalSuccessOverlay(
            message: '${widget.member.fullName} approved.',
            onDone: () => Navigator.of(context).pop(),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: AppColors.umbrellaRed,
          content: Text(AppErrorMapper.friendly(e), style: AppTextStyles.body(color: AppColors.surface)),
        ));
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
        builder: (ctx, setDialogState) {
          bool showError = false;
          return StatefulBuilder(
            builder: (ctx2, setInner) => AlertDialog(
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
                    onChanged: (_) {
                      if (showError) setInner(() => showError = false);
                    },
                    decoration: InputDecoration(
                      hintText: 'e.g. Incomplete information, duplicate entry...',
                      hintStyle: AppTextStyles.body(color: AppColors.textMuted),
                      errorText: showError ? 'A reason is required to reject.' : null,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx2), child: const Text('Cancel')),
                TextButton(
                  onPressed: () {
                    if (ctrl.text.trim().isEmpty) {
                      setInner(() => showError = true);
                      return;
                    }
                    Navigator.pop(ctx2, ctrl.text.trim());
                  },
                  child: Text('Reject', style: AppTextStyles.bodyMedium(color: AppColors.umbrellaRed)),
                ),
              ],
            ),
          );
        },
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
            backgroundColor: AppColors.umbrellaRed,
            content: Text('Member rejected.', style: AppTextStyles.body(color: AppColors.surface)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: AppColors.umbrellaRed,
          content: Text(AppErrorMapper.friendly(e), style: AppTextStyles.body(color: AppColors.surface)),
        ));
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
            child: Text(action, style: AppTextStyles.bodyMedium(color: color)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final member = widget.member;
    final appUser = ref.watch(appUserProvider).valueOrNull;
    final canReview = appUser?.role == AppUserRole.higherAuthority ||
        appUser?.role == AppUserRole.admin;
    final showReviewBar = member.status == 'pending' && canReview;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              // Edge-to-edge brand header: photo + name + status
              _HeaderCard(member: member),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenH, AppSpacing.base, AppSpacing.screenH, AppSpacing.h1),
                child: Column(
                  children: _sections(member),
                ),
              ),
            ],
          ),
        ),
        // Pinned review actions — always reachable, never scrolled away.
        if (showReviewBar)
          Container(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.line)),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: NdcButton(
                        label: 'Reject',
                        variant: NdcButtonVariant.secondary,
                        loading: _submitting,
                        onPressed: _reject,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      flex: 2,
                      child: NdcButton(
                        label: 'Approve member',
                        loading: _submitting,
                        icon: const PhosphorIcon(PhosphorIconsFill.check,
                            size: 18, color: AppColors.surface),
                        onPressed: _approve,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  List<Widget> _sections(MemberDetail member) {
    return [
        // Rejection reason (if rejected)
        if (member.status == 'rejected' && member.rejectionReason != null) ...[
          Container(
            padding: const EdgeInsets.all(AppSpacing.base),
            decoration: BoxDecoration(
              color: AppColors.redTint,
              borderRadius: AppRadii.borderMd,
              border: Border.all(color: AppColors.umbrellaRed.withValues(alpha: 0.2)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const PhosphorIcon(PhosphorIconsRegular.xCircle, size: 18, color: AppColors.umbrellaRed),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Rejection reason', style: AppTextStyles.label(color: AppColors.umbrellaRed)),
                      const SizedBox(height: 4),
                      Text(member.rejectionReason!, style: AppTextStyles.body()),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.base),
        ],

        // Personal info
        _Section(
          title: 'Personal information',
          icon: PhosphorIconsRegular.person,
          rows: [
            _Row('Full name', member.fullName),
            if (member.memberNumber != null) _Row('Member no.', member.memberNumber!),
            if (member.dateOfBirth != null) _Row('Date of birth', member.dateOfBirth!),
            if (member.gender != null) _Row('Gender', member.gender!),
            if (member.phone != null) _Row('Phone', member.phone!),
            if (member.email != null) _Row('Email', member.email!),
            if (member.ghanaCardId != null) _Row('Ghana Card / Voter ID', member.ghanaCardId!),
            _Row('Registered on', _fmtDate(member.createdAt)),
            if (member.registeredByName != null) _Row('Registered by', member.registeredByName!),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),

        // Location
        _Section(
          title: 'Location',
          icon: PhosphorIconsRegular.mapPin,
          rows: [
            if (member.regionName != null) _Row('Region', member.regionName!),
            if (member.districtName != null) _Row('District', member.districtName!),
            if (member.constituencyName != null) _Row('Constituency', member.constituencyName!),
            if (member.electoralArea != null) _Row('Electoral area', 'Area ${member.electoralArea!}'),
            if (member.pollingStationName != null) _Row('Polling station',
              member.pollingStationCode != null
                ? '${member.pollingStationCode} — ${member.pollingStationName!}'
                : member.pollingStationName!),
            if (member.ward != null) _Row('Ward', member.ward!),
            if (member.branch != null) _Row('Branch', member.branch!),
            if (member.residentialAddress != null) _Row('Address', member.residentialAddress!),
            if (member.residenceTown != null) _Row('Town', member.residenceTown!),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),

        // Membership
        _Section(
          title: 'Membership',
          icon: PhosphorIconsRegular.identificationCard,
          rows: [
            if (member.membershipType != null) _Row('Type', _titleCase(member.membershipType!)),
            if (member.preferredRole != null) _Row('Preferred role', _titleCase(member.preferredRole!)),
            if (member.partyPosition != null) _Row('Party position', member.partyPosition!),
            if (member.otherParty != null) _Row('Other party', member.otherParty!),
            if (member.profession != null) _Row('Profession', member.profession!),
            if (member.employmentStatus != null) _Row('Employment', member.employmentStatus!),
            if (member.highestAcademicQualification != null) _Row('Qualification', member.highestAcademicQualification!),
            if (member.skills.isNotEmpty) _Row('Skills', member.skills.join(', ')),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),

        // Audit history
        _AuditSection(auditAsync: widget.auditAsync),
    ];
  }
}

class _HeaderCard extends ConsumerWidget {
  final MemberDetail member;
  const _HeaderCard({required this.member});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      width: double.infinity,
      color: AppColors.deepCanopy,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.base, AppSpacing.lg, AppSpacing.base, AppSpacing.xl,
      ),
      child: Column(
        children: [
          // Photo avatar — centered, circular; tap to view full-screen
          _PhotoAvatar(photoPath: member.photoPath, label: member.fullName),
          const SizedBox(height: AppSpacing.md),
          // Name
          Text(
            member.fullName,
            style: AppTextStyles.h2(color: AppColors.surface),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          // Member number
          if (member.memberNumber != null) ...[
            const SizedBox(height: 4),
            Text(
              member.memberNumber!,
              style: AppTextStyles.memberNumber(color: AppColors.surface.withValues(alpha: 0.65)),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          // Status badge
          StatusPill.fromString(member.status),
          // Polling station quick info
          if (member.pollingStationName != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(AppRadii.pill),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const PhosphorIcon(PhosphorIconsRegular.mapPin, size: 12, color: AppColors.surface),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      member.pollingStationName!,
                      style: AppTextStyles.caption(color: AppColors.surface.withValues(alpha: 0.75)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PhotoAvatar extends ConsumerWidget {
  final String? photoPath;
  final String? label;

  const _PhotoAvatar({required this.photoPath, this.label});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget inner;
    final hasPhoto = photoPath != null && photoPath!.isNotEmpty;
    if (!hasPhoto) {
      inner = _placeholder();
    } else {
      final urlAsync = ref.watch(photoUrlProvider(photoPath!));
      inner = urlAsync.when(
        data: (url) => url != null
            ? CachedNetworkImage(
                imageUrl: url,
                httpHeaders: PhotoService.authHeaders(),
                width: 88,
                height: 88,
                fit: BoxFit.cover,
                placeholder: (_, _) => const SizedBox(width: 88, height: 88),
                errorWidget: (_, _, _) => _placeholder(),
              )
            : _placeholder(),
        loading: () => const SizedBox(width: 88, height: 88),
        error: (_, _) => _placeholder(),
      );
    }

    final avatar = Container(
      width: 88,
      height: 88,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.surface.withValues(alpha: 0.30), width: 2),
      ),
      child: ClipOval(child: inner),
    );

    if (!hasPhoto) return avatar;
    return GestureDetector(
      onTap: () => openPhotoViewer(context, photoPath, label: label),
      child: avatar,
    );
  }

  // Same fallback palette as MemberListTile — one consistent style app-wide.
  Widget _placeholder() => Container(
    width: 88, height: 88,
    color: AppColors.greenTint,
    child: const PhosphorIcon(PhosphorIconsRegular.person, size: 42, color: AppColors.canopyGreen),
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
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.borderMd,
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                  width: 3, height: 16, margin: const EdgeInsets.only(right: 9),
                  decoration: BoxDecoration(
                      color: AppColors.brand,
                      borderRadius: BorderRadius.circular(2))),
              PhosphorIcon(icon, size: 16, color: AppColors.inkMuted),
              const SizedBox(width: 7),
              Text(title, style: AppTextStyles.h3()),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.line),
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
          // Selectable so member number, phone, email etc. can be copied.
          Expanded(child: SelectableText(value, style: AppTextStyles.bodyMedium())),
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
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.borderMd,
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const PhosphorIcon(PhosphorIconsRegular.clockCounterClockwise,
                  size: 16, color: AppColors.canopyGreen),
              const SizedBox(width: 8),
              Text('History', style: AppTextStyles.h3()),
            ],
          ),
          const SizedBox(height: 16),
          auditAsync.when(
            data: (entries) => entries.isEmpty
                ? Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('No events recorded yet.',
                        style: AppTextStyles.body(color: AppColors.textMuted)),
                  )
                : _Timeline(entries: entries),
            loading: () => Column(
              children: List.generate(
                3,
                (_) => const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: SkeletonLoader(height: 48, borderRadius: AppRadii.borderSm),
                ),
              ),
            ),
            error: (_, _) =>
                Text('Could not load history.', style: AppTextStyles.small()),
          ),
        ],
      ),
    );
  }
}

class _Timeline extends StatelessWidget {
  final List<AuditEntry> entries;
  const _Timeline({required this.entries});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(entries.length, (i) {
        return _TimelineItem(
          entry: entries[i],
          isLast: i == entries.length - 1,
        );
      }),
    );
  }
}

class _TimelineItem extends StatelessWidget {
  final AuditEntry entry;
  final bool isLast;
  const _TimelineItem({required this.entry, required this.isLast});

  static (IconData, Color, Color) _iconFor(String action) {
    return switch (action) {
      'member_created'       => (PhosphorIconsFill.userPlus,      AppColors.canopyGreen,  AppColors.greenTint),
      'member_status_changed'=> _statusIcon,
      'member_updated'       => (PhosphorIconsFill.pencilSimple,  AppColors.mist,         AppColors.fillMuted),
      'operator_created'     => (PhosphorIconsFill.userGear,      AppColors.canopyGreen,  AppColors.greenTint),
      'role_changed'         => (PhosphorIconsFill.arrowsLeftRight,AppColors.gold,        AppColors.goldTint),
      'account_status_changed'=> (PhosphorIconsFill.toggleRight,  AppColors.gold,         AppColors.goldTint),
      _                      => (PhosphorIconsRegular.dot,        AppColors.mist,         AppColors.fillMuted),
    };
  }

  // status_changed icon depends on new_status in metadata — resolved at build time
  static const _statusIcon = (PhosphorIconsFill.arrowCircleRight, AppColors.canopyGreen, AppColors.greenTint);

  (IconData, Color, Color) _resolvedIcon() {
    if (entry.action == 'member_status_changed') {
      final ns = entry.metadata['new_status'] as String?;
      if (ns == 'active')   return (PhosphorIconsFill.checkCircle,  AppColors.canopyGreen,  AppColors.greenTint);
      if (ns == 'rejected') return (PhosphorIconsFill.xCircle,      AppColors.umbrellaRed,  AppColors.redTint);
    }
    return _iconFor(entry.action);
  }

  @override
  Widget build(BuildContext context) {
    final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final d = entry.createdAt;
    final dateStr =
        '${d.day} ${months[d.month - 1]} ${d.year}  ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

    final meta = entry.metadata;
    String? detail;
    if (meta['old_status'] != null && meta['new_status'] != null) {
      detail = '${(meta['old_status'] as String).replaceAll('_', ' ')} → ${(meta['new_status'] as String).replaceAll('_', ' ')}';
    } else if (meta['reason'] != null && (meta['reason'] as String).isNotEmpty) {
      detail = meta['reason'] as String;
    }

    final (icon, iconColor, iconBg) = _resolvedIcon();

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Vertical spine + icon
          SizedBox(
            width: 36,
            child: Column(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
                  child: Center(child: PhosphorIcon(icon, size: 15, color: iconColor)),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 3),
                      color: AppColors.hairline,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Content
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : AppSpacing.base),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry.humanAction, style: AppTextStyles.bodyMedium()),
                  if (detail != null) ...[
                    const SizedBox(height: 2),
                    Text(detail, style: AppTextStyles.small(color: AppColors.textSecondary)),
                  ],
                  const SizedBox(height: 3),
                  Text(dateStr, style: AppTextStyles.caption()),
                ],
              ),
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
        const SkeletonLoader(height: 110, borderRadius: AppRadii.borderMd),
        const SizedBox(height: AppSpacing.base),
        for (int i = 0; i < 3; i++) ...[
          SkeletonLoader(height: 120, borderRadius: AppRadii.borderMd),
          const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}

// ── Approval success overlay ──────────────────────────────────────────────────

class _ApprovalSuccessOverlay extends StatelessWidget {
  final String message;
  final VoidCallback onDone;
  const _ApprovalSuccessOverlay(
      {required this.message, required this.onDone});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 40),
          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadii.borderLg,
            boxShadow: AppShadows.e2,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LottieSuccess(size: 72, onComplete: onDone),
              const SizedBox(height: 12),
              Text(message,
                  style: AppTextStyles.body(), textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
