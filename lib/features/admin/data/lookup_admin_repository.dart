import 'package:supabase_flutter/supabase_flutter.dart';
import '../../members/data/location_repository.dart';

class LookupAdminRepository {
  final _db = Supabase.instance.client;

  // ── Regions ────────────────────────────────────────────────────────────────

  Future<List<Region>> fetchAllRegions() async {
    final data = await _db.from('regions').select('id, name').order('name');
    return (data as List).map((m) => Region.fromMap(m as Map<String, dynamic>)).toList();
  }

  Future<void> createRegion(String name) async {
    await _db.from('regions').insert({'name': name.trim()});
  }

  Future<void> updateRegion(int id, String name) async {
    await _db.from('regions').update({'name': name.trim()}).eq('id', id);
  }

  Future<void> deleteRegion(int id) async {
    await _db.from('regions').delete().eq('id', id);
  }

  // ── Districts ──────────────────────────────────────────────────────────────

  Future<List<District>> fetchDistricts({int? regionId}) async {
    var q = _db.from('districts').select('id, region_id, name');
    if (regionId != null) q = q.eq('region_id', regionId);
    final data = await q.order('name');
    return (data as List).map((m) => District.fromMap(m as Map<String, dynamic>)).toList();
  }

  Future<void> createDistrict(int regionId, String name) async {
    await _db.from('districts').insert({'region_id': regionId, 'name': name.trim()});
  }

  Future<void> updateDistrict(int id, String name) async {
    await _db.from('districts').update({'name': name.trim()}).eq('id', id);
  }

  Future<void> deleteDistrict(int id) async {
    await _db.from('districts').delete().eq('id', id);
  }

  // ── Constituencies ─────────────────────────────────────────────────────────

  Future<List<Constituency>> fetchConstituencies({int? districtId}) async {
    var q = _db.from('constituencies').select('id, district_id, name');
    if (districtId != null) q = q.eq('district_id', districtId);
    final data = await q.order('name');
    return (data as List).map((m) => Constituency.fromMap(m as Map<String, dynamic>)).toList();
  }

  Future<void> createConstituency(int districtId, String name) async {
    await _db.from('constituencies').insert({'district_id': districtId, 'name': name.trim()});
  }

  Future<void> updateConstituency(int id, String name) async {
    await _db.from('constituencies').update({'name': name.trim()}).eq('id', id);
  }

  Future<void> deleteConstituency(int id) async {
    await _db.from('constituencies').delete().eq('id', id);
  }

  // ── Polling Stations ───────────────────────────────────────────────────────

  Future<List<PollingStation>> fetchPollingStations({int? constituencyId}) async {
    var q = _db.from('polling_stations').select('id, constituency_id, name');
    if (constituencyId != null) q = q.eq('constituency_id', constituencyId);
    final data = await q.order('name');
    return (data as List).map((m) => PollingStation.fromMap(m as Map<String, dynamic>)).toList();
  }

  Future<void> createPollingStation(int constituencyId, String name) async {
    await _db.from('polling_stations').insert({'constituency_id': constituencyId, 'name': name.trim()});
  }

  Future<void> updatePollingStation(int id, String name) async {
    await _db.from('polling_stations').update({'name': name.trim()}).eq('id', id);
  }

  Future<void> deletePollingStation(int id) async {
    await _db.from('polling_stations').delete().eq('id', id);
  }
}
