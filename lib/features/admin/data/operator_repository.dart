import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../auth/application/user_role_provider.dart';
import '../../../core/net/db_timeout.dart';

AppUserRole _parseRole(String role) {
  switch (role) {
    case 'admin':
      return AppUserRole.admin;
    case 'manager':
      return AppUserRole.manager;
    case 'higher_authority':
      return AppUserRole.higherAuthority;
    default:
      return AppUserRole.personnel;
  }
}

String roleToString(AppUserRole role) {
  switch (role) {
    case AppUserRole.admin:
      return 'admin';
    case AppUserRole.manager:
      return 'manager';
    case AppUserRole.higherAuthority:
      return 'higher_authority';
    case AppUserRole.personnel:
      return 'personnel';
  }
}

class OperatorDetail {
  final String id;
  final String fullName;
  final String email;
  final String? phone;
  final AppUserRole role;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? lastLoginAt;
  final String? partyPosition;
  final String? branch;
  final String? avatarPath;

  const OperatorDetail({
    required this.id,
    required this.fullName,
    required this.email,
    this.phone,
    required this.role,
    required this.isActive,
    required this.createdAt,
    this.lastLoginAt,
    this.partyPosition,
    this.branch,
    this.avatarPath,
  });

  factory OperatorDetail.fromMap(Map<String, dynamic> m) {
    return OperatorDetail(
      id: m['id'] as String,
      fullName: m['full_name'] as String,
      email: m['email'] as String,
      phone: m['phone'] as String?,
      role: _parseRole(m['role'] as String? ?? 'personnel'),
      isActive: m['is_active'] as bool? ?? false,
      createdAt: DateTime.parse(m['created_at'] as String),
      lastLoginAt: m['last_login_at'] != null
          ? DateTime.parse(m['last_login_at'] as String)
          : null,
      partyPosition: m['party_position'] as String?,
      branch: m['branch'] as String?,
      avatarPath: m['avatar_path'] as String?,
    );
  }

  OperatorDetail copyWith({bool? isActive, AppUserRole? role}) {
    return OperatorDetail(
      id: id,
      fullName: fullName,
      email: email,
      phone: phone,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
      lastLoginAt: lastLoginAt,
      partyPosition: partyPosition,
      branch: branch,
      avatarPath: avatarPath,
    );
  }
}

class PendingOperator {
  final String id;
  final String fullName;
  final String email;
  final String? requestedRole;
  final String? avatarPath;
  final DateTime createdAt;

  const PendingOperator({
    required this.id,
    required this.fullName,
    required this.email,
    this.requestedRole,
    this.avatarPath,
    required this.createdAt,
  });

  factory PendingOperator.fromMap(Map<String, dynamic> m) {
    return PendingOperator(
      id: m['id'] as String,
      fullName: m['full_name'] as String,
      email: m['email'] as String,
      requestedRole: m['requested_role'] as String?,
      avatarPath: m['avatar_path'] as String?,
      createdAt: DateTime.parse(m['created_at'] as String),
    );
  }
}

class OperatorRepository {
  final _db = Supabase.instance.client;
  static const _pageSize = 20;

  Future<List<PendingOperator>> listPendingOperators() async {
    final data = await _db
        .from('app_users')
        .select('id, full_name, email, requested_role, avatar_path, created_at')
        .isFilter('role', null)
        .eq('is_active', false)
        .order('created_at', ascending: true)
        .limit(500).dbTimeout();
    return (data as List).map((m) => PendingOperator.fromMap(m as Map<String, dynamic>)).toList();
  }

  Future<List<OperatorDetail>> listOperators({int page = 0, String? search}) async {
    var query = _db
        .from('app_users')
        .select('id, full_name, email, phone, role, is_active, created_at, last_login_at, party_position, branch, avatar_path')
        .not('role', 'is', null); // exclude pending self-signups
    final q = (search ?? '').trim();
    if (q.isNotEmpty) {
      // Match name, phone or email (case-insensitive).
      final esc = q.replaceAll(',', ' ');
      query = query.or('full_name.ilike.%$esc%,phone.ilike.%$esc%,email.ilike.%$esc%');
    }
    final data = await query
        .order('created_at', ascending: false)
        .range(page * _pageSize, (page + 1) * _pageSize - 1).dbTimeout();
    return (data as List).map((m) => OperatorDetail.fromMap(m as Map<String, dynamic>)).toList();
  }

  Future<Map<String, int>> countByRole() async {
    final base = _db.from('app_users').select().not('role', 'is', null);
    final results = await Future.wait([
      base.count(CountOption.exact),
      base.eq('role', 'admin').count(CountOption.exact),
      base.eq('role', 'manager').count(CountOption.exact),
      base.eq('role', 'higher_authority').count(CountOption.exact),
      base.eq('role', 'personnel').count(CountOption.exact),
    ]).dbTimeout();
    return {
      'total': results[0].count,
      'admin': results[1].count,
      'manager': results[2].count,
      'higher_authority': results[3].count,
      'personnel': results[4].count,
    };
  }

  Future<void> createOperator({
    required String fullName,
    required String email,
    required String role,
    required String password,
    String? phone,
    String? partyPosition,
    String? branch,
    int? assignedRegionId,
    int? assignedDistrictId,
    int? assignedConstituencyId,
  }) async {
    await _railwayPost('/api/admin/operators', {
      'full_name': fullName,
      'email': email,
      'role': role,
      // Temporary password set by the admin — the account works immediately,
      // with no dependence on invite-email deliverability.
      'password': password,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
      if (partyPosition != null && partyPosition.isNotEmpty) 'party_position': partyPosition,
      if (branch != null && branch.isNotEmpty) 'branch': branch,
      'assigned_region_id': ?assignedRegionId,
      'assigned_district_id': ?assignedDistrictId,
      'assigned_constituency_id': ?assignedConstituencyId,
    }).dbTimeout();
  }

  Future<void> suspendOperator(String id) async {
    await _railwayPost('/api/admin/operators/$id/suspend', {}).dbTimeout();
  }

  Future<void> reactivateOperator(String id) async {
    await _railwayPost('/api/admin/operators/$id/reactivate', {}).dbTimeout();
  }

  Future<void> changeRole(String id, String role) async {
    await _railwayPost('/api/admin/operators/$id/role', {'role': role}).dbTimeout();
  }

  Future<void> approveOperator(
    String id,
    String role, {
    int? assignedRegionId,
    int? assignedDistrictId,
    int? assignedConstituencyId,
  }) async {
    await _railwayPost('/api/admin/operators/$id/approve', {
      'role': role,
      'assigned_region_id': ?assignedRegionId,
      'assigned_district_id': ?assignedDistrictId,
      'assigned_constituency_id': ?assignedConstituencyId,
    }).dbTimeout();
  }

  Future<void> setOperatorPassword(String id, String password) async {
    await _railwayPost('/api/admin/operators/$id/password', {'password': password}).dbTimeout();
  }

  Future<void> declineOperator(String id) async {
    await _railwayPost('/api/admin/operators/$id/decline', {}).dbTimeout();
  }

  Future<void> _railwayPost(String path, Map<String, dynamic> body) async {
    final token = _db.auth.currentSession?.accessToken;
    if (token == null) throw Exception('Not authenticated');

    final baseUrl =
        dotenv.env['API_BASE_URL'] ?? dotenv.env['RAILWAY_API_URL'] ?? '';
    if (baseUrl.isEmpty) throw Exception('API_BASE_URL not configured');
    final uri = Uri.parse('$baseUrl$path');

    final response = await http.post(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode >= 400) {
      // Only surface our API's own safe `error` field — never a raw server or
      // HTML error body (which could reveal backend internals).
      var message = 'Request failed (${response.statusCode})';
      try {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        if (decoded['error'] != null) message = decoded['error'].toString();
      } catch (_) {
        // keep the generic message
      }
      throw Exception(message);
    }
  }
}
