import 'dart:convert';
import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../auth/application/user_role_provider.dart';

AppUserRole _parseRole(String role) {
  switch (role) {
    case 'admin':
      return AppUserRole.admin;
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

  const OperatorDetail({
    required this.id,
    required this.fullName,
    required this.email,
    this.phone,
    required this.role,
    required this.isActive,
    required this.createdAt,
    this.lastLoginAt,
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
    );
  }
}

class PendingOperator {
  final String id;
  final String fullName;
  final String email;
  final String? requestedRole;
  final DateTime createdAt;

  const PendingOperator({
    required this.id,
    required this.fullName,
    required this.email,
    this.requestedRole,
    required this.createdAt,
  });

  factory PendingOperator.fromMap(Map<String, dynamic> m) {
    return PendingOperator(
      id: m['id'] as String,
      fullName: m['full_name'] as String,
      email: m['email'] as String,
      requestedRole: m['requested_role'] as String?,
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
        .select('id, full_name, email, requested_role, created_at')
        .is_('role', null)
        .eq('is_active', false)
        .order('created_at', ascending: true);
    return (data as List).map((m) => PendingOperator.fromMap(m as Map<String, dynamic>)).toList();
  }

  Future<List<OperatorDetail>> listOperators({int page = 0}) async {
    final data = await _db
        .from('app_users')
        .select('id, full_name, email, phone, role, is_active, created_at, last_login_at')
        .not('role', 'is', null)  // exclude pending self-signups
        .order('created_at', ascending: false)
        .range(page * _pageSize, (page + 1) * _pageSize - 1);
    return (data as List).map((m) => OperatorDetail.fromMap(m as Map<String, dynamic>)).toList();
  }

  Future<Map<String, int>> countByRole() async {
    final data = await _db.from('app_users').select('role, is_active');
    final counts = <String, int>{'admin': 0, 'higher_authority': 0, 'personnel': 0, 'total': 0};
    for (final row in data as List) {
      final role = row['role'] as String;
      counts[role] = (counts[role] ?? 0) + 1;
      counts['total'] = counts['total']! + 1;
    }
    return counts;
  }

  Future<void> createOperator({
    required String fullName,
    required String email,
    required String role,
    String? phone,
  }) async {
    await _railwayPost('/api/admin/operators', {
      'full_name': fullName,
      'email': email,
      'role': role,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
    });
  }

  Future<void> suspendOperator(String id) async {
    await _railwayPost('/api/admin/operators/$id/suspend', {});
  }

  Future<void> reactivateOperator(String id) async {
    await _railwayPost('/api/admin/operators/$id/reactivate', {});
  }

  Future<void> changeRole(String id, String role) async {
    await _railwayPost('/api/admin/operators/$id/role', {'role': role});
  }

  Future<void> approveOperator(String id, String role) async {
    await _railwayPost('/api/admin/operators/$id/approve', {'role': role});
  }

  Future<void> declineOperator(String id) async {
    await _railwayPost('/api/admin/operators/$id/decline', {});
  }

  Future<void> _railwayPost(String path, Map<String, dynamic> body) async {
    final token = _db.auth.currentSession?.accessToken;
    if (token == null) throw Exception('Not authenticated');

    final baseUrl = dotenv.env['RAILWAY_API_URL'] ?? '';
    if (baseUrl.isEmpty) throw Exception('RAILWAY_API_URL not configured');
    final uri = Uri.parse('$baseUrl$path');

    final client = HttpClient();
    try {
      final request = await client.postUrl(uri);
      request.headers.set('Authorization', 'Bearer $token');
      request.headers.set('Content-Type', 'application/json');
      request.write(jsonEncode(body));

      final response = await request.close().timeout(const Duration(seconds: 30));
      final responseBody = await response.transform(const Utf8Decoder()).join();

      if (response.statusCode >= 400) {
        final decoded = jsonDecode(responseBody) as Map<String, dynamic>;
        throw Exception(decoded['error'] ?? 'Request failed (${response.statusCode})');
      }
    } finally {
      client.close();
    }
  }
}
