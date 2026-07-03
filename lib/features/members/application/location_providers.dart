import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/location_repository.dart';

final _locationRepo = LocationRepository();

// Cascade selection state
final selectedRegionIdProvider = StateProvider<int?>((ref) => null);
final selectedDistrictIdProvider = StateProvider<int?>((ref) => null);
final selectedConstituencyIdProvider = StateProvider<int?>((ref) => null);

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

final pollingStationsProvider = FutureProvider<List<PollingStation>>((ref) async {
  final constituencyId = ref.watch(selectedConstituencyIdProvider);
  if (constituencyId == null) return [];
  return _locationRepo.fetchPollingStations(constituencyId);
});
