import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/review_repository.dart';

final _repo = ReviewRepository();

// ── Review queue ────────────────────────────────────────────────────────────

final reviewQueuePageProvider = StateProvider<int>((ref) => 0);

final reviewQueueProvider = FutureProvider.autoDispose<List<MemberDetail>>((ref) async {
  final page = ref.watch(reviewQueuePageProvider);
  return _repo.fetchPendingMembers(page: page);
});

// ── Member directory ─────────────────────────────────────────────────────────

final directorySearchProvider = StateProvider<String>((ref) => '');
final directoryFilterProvider = StateProvider<String>((ref) => 'all');
final directoryPageProvider = StateProvider<int>((ref) => 0);

final memberDirectoryProvider = FutureProvider.autoDispose<List<MemberDetail>>((ref) async {
  final query = ref.watch(directorySearchProvider);
  final filter = ref.watch(directoryFilterProvider);
  final page = ref.watch(directoryPageProvider);
  return _repo.searchMembers(
    page: page,
    query: query.isEmpty ? null : query,
    statusFilter: filter,
  );
});

// ── Member detail ─────────────────────────────────────────────────────────────

final memberDetailProvider =
    FutureProvider.autoDispose.family<MemberDetail, String>((ref, id) async {
  return _repo.fetchMemberDetail(id);
});

final auditHistoryProvider =
    FutureProvider.autoDispose.family<List<AuditEntry>, String>((ref, memberId) async {
  return _repo.fetchAuditHistory(memberId);
});
