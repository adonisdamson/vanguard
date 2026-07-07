import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/net/db_timeout.dart';

class AppNotification {
  final int id;
  final String type; // new_registration | member_approved | member_rejected
  final String title;
  final String? body;
  final String? memberId;
  final bool read;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    this.body,
    this.memberId,
    required this.read,
    required this.createdAt,
  });

  factory AppNotification.fromMap(Map<String, dynamic> m) => AppNotification(
        id: m['id'] as int,
        type: m['type'] as String,
        title: m['title'] as String,
        body: m['body'] as String?,
        memberId: m['member_id'] as String?,
        read: m['read'] as bool? ?? false,
        createdAt: DateTime.parse(m['created_at'] as String),
      );
}

class NotificationRepository {
  final _db = Supabase.instance.client;

  Future<List<AppNotification>> fetch({int limit = 50}) async {
    final data = await _db
        .from('notifications')
        .select('id, type, title, body, member_id, read, created_at')
        .order('created_at', ascending: false)
        .limit(limit)
        .dbTimeout();
    return (data as List)
        .map((m) => AppNotification.fromMap(m as Map<String, dynamic>))
        .toList();
  }

  Future<int> unreadCount() async {
    final res = await _db
        .from('notifications')
        .select()
        .eq('read', false)
        .count(CountOption.exact)
        .dbTimeout();
    return res.count;
  }

  Future<void> markRead(int id) async {
    await _db.from('notifications').update({'read': true}).eq('id', id).dbTimeout();
  }

  Future<void> markAllRead() async {
    await _db.rpc('mark_all_notifications_read').dbTimeout();
  }
}
