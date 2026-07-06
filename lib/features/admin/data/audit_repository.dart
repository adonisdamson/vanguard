import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/net/db_timeout.dart';

class AuditEntry {
  final int id;
  final String action;
  final String? targetTable;
  final String? targetId;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;
  final String? actorName;
  final String? actorEmail;

  const AuditEntry({
    required this.id,
    required this.action,
    this.targetTable,
    this.targetId,
    required this.metadata,
    required this.createdAt,
    this.actorName,
    this.actorEmail,
  });

  factory AuditEntry.fromMap(Map<String, dynamic> m) {
    final actor = m['actor'] as Map<String, dynamic>?;
    return AuditEntry(
      id: m['id'] as int,
      action: m['action'] as String,
      targetTable: m['target_table'] as String?,
      targetId: m['target_id'] as String?,
      metadata: (m['metadata'] as Map<String, dynamic>?) ?? {},
      createdAt: DateTime.parse(m['created_at'] as String),
      actorName: actor?['full_name'] as String?,
      actorEmail: actor?['email'] as String?,
    );
  }
}

class AuditRepository {
  final _db = Supabase.instance.client;
  static const _pageSize = 25;

  Future<List<AuditEntry>> fetchAuditLog({
    int page = 0,
    String? actionFilter,
    List<String>? actions,
    int pageSize = _pageSize,
  }) async {
    var query = _db
        .from('audit_log')
        .select('id, action, target_table, target_id, metadata, created_at, actor:app_users!actor_id(full_name, email)');

    if (actionFilter != null && actionFilter.isNotEmpty) {
      query = query.eq('action', actionFilter);
    }
    if (actions != null && actions.isNotEmpty) {
      query = query.inFilter('action', actions);
    }

    final data = await query
        .order('created_at', ascending: false)
        .range(page * pageSize, (page + 1) * pageSize - 1).dbTimeout();
    return (data as List).map((m) => AuditEntry.fromMap(m as Map<String, dynamic>)).toList();
  }
}
