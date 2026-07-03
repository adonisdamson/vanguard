import 'package:supabase_flutter/supabase_flutter.dart';

class MonthlyCount {
  final String month;
  final int count;
  const MonthlyCount({required this.month, required this.count});
}

class DashboardStats {
  final int total;
  final int pending;
  final int active;
  final int rejected;
  final int thisMonth;
  final List<MonthlyCount> trend;

  const DashboardStats({
    required this.total,
    required this.pending,
    required this.active,
    required this.rejected,
    required this.thisMonth,
    required this.trend,
  });
}

class DashboardRepository {
  final _db = Supabase.instance.client;

  Future<DashboardStats> fetchStats() async {
    // Parallel: status counts + monthly trend
    final results = await Future.wait([
      _db.rpc('get_member_status_counts'),
      _db.rpc('get_registration_trend'),
    ]);

    // Status counts
    final statusRows = results[0] as List;
    int total = 0, pending = 0, active = 0, rejected = 0;
    for (final row in statusRows) {
      final m = row as Map<String, dynamic>;
      final c = (m['count'] as int?) ?? 0;
      total += c;
      switch (m['status'] as String) {
        case 'pending':
          pending = c;
        case 'active':
          active = c;
        case 'rejected':
          rejected = c;
      }
    }

    // Monthly trend
    final trendRows = results[1] as List;
    final trend = trendRows.map((r) {
      final m = r as Map<String, dynamic>;
      return MonthlyCount(
        month: m['month'] as String,
        count: (m['count'] as int?) ?? 0,
      );
    }).toList();

    // This month count (last item in trend, or 0)
    final thisMonth = trend.isNotEmpty ? trend.last.count : 0;

    return DashboardStats(
      total: total,
      pending: pending,
      active: active,
      rejected: rejected,
      thisMonth: thisMonth,
      trend: trend,
    );
  }
}
