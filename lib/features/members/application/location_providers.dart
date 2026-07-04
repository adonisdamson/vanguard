import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/location_repository.dart';

final _locationRepo = LocationRepository();

// ── Cascade selection state ──────────────────────────────────────────────────
final selectedRegionIdProvider       = StateProvider<int?>((ref) => null);
final selectedDistrictIdProvider     = StateProvider<int?>((ref) => null);
final selectedConstituencyIdProvider = StateProvider<int?>((ref) => null);
final selectedElectoralAreaProvider  = StateProvider<String?>((ref) => null);

// ── Data providers ───────────────────────────────────────────────────────────
final regionsProvider = FutureProvider<List<Region>>((ref) async {
  return _locationRepo.fetchRegions();
});

final districtsProvider = FutureProvider<List<District>>((ref) async {
  final regionId = ref.watch(selectedRegionIdProvider);
  if (regionId == null) return [];
  return _locationRepo.fetchDistricts(regionId);
});

final constituenciesProvider = FutureProvider<List<Constituency>>((ref) async {
  final districtId = ref.watch(selectedDistrictIdProvider);
  if (districtId == null) return [];
  return _locationRepo.fetchConstituencies(districtId);
});

final electoralAreasProvider = FutureProvider<List<String>>((ref) async {
  final constituencyId = ref.watch(selectedConstituencyIdProvider);
  if (constituencyId == null) return [];
  return _locationRepo.fetchElectoralAreas(constituencyId);
});

final pollingStationsProvider = FutureProvider<List<PollingStation>>((ref) async {
  final constituencyId = ref.watch(selectedConstituencyIdProvider);
  if (constituencyId == null) return [];
  final electoralArea = ref.watch(selectedElectoralAreaProvider);
  return _locationRepo.fetchPollingStations(constituencyId, electoralArea: electoralArea);
});

// ── Location retention for "Save & Add Another" ──────────────────────────────
class LocationRetention {
  final Region? region;
  final District? district;
  final Constituency? constituency;
  final PollingStation? pollingStation;
  final String? electoralArea;
  final String? ward;
  final String? branch;
  final String? residentialAddress;
  final String? residenceTown;

  const LocationRetention({
    this.region,
    this.district,
    this.constituency,
    this.pollingStation,
    this.electoralArea,
    this.ward,
    this.branch,
    this.residentialAddress,
    this.residenceTown,
  });
}

final locationRetentionProvider = StateProvider<LocationRetention?>((ref) => null);
