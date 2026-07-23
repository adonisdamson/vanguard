import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../../core/errors/app_error_mapper.dart';
import '../../data/operator_repository.dart';
import 'operator_detail_screen.dart';
import '../../../auth/application/user_role_provider.dart';
import '../../../members/data/location_repository.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/theme/app_radii.dart';
import '../../../../shared/theme/app_shadows.dart';
import '../../../../shared/theme/app_spacing.dart';
import '../../../../shared/theme/app_text_styles.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/load_more_button.dart';
import '../../../../shared/widgets/skeleton_loader.dart';
import '../../../../shared/widgets/status_pill.dart';
import '../../../members/presentation/widgets/member_avatar.dart';

class OperatorListScreen extends ConsumerStatefulWidget {
  const OperatorListScreen({super.key});

  @override
  ConsumerState<OperatorListScreen> createState() => _OperatorListScreenState();
}

class _OperatorListScreenState extends ConsumerState<OperatorListScreen> {
  static const _pageSize = 20;
  final List<OperatorDetail> _items = [];
  List<PendingOperator> _pending = [];
  int _page = 0;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  String? _error;

  /// Only System Admins may manage operators (create, approve, change role,
  /// suspend). Coordinators / Administrators get a read-only roster.
  bool get _isAdmin =>
      ref.read(appUserProvider).valueOrNull?.role == AppUserRole.admin;

  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _loadAll(0);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String _) {
    setState(() {}); // toggle the clear button
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _loadAll(0));
  }

  Future<void> _loadAll(int page) async {
    if (!mounted) return;
    setState(() {
      if (page == 0) { _loading = true; _error = null; }
      else { _loadingMore = true; }
    });
    try {
      final search = _searchCtrl.text.trim();
      final results = await Future.wait([
        // Pending approvals are an admin-only action — coordinators never see
        // the approve/decline queue. Also hidden while searching.
        (_isAdmin && search.isEmpty)
            ? OperatorRepository().listPendingOperators()
            : Future.value(<PendingOperator>[]),
        OperatorRepository().listOperators(page: page, search: search),
      ]);
      if (!mounted) return;
      setState(() {
        _pending = results[0] as List<PendingOperator>;
        final items = results[1] as List<OperatorDetail>;
        if (page == 0) _items.clear();
        _items.addAll(items);
        _page = page;
        _hasMore = items.length == _pageSize;
        _loading = false;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = AppErrorMapper.forDataLoad(e); _loading = false; _loadingMore = false; });
    }
  }

  Future<void> _loadPage(int page) => _loadAll(page);

  @override
  Widget build(BuildContext context) {
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
        title: Text('Operator accounts', style: AppTextStyles.appBarTitle()),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const PhosphorIcon(PhosphorIconsRegular.arrowCounterClockwise, color: AppColors.surface, size: 20),
            onPressed: () => _loadPage(0),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(58),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: TextField(
              controller: _searchCtrl,
              onChanged: _onSearchChanged,
              textInputAction: TextInputAction.search,
              style: AppTextStyles.body(),
              decoration: InputDecoration(
                hintText: 'Search by phone, name or email',
                prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.inkMuted),
                suffixIcon: _searchCtrl.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear',
                        icon: const PhosphorIcon(PhosphorIconsRegular.x, size: 16, color: AppColors.inkMuted),
                        onPressed: () {
                          _searchCtrl.clear();
                          _loadAll(0);
                          setState(() {});
                        },
                      ),
                isDense: true,
                filled: true,
                fillColor: AppColors.surface,
                contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                border: OutlineInputBorder(borderRadius: AppRadii.borderSm, borderSide: BorderSide.none),
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: _isAdmin
          ? FloatingActionButton.extended(
              backgroundColor: AppColors.canopyGreen,
              icon: const PhosphorIcon(PhosphorIconsRegular.userPlus, color: AppColors.surface, size: 20),
              label: Text('New operator', style: AppTextStyles.label(color: AppColors.surface)),
              onPressed: () async {
                await context.push('/admin/operators/create');
                _loadPage(0);
              },
            )
          : null,
      body: RefreshIndicator(
        color: AppColors.canopyGreen,
        onRefresh: () => _loadPage(0),
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return ListView.builder(
        padding: const EdgeInsets.all(AppSpacing.base),
        itemCount: 6,
        itemBuilder: (_, _) => const Padding(
          padding: EdgeInsets.only(bottom: AppSpacing.sm),
          child: MemberTileSkeleton(),
        ),
      );
    }
    if (_error != null && _items.isEmpty) {
      return EmptyState.offline(onRetry: () => _loadPage(0));
    }
    if (_items.isEmpty && _pending.isEmpty) {
      return const EmptyState.noPendingOperators();
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenH, AppSpacing.base,
        AppSpacing.screenH, 100,
      ),
      itemCount: _pendingCount + _items.length + (_hasMore ? 1 : 0),
      itemBuilder: (_, i) {
        // ── Pending section ──
        if (i == 0 && _pending.isNotEmpty) {
          return _PendingSection(
            pending: _pending,
            onChanged: () => _loadAll(0),
          );
        }
        // ── Active operators header ──
        final offset = _pending.isNotEmpty ? 1 : 0;
        if (i == offset && _items.isNotEmpty) {
          // section header for active operators (only show if pending section visible)
          if (_pending.isNotEmpty) {
            return Padding(
              padding: const EdgeInsets.only(top: AppSpacing.base, bottom: AppSpacing.sm),
              child: Text('Active operators', style: AppTextStyles.label()),
            );
          }
        }
        final itemIndex = i - offset - (_pending.isNotEmpty ? 1 : 0);
        if (itemIndex < 0) return const SizedBox.shrink();
        if (itemIndex == _items.length) {
          return LoadMoreButton(loading: _loadingMore, onPressed: () => _loadPage(_page + 1));
        }
        if (itemIndex >= _items.length) return const SizedBox.shrink();
        return _OperatorTile(
          operator: _items[itemIndex],
          isAdmin: _isAdmin,
          onChanged: () => _loadAll(0),
        );
      },
    );
  }

  int get _pendingCount => _pending.isNotEmpty ? 2 : 0; // section widget + header
}

// ── Pending requests section ──────────────────────────────────────────────────

class _PendingSection extends StatelessWidget {
  final List<PendingOperator> pending;
  final VoidCallback onChanged;
  const _PendingSection({required this.pending, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text('Pending requests', style: AppTextStyles.h2())),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.fillMuted,
                borderRadius: AppRadii.borderPill,
              ),
              child: Text(
                '${pending.length}',
                style: AppTextStyles.badge(color: AppColors.inkMuted),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        ...pending.map((p) => _PendingTile(operator: p, onChanged: onChanged)),
        const SizedBox(height: AppSpacing.base),
      ],
    );
  }
}

class _PendingTile extends StatelessWidget {
  final PendingOperator operator;
  final VoidCallback onChanged;
  const _PendingTile({required this.operator, required this.onChanged});

  String _roleLabel(String? r) => switch (r) {
    'admin'            => 'System Admin',
    'manager'          => 'Administrator',
    'higher_authority' => 'Coordinator',
    'personnel'        => 'Personnel',
    _                  => 'Not specified',
  };

  Future<void> _approve(BuildContext context) async {
    final locationRepo = LocationRepository();
    // Pre-load regions so dialog opens without lag
    final regions = await locationRepo.fetchRegions().catchError((_) => <Region>[]);
    if (!context.mounted) return;

    String selectedRole = operator.requestedRole ?? 'personnel';
    Region? selRegion;
    District? selDistrict;
    Constituency? selConstituency;
    List<District> districts = [];
    List<Constituency> constituencies = [];
    bool loadingDistricts = false;
    bool loadingConstituencies = false;

    final result = await showDialog<({String role, int? regionId, int? districtId, int? constituencyId})>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: AppRadii.borderLg),
          title: Text('Approve ${operator.fullName}', style: AppTextStyles.h3()),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Role', style: AppTextStyles.label()),
                RadioGroup<String>(
                  groupValue: selectedRole,
                  onChanged: (v) => setS(() => selectedRole = v!),
                  child: Column(
                    children: ['personnel', 'higher_authority', 'manager', 'admin'].map((r) => RadioListTile<String>(
                      dense: true,
                      value: r,
                      title: Text(_roleLabel(r), style: AppTextStyles.body()),
                      activeColor: AppColors.canopyGreen,
                    )).toList(),
                  ),
                ),
                const SizedBox(height: 8),
                Text('Jurisdiction (optional)', style: AppTextStyles.label()),
                const SizedBox(height: 6),
                // Region
                DropdownButton<Region>(
                  isExpanded: true,
                  hint: const Text('Region — optional'),
                  value: selRegion,
                  items: regions.map((r) => DropdownMenuItem(value: r, child: Text(r.name))).toList(),
                  onChanged: (r) async {
                    setS(() { selRegion = r; selDistrict = null; selConstituency = null; districts = []; constituencies = []; loadingDistricts = true; });
                    if (r != null) {
                      final d = await locationRepo.fetchDistricts(r.id).catchError((_) => <District>[]);
                      if (ctx.mounted) setS(() { districts = d; loadingDistricts = false; });
                    }
                  },
                ),
                if (selRegion != null) ...[
                  const SizedBox(height: 4),
                  loadingDistricts
                      ? const LinearProgressIndicator(color: AppColors.canopyGreen)
                      : DropdownButton<District>(
                          isExpanded: true,
                          hint: const Text('District — optional'),
                          value: selDistrict,
                          items: districts.map((d) => DropdownMenuItem(value: d, child: Text(d.name))).toList(),
                          onChanged: (d) async {
                            setS(() { selDistrict = d; selConstituency = null; constituencies = []; loadingConstituencies = true; });
                            if (d != null) {
                              final c = await locationRepo.fetchConstituencies(d.id).catchError((_) => <Constituency>[]);
                              if (ctx.mounted) setS(() { constituencies = c; loadingConstituencies = false; });
                            }
                          },
                        ),
                ],
                if (selDistrict != null) ...[
                  const SizedBox(height: 4),
                  loadingConstituencies
                      ? const LinearProgressIndicator(color: AppColors.canopyGreen)
                      : DropdownButton<Constituency>(
                          isExpanded: true,
                          hint: const Text('Constituency — optional'),
                          value: selConstituency,
                          items: constituencies.map((c) => DropdownMenuItem(value: c, child: Text(c.name))).toList(),
                          onChanged: (c) => setS(() => selConstituency = c),
                        ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            TextButton(
              onPressed: () => Navigator.pop(ctx, (
                role: selectedRole,
                regionId: selRegion?.id,
                districtId: selDistrict?.id,
                constituencyId: selConstituency?.id,
              )),
              child: Text('Approve', style: TextStyle(color: AppColors.canopyGreen)),
            ),
          ],
        ),
      ),
    );
    if (result == null || !context.mounted) return;
    try {
      await OperatorRepository().approveOperator(
        operator.id,
        result.role,
        assignedRegionId: result.regionId,
        assignedDistrictId: result.districtId,
        assignedConstituencyId: result.constituencyId,
      );
      HapticFeedback.mediumImpact();
      onChanged();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: AppColors.canopyGreen,
          content: Text('${operator.fullName} approved as ${_roleLabel(result.role)}.',
              style: AppTextStyles.body(color: AppColors.surface)),
        ));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
  backgroundColor: AppColors.umbrellaRed,
  content: Text(AppErrorMapper.forAdminAction(e), style: AppTextStyles.body(color: AppColors.surface)),
));
      }
    }
  }

  Future<void> _decline(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppRadii.borderLg),
        title: Text('Decline ${operator.fullName}?', style: AppTextStyles.h3()),
        content: Text(
          'This will permanently delete their account. They can re-apply with the same email.',
          style: AppTextStyles.body(),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Decline', style: TextStyle(color: AppColors.umbrellaRed)),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await OperatorRepository().declineOperator(operator.id);
      HapticFeedback.mediumImpact();
      onChanged();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${operator.fullName} declined.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
  backgroundColor: AppColors.umbrellaRed,
  content: Text(AppErrorMapper.forAdminAction(e), style: AppTextStyles.body(color: AppColors.surface)),
));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.borderMd,
        boxShadow: AppShadows.e1,
        border: Border.all(color: AppColors.brandTint, width: 1.5),
      ),
      child: Row(
        children: [
          // Verification selfie — the whole point of the access-request flow
          // is the admin confirming a real face before approving.
          MemberAvatar(photoPath: operator.avatarPath, size: 48, viewerLabel: operator.fullName),
          const SizedBox(width: AppSpacing.base),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(operator.fullName, style: AppTextStyles.title(),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(operator.email, style: AppTextStyles.small(),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                if (operator.requestedRole != null)
                  Text('Wants: ${_roleLabel(operator.requestedRole)}',
                      style: AppTextStyles.caption()),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          // Approve / Decline buttons
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ActionChip(
                label: 'Approve',
                color: AppColors.canopyGreen,
                bg: AppColors.greenTint,
                onTap: () => _approve(context),
              ),
              const SizedBox(width: 6),
              _ActionChip(
                label: 'Decline',
                color: AppColors.umbrellaRed,
                bg: AppColors.redTint,
                onTap: () => _decline(context),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final String label;
  final Color color;
  final Color bg;
  final VoidCallback onTap;
  const _ActionChip({required this.label, required this.color, required this.bg, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), // intentional: pill badge sizing
        decoration: BoxDecoration(color: bg, borderRadius: AppRadii.borderPill),
        child: Text(label, style: AppTextStyles.badge(color: color)),
      ),
    );
  }
}

// ── Active operator tile ──────────────────────────────────────────────────────

class _OperatorTile extends StatelessWidget {
  final OperatorDetail operator;
  final bool isAdmin;
  final VoidCallback onChanged;
  const _OperatorTile({
    required this.operator,
    required this.isAdmin,
    required this.onChanged,
  });

  Future<void> _openDetail(BuildContext context) async {
    HapticFeedback.selectionClick();
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            OperatorDetailScreen(operator: operator, isAdmin: isAdmin),
      ),
    );
    if (changed == true) onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final iconColor = operator.isActive ? AppColors.canopyGreen : AppColors.umbrellaRed;
    final iconBg    = operator.isActive ? AppColors.greenTint   : AppColors.redTint;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.borderMd,
        boxShadow: AppShadows.e1,
        border: Border.all(color: AppColors.hairline, width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: AppRadii.borderMd,
        child: InkWell(
          borderRadius: AppRadii.borderMd,
          onTap: () => _openDetail(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base, vertical: AppSpacing.md),
            child: Row(
              children: [
                // Avatar chip
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(color: iconBg, borderRadius: AppRadii.borderSm),
                  child: PhosphorIcon(_roleIcon(operator.role), size: 22, color: iconColor),
                ),
                const SizedBox(width: AppSpacing.base),

                // Name + login ID + position/branch
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              operator.fullName,
                              style: AppTextStyles.title(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          _RolePill(role: operator.role),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        // Phone is the login ID; the email is a synthetic internal one.
                        operator.phone ?? operator.email,
                        style: AppTextStyles.body(color: AppColors.mist),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if ([operator.partyPosition, operator.branch]
                          .any((s) => s != null && s.isNotEmpty))
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            [operator.partyPosition, operator.branch]
                                .where((s) => s != null && s.isNotEmpty)
                                .join(' · '),
                            style: AppTextStyles.small(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      if (!operator.isActive)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: StatusPill(MemberStatus.suspended),
                        ),
                    ],
                  ),
                ),

                const SizedBox(width: AppSpacing.sm),
                const PhosphorIcon(
                  PhosphorIconsRegular.caretRight,
                  size: 18,
                  color: AppColors.mist,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _roleIcon(AppUserRole role) => switch (role) {
    AppUserRole.admin          => PhosphorIconsFill.shieldStar,
    AppUserRole.manager        => PhosphorIconsFill.shieldCheck,
    AppUserRole.higherAuthority => PhosphorIconsFill.userCircleCheck,
    AppUserRole.personnel      => PhosphorIconsFill.userCircle,
  };
}

class _RolePill extends StatelessWidget {
  final AppUserRole role;
  const _RolePill({required this.role});

  @override
  Widget build(BuildContext context) {
    final (label, color, bg) = switch (role) {
      AppUserRole.admin          => ('Admin',     AppColors.umbrellaRed,  AppColors.redTint),
      AppUserRole.manager        => ('Manager',     AppColors.brand900, AppColors.brandTint),
      AppUserRole.higherAuthority => ('Coordinator', AppColors.brand,      AppColors.brandTint),
      AppUserRole.personnel      => ('Personnel', AppColors.canopyGreen,  AppColors.greenTint),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: AppRadii.borderPill),
      child: Text(label, style: AppTextStyles.badge(color: color)),
    );
  }
}
