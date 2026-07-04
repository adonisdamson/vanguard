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

  // Bulk import — idempotent upsert of full hierarchy from parsed CSV rows.
  // Each row must have: region, district, constituency, station_name.
  // electoral_area is optional.
  // Returns counts of (upserted, skipped due to missing fields, failed due to error).
  Future<({int upserted, int skipped, int failed})> bulkImportRows(
    List<Map<String, String>> rows,
  ) async {
    int upserted = 0, skipped = 0, failed = 0;

    final regionCache       = <String, int>{};
    final districtCache     = <String, int>{};
    final constituencyCache = <String, int>{};

    for (final row in rows) {
      final regionName       = row['region']?.trim() ?? '';
      final districtName     = row['district']?.trim() ?? '';
      final constituencyName = row['constituency']?.trim() ?? '';
      final stationName      = row['station_name']?.trim() ?? '';
      final eaRaw            = row['electoral_area']?.trim() ?? '';
      final eaValue          = eaRaw.isEmpty ? null : eaRaw;

      if (regionName.isEmpty || districtName.isEmpty || constituencyName.isEmpty || stationName.isEmpty) {
        skipped++;
        continue;
      }

      try {
        // Region — upsert on name uniqueness
        if (!regionCache.containsKey(regionName)) {
          final r = await _db
              .from('regions')
              .upsert({'name': regionName}, onConflict: 'name')
              .select('id')
              .single();
          regionCache[regionName] = r['id'] as int;
        }
        final regionId = regionCache[regionName]!;

        // District — upsert on (region_id, name) uniqueness
        final districtKey = '$regionId:$districtName';
        if (!districtCache.containsKey(districtKey)) {
          final r = await _db
              .from('districts')
              .upsert({'region_id': regionId, 'name': districtName}, onConflict: 'region_id,name')
              .select('id')
              .single();
          districtCache[districtKey] = r['id'] as int;
        }
        final districtId = districtCache[districtKey]!;

        // Constituency — upsert on (district_id, name) uniqueness
        final constituencyKey = '$districtId:$constituencyName';
        if (!constituencyCache.containsKey(constituencyKey)) {
          final r = await _db
              .from('constituencies')
              .upsert({'district_id': districtId, 'name': constituencyName}, onConflict: 'district_id,name')
              .select('id')
              .single();
          constituencyCache[constituencyKey] = r['id'] as int;
        }
        final constituencyId = constituencyCache[constituencyKey]!;

        // Polling station — upsert on (constituency_id, name) uniqueness
        await _db.from('polling_stations').upsert(
          {
            'constituency_id': constituencyId,
            'name': stationName,
            'electoral_area': ?eaValue,
          },
          onConflict: 'constituency_id,name',
        );

        upserted++;
      } catch (_) {
        failed++;
      }
    }

    return (upserted: upserted, skipped: skipped, failed: failed);
  }
}
