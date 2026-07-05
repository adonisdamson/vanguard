import 'package:supabase_flutter/supabase_flutter.dart';

class Region {
  final int id;
  final String name;
  const Region({required this.id, required this.name});
  factory Region.fromMap(Map<String, dynamic> m) =>
      Region(id: m['id'] as int, name: m['name'] as String);
}

class District {
  final int id;
  final int regionId;
  final String name;
  const District({required this.id, required this.regionId, required this.name});
  factory District.fromMap(Map<String, dynamic> m) =>
      District(id: m['id'] as int, regionId: m['region_id'] as int, name: m['name'] as String);
}

class Constituency {
  final int id;
  final int districtId;
  final String name;
  const Constituency({required this.id, required this.districtId, required this.name});
  factory Constituency.fromMap(Map<String, dynamic> m) =>
      Constituency(id: m['id'] as int, districtId: m['district_id'] as int, name: m['name'] as String);
}

class PollingStation {
  final int id;
  final int constituencyId;
  final String name;
  final String? electoralArea;
  final String? stationCode;
  const PollingStation({
    required this.id,
    required this.constituencyId,
    required this.name,
    this.electoralArea,
    this.stationCode,
  });
  factory PollingStation.fromMap(Map<String, dynamic> m) => PollingStation(
    id: m['id'] as int,
    constituencyId: m['constituency_id'] as int,
    name: m['name'] as String,
    electoralArea: m['electoral_area']?.toString(),
    stationCode: m['station_code'] as String?,
  );
}

class LocationRepository {
  final _db = Supabase.instance.client;

  Future<List<Region>> fetchRegions() async {
    final data = await _db.from('regions').select('id, name').order('name').limit(50);
    return (data as List).map((m) => Region.fromMap(m as Map<String, dynamic>)).toList();
  }

  Future<List<District>> fetchDistricts(int regionId) async {
    final data = await _db
        .from('districts')
        .select('id, region_id, name')
        .eq('region_id', regionId)
        .order('name')
        .limit(500);
    return (data as List).map((m) => District.fromMap(m as Map<String, dynamic>)).toList();
  }

  Future<List<Constituency>> fetchConstituencies(int districtId) async {
    final data = await _db
        .from('constituencies')
        .select('id, district_id, name')
        .eq('district_id', districtId)
        .order('name')
        .limit(500);
    return (data as List).map((m) => Constituency.fromMap(m as Map<String, dynamic>)).toList();
  }

  Future<List<String>> fetchElectoralAreas(int constituencyId) async {
    final data = await _db
        .from('polling_stations')
        .select('electoral_area')
        .eq('constituency_id', constituencyId)
        .not('electoral_area', 'is', null)
        .order('electoral_area')
        .limit(500);
    final seen = <String>{};
    final areas = <String>[];
    for (final m in data as List) {
      final ea = m['electoral_area'] as String;
      if (seen.add(ea)) areas.add(ea);
    }
    return areas;
  }

  Future<List<PollingStation>> fetchPollingStations(int constituencyId, {String? electoralArea}) async {
    var query = _db
        .from('polling_stations')
        .select('id, constituency_id, name, electoral_area, station_code')
        .eq('constituency_id', constituencyId);
    if (electoralArea != null) query = query.eq('electoral_area', electoralArea);
    final data = await query.order('name').limit(500);
    return (data as List).map((m) => PollingStation.fromMap(m as Map<String, dynamic>)).toList();
  }
}
