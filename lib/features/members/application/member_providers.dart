import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/member_repository.dart';
import '../../auth/application/auth_provider.dart';

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

// Signed URL for a photo path (1 hour TTL)
final photoUrlProvider = FutureProvider.autoDispose.family<String?, String>((ref, path) async {
  if (path.isEmpty) return null;
  final response = await Supabase.instance.client.storage
      .from('member-photos')
      .createSignedUrl(path, 3600);
  return response;
});
