import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/dashboard_repository.dart';

final _repo = DashboardRepository();

final dashboardStatsProvider = FutureProvider.autoDispose<DashboardStats>((ref) async {
  return _repo.fetchStats();
});
