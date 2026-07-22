import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/member_repository.dart';
import '../../auth/application/auth_provider.dart';
import '../../../core/net/photo_service.dart';

final _repo = MemberRepository();

// Submissions filter — 'all' | 'pending' | 'active' | 'rejected'
final submissionsFilterProvider = StateProvider<String>((ref) => 'all');

// Current page index
final submissionsPageProvider = StateProvider<int>((ref) => 0);

// Paginated submissions list
final mySubmissionsProvider = FutureProvider.autoDispose<List<MemberSummary>>((ref) async {
  final session = ref.watch(currentSessionProvider);
  if (session == null) return [];
  final filter = ref.watch(submissionsFilterProvider);
  final page = ref.watch(submissionsPageProvider);
  return _repo.fetchMySubmissions(
    userId: session.user.id,
    page: page,
    statusFilter: filter,
  );
});

// Stats for home screen
final myStatsProvider = FutureProvider.autoDispose<MemberStats>((ref) async {
  final session = ref.watch(currentSessionProvider);
  if (session == null) return const MemberStats(total: 0, pending: 0, active: 0, rejected: 0);
  return _repo.fetchMyStats(session.user.id);
});

// Authenticated Worker view URL for a photo key (R2-backed). Deterministic —
// the bytes are fetched by the image widget with PhotoService.authHeaders().
final photoUrlProvider = FutureProvider.autoDispose.family<String?, String>((ref, path) async {
  if (path.isEmpty) return null;
  return PhotoService.viewUrl(path);
});

// Recent submissions for the personnel activity feed.
// Uses the members table (RLS-accessible to personnel) instead of audit_log
// which is blocked for the personnel role.
final personnelRecentActivityProvider = FutureProvider.autoDispose<List<MemberSummary>>((ref) async {
  final session = ref.watch(currentSessionProvider);
  if (session == null) return [];
  return _repo.fetchMySubmissions(
    userId: session.user.id,
    page: 0,
    pageSize: 5,
  );
});
