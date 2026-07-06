import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/dashboard_repository.dart';
import '../../admin/data/audit_repository.dart';

final _repo = DashboardRepository();

final dashboardStatsProvider = FutureProvider.autoDispose<DashboardStats>((ref) async {
  return _repo.fetchStats();
});

final recentActivityProvider = FutureProvider.autoDispose<List<AuditEntry>>((ref) async {
  // Home feeds show MEMBER activity only — registrations and reviews.
  // Operator/account administration stays in the audit log.
  return AuditRepository().fetchAuditLog(
    page: 0,
    pageSize: 5,
    actions: ['member_created', 'member_status_changed'],
  );
});
