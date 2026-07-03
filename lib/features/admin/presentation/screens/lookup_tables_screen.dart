import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../application/lookup_admin_providers.dart';
import '../../data/lookup_admin_repository.dart';
import '../../../../features/members/data/location_repository.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/theme/app_text_styles.dart';
import '../../../../shared/widgets/ndc_flag_stripe.dart';
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.ndcBlack,
        elevation: 0,
        leading: IconButton(
          icon: const PhosphorIcon(PhosphorIconsRegular.arrowLeft, color: AppColors.ndcWhite, size: 22),
          onPressed: () => context.pop(),
        ),
        title: Text('Lookup Tables', style: AppTextStyles.appBarTitle()),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Column(
            children: [
              const NdcFlagStripe(height: 4),
              TabBar(
                controller: _tabs,
                indicatorColor: AppColors.ndcGold,
                labelColor: AppColors.ndcWhite,
                unselectedLabelColor: AppColors.ndcWhite.withValues(alpha: 0.5),
                labelStyle: AppTextStyles.small(color: AppColors.ndcWhite),
                tabs: const [
                  Tab(text: 'Regions'),
                  Tab(text: 'Districts'),
                  Tab(text: 'Const.'),
                  Tab(text: 'Polling'),
                ],
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
      itemsAsync: regionsAsync,
      nameOf: (r) => r.name,
      onAdd: () => _showDialog(context, 'Add Region', null, (name) async {
        await LookupAdminRepository().createRegion(name);
        ref.invalidate(allRegionsProvider);
      }),
      onEdit: (r) => _showDialog(context, 'Edit Region', r.name, (name) async {
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
          label: 'Filter by Region',
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
            itemsAsync: districtsAsync,
            nameOf: (d) => d.name,
            onAdd: selectedRegionId == null
                ? null
                : () => _showDialog(context, 'Add District', null, (name) async {
                      await LookupAdminRepository().createDistrict(selectedRegionId, name);
                      ref.invalidate(adminDistrictsProvider);
                    }),
            onEdit: (d) => _showDialog(context, 'Edit District', d.name, (name) async {
              await LookupAdminRepository().updateDistrict(d.id, name);
              ref.invalidate(adminDistrictsProvider);
            }),
            onDelete: (d) => _confirmDelete(context, d.name, () async {
              await LookupAdminRepository().deleteDistrict(d.id);
              ref.invalidate(adminDistrictsProvider);
            }),
            emptyHint: selectedRegionId == null ? 'Select a region above first.' : null,
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
          label: 'Filter by District',
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
            itemsAsync: constituenciesAsync,
            nameOf: (c) => c.name,
            onAdd: selectedDistrictId == null
                ? null
                : () => _showDialog(context, 'Add Constituency', null, (name) async {
                      await LookupAdminRepository().createConstituency(selectedDistrictId, name);
                      ref.invalidate(adminConstituenciesProvider);
                    }),
            onEdit: (c) => _showDialog(context, 'Edit Constituency', c.name, (name) async {
              await LookupAdminRepository().updateConstituency(c.id, name);
              ref.invalidate(adminConstituenciesProvider);
            }),
            onDelete: (c) => _confirmDelete(context, c.name, () async {
              await LookupAdminRepository().deleteConstituency(c.id);
              ref.invalidate(adminConstituenciesProvider);
            }),
            emptyHint: selectedDistrictId == null ? 'Select a district above first.' : null,
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
          label: 'Filter by Constituency',
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
            title: 'Polling Station',
            itemsAsync: stationsAsync,
            nameOf: (p) => p.name,
            onAdd: selectedConstituencyId == null
                ? null
                : () => _showDialog(context, 'Add Polling Station', null, (name) async {
                      await LookupAdminRepository().createPollingStation(selectedConstituencyId, name);
                      ref.invalidate(adminPollingStationsProvider);
                    }),
            onEdit: (p) => _showDialog(context, 'Edit Polling Station', p.name, (name) async {
              await LookupAdminRepository().updatePollingStation(p.id, name);
              ref.invalidate(adminPollingStationsProvider);
            }),
            onDelete: (p) => _confirmDelete(context, p.name, () async {
              await LookupAdminRepository().deletePollingStation(p.id);
              ref.invalidate(adminPollingStationsProvider);
            }),
            emptyHint: selectedConstituencyId == null ? 'Select a constituency above first.' : null,
          ),
        ),
      ],
    );
  }
}

// ─── Shared Widgets ───────────────────────────────────────────────────────────

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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: itemsAsync.when(
        data: (items) => DropdownButtonFormField<int>(
          value: selectedId,
          hint: Text(label, style: AppTextStyles.body(color: AppColors.textMuted)),
          decoration: const InputDecoration(isDense: true),
          items: [
            const DropdownMenuItem<int>(value: null, child: Text('All')),
            ...items.map((item) => DropdownMenuItem<int>(
                  value: idOf(item),
                  child: Text(nameOf(item)),
                )),
          ],
          onChanged: onChanged,
        ),
        loading: () => const LinearProgressIndicator(color: AppColors.ndcGreen),
        error: (_, __) => Text('Failed to load', style: AppTextStyles.small()),
      ),
    );
  }
}

class _LookupList<T> extends StatelessWidget {
  final String title;
  final AsyncValue<List<T>> itemsAsync;
  final String Function(T) nameOf;
  final VoidCallback? onAdd;
  final void Function(T) onEdit;
  final void Function(T) onDelete;
  final String? emptyHint;

  const _LookupList({
    required this.title,
    required this.itemsAsync,
    required this.nameOf,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
    this.emptyHint,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: onAdd != null
          ? FloatingActionButton(
              mini: true,
              backgroundColor: AppColors.ndcGreen,
              onPressed: onAdd,
              child: const PhosphorIcon(PhosphorIconsFill.plus, color: AppColors.ndcWhite, size: 20),
            )
          : null,
      body: itemsAsync.when(
        data: (items) => items.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const PhosphorIcon(PhosphorIconsRegular.mapPin, size: 40, color: AppColors.textMuted),
                    const SizedBox(height: 12),
                    Text('No ${title}s', style: AppTextStyles.h3()),
                    if (emptyHint != null) ...[
                      const SizedBox(height: 8),
                      Text(emptyHint!, style: AppTextStyles.body(color: AppColors.textSecondary), textAlign: TextAlign.center),
                    ],
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                itemCount: items.length,
                itemBuilder: (_, i) => _LookupTile(
                  name: nameOf(items[i]),
                  onEdit: () => onEdit(items[i]),
                  onDelete: () => onDelete(items[i]),
                ),
              ),
        loading: () => ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: 5,
          itemBuilder: (_, __) => const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: SkeletonLoader(height: 52, borderRadius: BorderRadius.all(Radius.circular(8))),
          ),
        ),
        error: (e, _) => Center(child: Text('Error: $e', style: AppTextStyles.body(color: AppColors.ndcRed))),
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
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: ListTile(
        dense: true,
        leading: const PhosphorIcon(PhosphorIconsFill.mapPin, size: 18, color: AppColors.ndcGreen),
        title: Text(name, style: AppTextStyles.body()),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const PhosphorIcon(PhosphorIconsFill.pencilSimple, size: 16, color: AppColors.textSecondary),
              onPressed: onEdit,
              tooltip: 'Edit',
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              padding: EdgeInsets.zero,
            ),
            IconButton(
              icon: const PhosphorIcon(PhosphorIconsFill.trash, size: 16, color: AppColors.ndcRed),
              onPressed: onDelete,
              tooltip: 'Delete',
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
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
            onPressed: saving
                ? null
                : () async {
                    if (ctrl.text.trim().isEmpty) return;
                    setState(() => saving = true);
                    try {
                      await onSave(ctrl.text.trim());
                      if (ctx.mounted) Navigator.pop(ctx);
                    } catch (e) {
                      setState(() => saving = false);
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Error: $e')));
                      }
                    }
                  },
            child: saving
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save'),
          ),
        ],
      ),
    ),
  );
  ctrl.dispose();
}

Future<void> _confirmDelete(BuildContext context, String name, Future<void> Function() onConfirm) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text('Delete "$name"?', style: AppTextStyles.h3()),
      content: Text(
        'This will fail if any members are linked to this location. Unlink them first.',
        style: AppTextStyles.body(),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text('Delete', style: TextStyle(color: AppColors.ndcRed)),
        ),
      ],
    ),
  );

  if (confirmed != true || !context.mounted) return;
  try {
    await onConfirm();
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }
}
