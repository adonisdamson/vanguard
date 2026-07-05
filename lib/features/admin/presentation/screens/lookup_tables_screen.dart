import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../application/lookup_admin_providers.dart';
import '../../data/lookup_admin_repository.dart';
import '../../../../features/members/data/location_repository.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/theme/app_radii.dart';
import '../../../../shared/theme/app_shadows.dart';
import '../../../../shared/theme/app_spacing.dart';
import '../../../../shared/theme/app_text_styles.dart';
import '../../../../shared/widgets/app_tab_bar.dart';
import '../../../../core/errors/app_error_mapper.dart';
import '../../../../shared/widgets/canopy_arc.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/skeleton_loader.dart';

class LookupTablesScreen extends ConsumerStatefulWidget {
  const LookupTablesScreen({super.key});

  @override
  ConsumerState<LookupTablesScreen> createState() => _LookupTablesScreenState();
}

class _LookupTablesScreenState extends ConsumerState<LookupTablesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

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
        title: Text('Lookup tables', style: AppTextStyles.appBarTitle()),
        actions: [
          IconButton(
            icon: const PhosphorIcon(PhosphorIconsRegular.uploadSimple, color: AppColors.surface, size: 20),
            tooltip: 'CSV bulk import',
            onPressed: () => context.push('/admin/lookups/import-csv'),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CanopyStripe(height: 4),
              AppTabBar(
                controller: _tabs,
                tabs: const ['Regions', 'Districts', 'Const.', 'Polling'],
              ),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [
          _RegionsTab(),
          _DistrictsTab(),
          _ConstituenciesTab(),
          _PollingStationsTab(),
        ],
      ),
    );
  }
}

// ─── Regions Tab ──────────────────────────────────────────────────────────────

class _RegionsTab extends ConsumerWidget {
  const _RegionsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final regionsAsync = ref.watch(allRegionsProvider);
    return _LookupList<Region>(
      title: 'Region',
      emptyState: const EmptyState.noRegions(),
      itemsAsync: regionsAsync,
      nameOf: (r) => r.name,
      onAdd: () => _showDialog(context, 'Add region', null, (name) async {
        await LookupAdminRepository().createRegion(name);
        ref.invalidate(allRegionsProvider);
      }),
      onEdit: (r) => _showDialog(context, 'Edit region', r.name, (name) async {
        await LookupAdminRepository().updateRegion(r.id, name);
        ref.invalidate(allRegionsProvider);
      }),
      onDelete: (r) => _confirmDelete(context, r.name, () async {
        await LookupAdminRepository().deleteRegion(r.id);
        ref.invalidate(allRegionsProvider);
      }),
    );
  }
}

// ─── Districts Tab ────────────────────────────────────────────────────────────

class _DistrictsTab extends ConsumerWidget {
  const _DistrictsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final regionsAsync = ref.watch(allRegionsProvider);
    final selectedRegionId = ref.watch(lookupRegionFilterProvider);
    final districtsAsync = ref.watch(adminDistrictsProvider);

    return Column(
      children: [
        _ParentFilter<Region>(
          label: 'Filter by region',
          itemsAsync: regionsAsync,
          selectedId: selectedRegionId,
          nameOf: (r) => r.name,
          idOf: (r) => r.id,
          onChanged: (id) {
            ref.read(lookupRegionFilterProvider.notifier).state = id;
            ref.invalidate(adminDistrictsProvider);
          },
        ),
        Expanded(
          child: _LookupList<District>(
            title: 'District',
            emptyState: const EmptyState(
              icon: PhosphorIconsRegular.buildings,
              title: 'No districts',
              subtitle: 'Select a region above, then add districts beneath it.',
            ),
            itemsAsync: districtsAsync,
            nameOf: (d) => d.name,
            onAdd: selectedRegionId == null ? null : () => _showDialog(context, 'Add district', null, (name) async {
              await LookupAdminRepository().createDistrict(selectedRegionId, name);
              ref.invalidate(adminDistrictsProvider);
            }),
            onEdit: (d) => _showDialog(context, 'Edit district', d.name, (name) async {
              await LookupAdminRepository().updateDistrict(d.id, name);
              ref.invalidate(adminDistrictsProvider);
            }),
            onDelete: (d) => _confirmDelete(context, d.name, () async {
              await LookupAdminRepository().deleteDistrict(d.id);
              ref.invalidate(adminDistrictsProvider);
            }),
          ),
        ),
      ],
    );
  }
}

// ─── Constituencies Tab ───────────────────────────────────────────────────────

class _ConstituenciesTab extends ConsumerWidget {
  const _ConstituenciesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final districtsAsync = ref.watch(adminDistrictsProvider);
    final selectedDistrictId = ref.watch(lookupDistrictFilterProvider);
    final constituenciesAsync = ref.watch(adminConstituenciesProvider);

    return Column(
      children: [
        _ParentFilter<District>(
          label: 'Filter by district',
          itemsAsync: districtsAsync,
          selectedId: selectedDistrictId,
          nameOf: (d) => d.name,
          idOf: (d) => d.id,
          onChanged: (id) {
            ref.read(lookupDistrictFilterProvider.notifier).state = id;
            ref.invalidate(adminConstituenciesProvider);
          },
        ),
        Expanded(
          child: _LookupList<Constituency>(
            title: 'Constituency',
            emptyState: const EmptyState(
              icon: PhosphorIconsRegular.mapPin,
              title: 'No constituencies',
              subtitle: 'Select a district above, then add constituencies beneath it.',
            ),
            itemsAsync: constituenciesAsync,
            nameOf: (c) => c.name,
            onAdd: selectedDistrictId == null ? null : () => _showDialog(context, 'Add constituency', null, (name) async {
              await LookupAdminRepository().createConstituency(selectedDistrictId, name);
              ref.invalidate(adminConstituenciesProvider);
            }),
            onEdit: (c) => _showDialog(context, 'Edit constituency', c.name, (name) async {
              await LookupAdminRepository().updateConstituency(c.id, name);
              ref.invalidate(adminConstituenciesProvider);
            }),
            onDelete: (c) => _confirmDelete(context, c.name, () async {
              await LookupAdminRepository().deleteConstituency(c.id);
              ref.invalidate(adminConstituenciesProvider);
            }),
          ),
        ),
      ],
    );
  }
}

// ─── Polling Stations Tab ─────────────────────────────────────────────────────

class _PollingStationsTab extends ConsumerWidget {
  const _PollingStationsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final constituenciesAsync = ref.watch(adminConstituenciesProvider);
    final selectedConstituencyId = ref.watch(lookupConstituencyFilterProvider);
    final stationsAsync = ref.watch(adminPollingStationsProvider);

    return Column(
      children: [
        _ParentFilter<Constituency>(
          label: 'Filter by constituency',
          itemsAsync: constituenciesAsync,
          selectedId: selectedConstituencyId,
          nameOf: (c) => c.name,
          idOf: (c) => c.id,
          onChanged: (id) {
            ref.read(lookupConstituencyFilterProvider.notifier).state = id;
            ref.invalidate(adminPollingStationsProvider);
          },
        ),
        Expanded(
          child: _LookupList<PollingStation>(
            title: 'Polling station',
            emptyState: const EmptyState.chooseConstituency(),
            itemsAsync: stationsAsync,
            nameOf: (p) => p.name,
            onAdd: selectedConstituencyId == null ? null : () => _showDialog(context, 'Add polling station', null, (name) async {
              await LookupAdminRepository().createPollingStation(selectedConstituencyId, name);
              ref.invalidate(adminPollingStationsProvider);
            }),
            onEdit: (p) => _showDialog(context, 'Edit polling station', p.name, (name) async {
              await LookupAdminRepository().updatePollingStation(p.id, name);
              ref.invalidate(adminPollingStationsProvider);
            }),
            onDelete: (p) => _confirmDelete(context, p.name, () async {
              await LookupAdminRepository().deletePollingStation(p.id);
              ref.invalidate(adminPollingStationsProvider);
            }),
          ),
        ),
      ],
    );
  }
}

// ─── Shared widgets ───────────────────────────────────────────────────────────

class _ParentFilter<T> extends StatelessWidget {
  final String label;
  final AsyncValue<List<T>> itemsAsync;
  final int? selectedId;
  final String Function(T) nameOf;
  final int Function(T) idOf;
  final void Function(int?) onChanged;

  const _ParentFilter({
    required this.label,
    required this.itemsAsync,
    required this.selectedId,
    required this.nameOf,
    required this.idOf,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH, vertical: AppSpacing.sm),
      child: itemsAsync.when(
        data: (items) => DropdownButtonFormField<int>(
          initialValue: selectedId,
          hint: Text(label, style: AppTextStyles.body(color: AppColors.mist)),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: AppColors.fillMuted,
            border: OutlineInputBorder(
              borderRadius: AppRadii.borderSm,
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          items: [
            const DropdownMenuItem<int>(value: null, child: Text('All')),
            ...items.map((item) => DropdownMenuItem<int>(
                  value: idOf(item),
                  child: Text(nameOf(item)),
                )),
          ],
          onChanged: onChanged,
        ),
        loading: () => const LinearProgressIndicator(color: AppColors.canopyGreen),
        error: (_, __) => Text('Failed to load', style: AppTextStyles.small()),
      ),
    );
  }
}

class _LookupList<T> extends StatelessWidget {
  final String title;
  final EmptyState emptyState;
  final AsyncValue<List<T>> itemsAsync;
  final String Function(T) nameOf;
  final VoidCallback? onAdd;
  final void Function(T) onEdit;
  final void Function(T) onDelete;

  const _LookupList({
    required this.title,
    required this.emptyState,
    required this.itemsAsync,
    required this.nameOf,
    this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      floatingActionButton: onAdd != null
          ? FloatingActionButton(
              mini: true,
              backgroundColor: AppColors.canopyGreen,
              onPressed: onAdd,
              child: const PhosphorIcon(PhosphorIconsRegular.plus, color: AppColors.surface, size: 20),
            )
          : null,
      body: itemsAsync.when(
        data: (items) => items.isEmpty
            ? emptyState
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenH, AppSpacing.base,
                  AppSpacing.screenH, 100,
                ),
                itemCount: items.length,
                itemBuilder: (_, i) => _LookupTile(
                  name: nameOf(items[i]),
                  onEdit: () => onEdit(items[i]),
                  onDelete: () => onDelete(items[i]),
                ),
              ),
        loading: () => ListView.builder(
          padding: const EdgeInsets.all(AppSpacing.base),
          itemCount: 5,
          itemBuilder: (_, __) => const Padding(
            padding: EdgeInsets.only(bottom: AppSpacing.sm),
            child: SkeletonLoader(height: 52, borderRadius: AppRadii.borderSm),
          ),
        ),
        error: (e, _) => Center(
          child: Text('Error: $e', style: AppTextStyles.body(color: AppColors.umbrellaRed)),
        ),
      ),
    );
  }
}

class _LookupTile extends StatelessWidget {
  final String name;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _LookupTile({required this.name, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.borderMd,
        boxShadow: AppShadows.e1,
        border: Border.all(color: AppColors.hairline, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base, vertical: AppSpacing.sm),
        child: Row(
          children: [
            const PhosphorIcon(PhosphorIconsRegular.mapPin, size: 18, color: AppColors.canopyGreen),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: Text(name, style: AppTextStyles.body())),
            IconButton(
              icon: const PhosphorIcon(PhosphorIconsRegular.pencilSimple, size: 16, color: AppColors.mist),
              onPressed: onEdit,
              tooltip: 'Edit',
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              padding: EdgeInsets.zero,
            ),
            IconButton(
              icon: const PhosphorIcon(PhosphorIconsRegular.trash, size: 16, color: AppColors.umbrellaRed),
              onPressed: onDelete,
              tooltip: 'Delete',
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              padding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Dialogs ──────────────────────────────────────────────────────────────────

Future<void> _showDialog(
  BuildContext context,
  String title,
  String? initialValue,
  Future<void> Function(String name) onSave,
) async {
  final ctrl = TextEditingController(text: initialValue ?? '');
  bool saving = false;

  await showDialog<void>(
    context: context,
    builder: (_) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppRadii.borderLg),
        title: Text(title, style: AppTextStyles.h3()),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Name'),
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: saving ? null : () async {
              if (ctrl.text.trim().isEmpty) return;
              setState(() => saving = true);
              try {
                await onSave(ctrl.text.trim());
                if (ctx.mounted) Navigator.pop(ctx);
              } catch (e) {
                setState(() => saving = false);
                if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                  backgroundColor: AppColors.umbrellaRed,
                  content: Text(AppErrorMapper.friendly(e), style: AppTextStyles.body(color: AppColors.surface)),
                ));
              }
            },
            child: saving
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : Text('Save', style: AppTextStyles.bodyMedium(color: AppColors.canopyGreen)),
          ),
        ],
      ),
    ),
  );
  ctrl.dispose();
}

Future<void> _confirmDelete(
  BuildContext context,
  String name,
  Future<void> Function() onConfirm,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: AppRadii.borderLg),
      title: Text('Delete "$name"?', style: AppTextStyles.h3()),
      content: Text(
        'This will fail if members are linked to this location. Unlink them first.',
        style: AppTextStyles.body(),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text('Delete', style: AppTextStyles.bodyMedium(color: AppColors.umbrellaRed)),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;
  try {
    await onConfirm();
  } catch (e) {
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: AppColors.umbrellaRed,
      content: Text(AppErrorMapper.friendly(e), style: AppTextStyles.body(color: AppColors.surface)),
    ));
  }
}
