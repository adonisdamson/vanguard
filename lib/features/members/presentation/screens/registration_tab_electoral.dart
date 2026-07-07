import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../application/location_providers.dart';
import '../../data/location_repository.dart';
import '../../application/registration_form_notifier.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/theme/app_radii.dart';
import '../../../../shared/theme/app_spacing.dart';
import '../../../../shared/theme/app_text_styles.dart';
import '../../../../shared/widgets/ndc_text_field.dart';
import '../widgets/registration_form_widgets.dart';

class RegistrationTabElectoral extends ConsumerStatefulWidget {
  final GlobalKey<FormState> formKey;
  const RegistrationTabElectoral({super.key, required this.formKey});

  @override
  ConsumerState<RegistrationTabElectoral> createState() =>
      _RegistrationTabElectoralState();
}

class _RegistrationTabElectoralState
    extends ConsumerState<RegistrationTabElectoral>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  late TextEditingController _ward;
  late TextEditingController _branch;
  late TextEditingController _residentialAddress;
  late TextEditingController _residenceTown;

  Region? _region;
  District? _district;
  Constituency? _constituency;
  PollingStation? _pollingStation;

  @override
  void initState() {
    super.initState();
    final d = ref.read(registrationFormProvider);
    _ward = TextEditingController(text: d.ward ?? '');
    _branch = TextEditingController(text: d.branch ?? '');
    _residentialAddress = TextEditingController(text: d.residentialAddress ?? '');
    _residenceTown = TextEditingController(text: d.residenceTown ?? '');

    if (d.regionId != null) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _restoreLocationObjects());
    }
  }

  void _restoreLocationObjects() {
    if (!mounted) return;
    final d = ref.read(registrationFormProvider);

    ref.read(regionsProvider).whenData((regions) {
      final r = regions.where((x) => x.id == d.regionId).firstOrNull;
      if (r != null && mounted) setState(() => _region = r);
    });
    ref.read(districtsProvider).whenData((districts) {
      final r = districts.where((x) => x.id == d.districtId).firstOrNull;
      if (r != null && mounted) setState(() => _district = r);
    });
    ref.read(constituenciesProvider).whenData((constituencies) {
      final r =
          constituencies.where((x) => x.id == d.constituencyId).firstOrNull;
      if (r != null && mounted) setState(() => _constituency = r);
    });
    ref.read(pollingStationsProvider).whenData((stations) {
      final r = stations.where((x) => x.id == d.pollingStationId).firstOrNull;
      if (r != null && mounted) setState(() => _pollingStation = r);
    });
  }

  @override
  void dispose() {
    _ward.dispose();
    _branch.dispose();
    _residentialAddress.dispose();
    _residenceTown.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final regionsAsync = ref.watch(regionsProvider);
    final districtsAsync = ref.watch(districtsProvider);
    final constituenciesAsync = ref.watch(constituenciesProvider);
    final pollingStationsAsync = ref.watch(pollingStationsProvider);

    return Form(
      key: widget.formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const RegistrationSectionTitle(
            'Electoral Location',
            subtitle: "Select the member's registration location",
          ),
          const SizedBox(height: 24),

          RegistrationAsyncDropdown<Region>(
            label: 'Region *',
            icon: PhosphorIconsRegular.mapTrifold,
            hint: 'Select region',
            asyncData: regionsAsync,
            selected: _region,
            itemLabel: (r) => r.name,
            onChanged: (r) {
              setState(() {
                _region = r;
                _district = null;
                _constituency = null;
                _pollingStation = null;
              });
              ref.read(selectedRegionIdProvider.notifier).state = r?.id;
              ref.read(selectedDistrictIdProvider.notifier).state = null;
              ref.read(selectedConstituencyIdProvider.notifier).state = null;
              ref.read(selectedElectoralAreaProvider.notifier).state = null;
            },
            validator: () => _region == null ? 'Please select a region' : null,
            onRetry: () => ref.invalidate(regionsProvider),
          ),
          const SizedBox(height: AppSpacing.base),

          RegistrationAsyncDropdown<District>(
            label: 'District *',
            icon: PhosphorIconsRegular.buildings,
            hint: _region == null ? 'Select region first' : 'Select district',
            asyncData: districtsAsync,
            selected: _district,
            enabled: _region != null,
            itemLabel: (d) => d.name,
            onChanged: (d) {
              setState(() {
                _district = d;
                _constituency = null;
                _pollingStation = null;
              });
              ref.read(selectedDistrictIdProvider.notifier).state = d?.id;
              ref.read(selectedConstituencyIdProvider.notifier).state = null;
              ref.read(selectedElectoralAreaProvider.notifier).state = null;
            },
            validator: () => _district == null && _region != null
                ? 'Please select a district'
                : null,
            onRetry: () => ref.invalidate(districtsProvider),
          ),
          const SizedBox(height: AppSpacing.base),

          RegistrationAsyncDropdown<Constituency>(
            label: 'Constituency *',
            icon: PhosphorIconsRegular.mapPin,
            hint: _district == null
                ? 'Select district first'
                : 'Select constituency',
            asyncData: constituenciesAsync,
            selected: _constituency,
            enabled: _district != null,
            itemLabel: (c) => c.name,
            onChanged: (c) {
              setState(() {
                _constituency = c;
                _pollingStation = null;
              });
              ref.read(selectedConstituencyIdProvider.notifier).state = c?.id;
              ref.read(selectedElectoralAreaProvider.notifier).state = null;
            },
            validator: () => _constituency == null && _district != null
                ? 'Please select a constituency'
                : null,
            onRetry: () => ref.invalidate(constituenciesProvider),
          ),
          const SizedBox(height: AppSpacing.base),

          _PollingStationField(
            asyncData: pollingStationsAsync,
            selected: _pollingStation,
            enabled: _constituency != null,
            onChanged: (p) => setState(() => _pollingStation = p),
            validator: () => _pollingStation == null && _constituency != null
                ? 'Please select a polling station'
                : null,
            onRetry: () => ref.invalidate(pollingStationsProvider),
          ),
          const SizedBox(height: AppSpacing.base),

          NdcTextField(
            label: 'Ward',
            hint: 'Optional',
            icon: PhosphorIconsRegular.mapPin,
            controller: _ward,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: AppSpacing.base),

          NdcTextField(
            label: 'Branch',
            hint: 'Optional',
            icon: PhosphorIconsRegular.tag,
            controller: _branch,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: AppSpacing.base),

          NdcTextField(
            label: 'Residential Address',
            hint: 'Optional — house number and street',
            icon: PhosphorIconsRegular.house,
            controller: _residentialAddress,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: AppSpacing.base),

          NdcTextField(
            label: 'Town / City of Residence',
            hint: 'Optional',
            icon: PhosphorIconsRegular.city,
            controller: _residenceTown,
            textInputAction: TextInputAction.done,
          ),

          // Safety net: renders a visible error if any cascading dropdown
          // is still missing when the user taps Continue.
          FormField<void>(
            builder: (field) => field.hasError
                ? Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Row(
                      children: [
                        const PhosphorIcon(PhosphorIconsFill.warningCircle,
                            size: 16, color: AppColors.umbrellaRed),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(field.errorText!,
                              style: AppTextStyles.small(
                                  color: AppColors.umbrellaRed)),
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
            validator: (_) {
              if (_region == null) return 'Select a region to continue';
              if (_district == null) return 'Select a district to continue';
              if (_constituency == null) {
                return 'Select a constituency to continue';
              }
              if (_pollingStation == null) {
                return 'Select a polling station to continue';
              }
              ref.read(registrationFormProvider.notifier).updateStep2(
                regionId: _region?.id,
                regionName: _region?.name,
                districtId: _district?.id,
                districtName: _district?.name,
                constituencyId: _constituency?.id,
                constituencyName: _constituency?.name,
                pollingStationId: _pollingStation?.id,
                pollingStationName: _pollingStation?.name,
                ward: _ward.text.trim().isEmpty ? null : _ward.text.trim(),
                branch:
                    _branch.text.trim().isEmpty ? null : _branch.text.trim(),
                residentialAddress: _residentialAddress.text.trim().isEmpty
                    ? null
                    : _residentialAddress.text.trim(),
                residenceTown: _residenceTown.text.trim().isEmpty
                    ? null
                    : _residenceTown.text.trim(),
              );
              return null;
            },
          ),
        ],
      ),
    );
  }
}

// ── Polling station: searchable picker ───────────────────────────────────────

class _PollingStationField extends StatelessWidget {
  final AsyncValue<List<PollingStation>> asyncData;
  final PollingStation? selected;
  final bool enabled;
  final void Function(PollingStation?) onChanged;
  final String? Function() validator;
  final VoidCallback? onRetry;

  const _PollingStationField({
    required this.asyncData,
    required this.selected,
    required this.enabled,
    required this.onChanged,
    required this.validator,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Polling Station *', style: AppTextStyles.label()),
        const SizedBox(height: 6),
        FormField<PollingStation>(
          validator: (_) => validator(),
          builder: (field) => asyncData.when(
            data: (stations) {
              final label = selected == null
                  ? (enabled
                      ? 'Search polling station'
                      : 'Select constituency first')
                  : (selected!.stationCode != null
                      ? '${selected!.stationCode} — ${selected!.name}'
                      : selected!.name);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: enabled && stations.isNotEmpty
                        ? () async {
                            final picked =
                                await showModalBottomSheet<PollingStation>(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: AppColors.surface,
                              shape: const RoundedRectangleBorder(
                                  borderRadius: AppRadii.sheetTop),
                              builder: (_) => _StationSearchSheet(
                                  stations: stations, selected: selected),
                            );
                            if (picked != null) {
                              onChanged(picked);
                              field.didChange(picked);
                            }
                          }
                        : null,
                    child: Container(
                      height: 52,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: field.hasError
                              ? AppColors.umbrellaRed
                              : AppColors.hairline,
                        ),
                        borderRadius: AppRadii.borderSm,
                        color:
                            enabled ? AppColors.surface : AppColors.fillMuted,
                      ),
                      child: Row(
                        children: [
                          const PhosphorIcon(PhosphorIconsRegular.buildings,
                              size: 20, color: AppColors.textMuted),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              label,
                              style: selected == null
                                  ? AppTextStyles.bodyLarge(
                                      color: AppColors.textMuted)
                                  : AppTextStyles.bodyLarge(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (enabled)
                            const PhosphorIcon(
                                PhosphorIconsRegular.magnifyingGlass,
                                size: 18,
                                color: AppColors.mist),
                        ],
                      ),
                    ),
                  ),
                  if (field.hasError) ...[
                    const SizedBox(height: 6),
                    Text(field.errorText!,
                        style:
                            AppTextStyles.small(color: AppColors.umbrellaRed)),
                  ],
                ],
              );
            },
            loading: () => _stationField('Loading polling stations…'),
            error: (_, _) => RegistrationRetryField(
                message: "Couldn't load polling stations", onRetry: onRetry),
          ),
        ),
      ],
    );
  }

  Widget _stationField(String text) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.hairline),
        borderRadius: AppRadii.borderSm,
        color: AppColors.fillMuted,
      ),
      child: Row(
        children: [
          const PhosphorIcon(PhosphorIconsRegular.buildings,
              size: 20, color: AppColors.mist),
          const SizedBox(width: 12),
          Expanded(
              child:
                  Text(text, style: AppTextStyles.bodyLarge(color: AppColors.mist))),
        ],
      ),
    );
  }
}

class _StationSearchSheet extends StatefulWidget {
  final List<PollingStation> stations;
  final PollingStation? selected;

  const _StationSearchSheet({required this.stations, required this.selected});

  @override
  State<_StationSearchSheet> createState() => _StationSearchSheetState();
}

class _StationSearchSheetState extends State<_StationSearchSheet> {
  final _searchCtrl = TextEditingController();
  late List<PollingStation> _filtered;

  @override
  void initState() {
    super.initState();
    _filtered = widget.stations;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearch(String q) {
    final query = q.trim().toLowerCase();
    setState(() {
      _filtered = query.isEmpty
          ? widget.stations
          : widget.stations
              .where((s) =>
                  s.name.toLowerCase().contains(query) ||
                  (s.stationCode?.toLowerCase().contains(query) ?? false))
              .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                  color: AppColors.hairline,
                  borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Row(
                children: [
                  Expanded(
                      child: Text('Polling station', style: AppTextStyles.h2())),
                  Text('${_filtered.length}', style: AppTextStyles.caption()),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _searchCtrl,
                autofocus: true,
                onChanged: _onSearch,
                decoration: const InputDecoration(
                  hintText: 'Search by name or code (e.g. COMM.2 or C240101)',
                  prefixIcon: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: PhosphorIcon(PhosphorIconsRegular.magnifyingGlass,
                        size: 20, color: AppColors.mist),
                  ),
                  prefixIconConstraints: BoxConstraints(minWidth: 44),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _filtered.isEmpty
                  ? Center(
                      child: Text('No matching station',
                          style: AppTextStyles.body(color: AppColors.mist)))
                  : ListView.builder(
                      controller: scrollController,
                      itemCount: _filtered.length,
                      itemBuilder: (_, i) {
                        final s = _filtered[i];
                        final isSel = s.id == widget.selected?.id;
                        return ListTile(
                          onTap: () => Navigator.pop(context, s),
                          leading: PhosphorIcon(
                            isSel
                                ? PhosphorIconsFill.checkCircle
                                : PhosphorIconsRegular.mapPin,
                            color: isSel
                                ? AppColors.canopyGreen
                                : AppColors.mist,
                            size: 22,
                          ),
                          title:
                              Text(s.name, style: AppTextStyles.bodyMedium()),
                          subtitle: s.stationCode != null
                              ? Text(s.stationCode!,
                                  style: AppTextStyles.memberNumber())
                              : null,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
