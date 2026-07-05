import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/dashboard_repository.dart';
import '../../admin/data/audit_repository.dart';

final _repo = DashboardRepository();

final dashboardStatsProvider = FutureProvider.autoDispose<DashboardStats>((ref) async {
  return _repo.fetchStats();
});

final recentActivityProvider = FutureProvider<List<AuditEntry>>((ref) async {
  return AuditRepository().fetchAuditLog(page: 0, pageSize: 5);
});
