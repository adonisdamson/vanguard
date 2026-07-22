import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/net/db_timeout.dart';
import '../../../core/net/photo_service.dart';

class MemberSummary {
  final String id;
  final String? memberNumber;
  final String firstName;
  final String lastName;
  final String status;
  final String? phone;
  final String? photoPath;
  final DateTime createdAt;

  const MemberSummary({
    required this.id,
    this.memberNumber,
    required this.firstName,
    required this.lastName,
    required this.status,
    this.phone,
    this.photoPath,
    required this.createdAt,
  });

  factory MemberSummary.fromMap(Map<String, dynamic> m) {
    return MemberSummary(
      id: m['id'] as String,
      memberNumber: m['member_number'] as String?,
      firstName: m['first_name'] as String,
      lastName: m['last_name'] as String,
      status: m['status'] as String,
      phone: m['phone'] as String?,
      photoPath: m['photo_path'] as String?,
      createdAt: DateTime.parse(m['created_at'] as String),
    );
  }

  String get fullName => '$firstName $lastName';
}

class MemberStats {
  final int total;
  final int pending;
  final int active;
  final int rejected;

  const MemberStats({
    required this.total,
    required this.pending,
    required this.active,
    required this.rejected,
  });
}

class MemberRepository {
  final _db = Supabase.instance.client;

  // Insert member row, returning the new member ID and member_number
  Future<Map<String, String>> insertMember(Map<String, dynamic> data) async {
    final result = await _db
        .from('members')
        .insert(data)
        .select('id, member_number')
        .single().dbTimeout();
    return {
      'id': result['id'] as String,
      'member_number': result['member_number'] as String? ?? '',
    };
  }

  // Upload photo to R2 via the Worker; returns the object key (== photo_path)
  Future<String> uploadPhoto(String localPath, String userId) async {
    final file = File(localPath);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final ext = localPath.split('.').last.toLowerCase();
    final storagePath = '$userId/${timestamp}_member.$ext';

    await PhotoService.upload(
      key: storagePath,
      bytes: await file.readAsBytes(),
      contentType: ext == 'png' ? 'image/png' : 'image/jpeg',
    );
    return storagePath;
  }

  // Paginated list of own submissions
  Future<List<MemberSummary>> fetchMySubmissions({
    required String userId,
    required int page,
    String? statusFilter,
    int pageSize = 20,
  }) async {
    final from = page * pageSize;
    final to = from + pageSize - 1;

    var query = _db
        .from('members')
        .select('id, member_number, first_name, last_name, status, phone, photo_path, created_at')
        .eq('registered_by', userId)
        .order('created_at', ascending: false)
        .range(from, to);

    if (statusFilter != null && statusFilter != 'all') {
      query = _db
          .from('members')
          .select('id, member_number, first_name, last_name, status, phone, photo_path, created_at')
          .eq('registered_by', userId)
          .eq('status', statusFilter)
          .order('created_at', ascending: false)
          .range(from, to);
    }

    final data = await query.dbTimeout();
    return (data as List)
        .map((m) => MemberSummary.fromMap(m as Map<String, dynamic>))
        .toList();
  }

  // Stats for own submissions — parallel HEAD count queries; no row data transferred
  Future<MemberStats> fetchMyStats(String userId) async {
    final results = await Future.wait([
      _db.from('members').select().eq('registered_by', userId).count(CountOption.exact),
      _db.from('members').select().eq('registered_by', userId).eq('status', 'pending').count(CountOption.exact),
      _db.from('members').select().eq('registered_by', userId).eq('status', 'active').count(CountOption.exact),
      _db.from('members').select().eq('registered_by', userId).eq('status', 'rejected').count(CountOption.exact),
    ]).dbTimeout();
    return MemberStats(
      total: results[0].count,
      pending: results[1].count,
      active: results[2].count,
      rejected: results[3].count,
    );
  }
}
