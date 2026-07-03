import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/lookup_admin_repository.dart';
import '../../members/data/location_repository.dart';

// Selected parent filters for cascading views
final lookupRegionFilterProvider = StateProvider<int?>((ref) => null);
final lookupDistrictFilterProvider = StateProvider<int?>((ref) => null);
final lookupConstituencyFilterProvider = StateProvider<int?>((ref) => null);

final allRegionsProvider = FutureProvider.autoDispose<List<Region>>((ref) async {
  return LookupAdminRepository().fetchAllRegions();
});

final adminDistrictsProvider = FutureProvider.autoDispose<List<District>>((ref) async {
  final regionId = ref.watch(lookupRegionFilterProvider);
  return LookupAdminRepository().fetchDistricts(regionId: regionId);
});

final adminConstituenciesProvider = FutureProvider.autoDispose<List<Constituency>>((ref) async {
  final districtId = ref.watch(lookupDistrictFilterProvider);
  return LookupAdminRepository().fetchConstituencies(districtId: districtId);
});

final adminPollingStationsProvider = FutureProvider.autoDispose<List<PollingStation>>((ref) async {
  final constituencyId = ref.watch(lookupConstituencyFilterProvider);
  return LookupAdminRepository().fetchPollingStations(constituencyId: constituencyId);
});
