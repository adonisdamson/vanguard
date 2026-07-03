import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/audit_repository.dart';

final auditActionFilterProvider = StateProvider<String?>((ref) => null);
final auditPageProvider = StateProvider<int>((ref) => 0);

final auditLogProvider = FutureProvider.autoDispose<List<AuditEntry>>((ref) async {
  final page = ref.watch(auditPageProvider);
  final filter = ref.watch(auditActionFilterProvider);
  return AuditRepository().fetchAuditLog(page: page, actionFilter: filter);
});
