import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/notification_repository.dart';
import '../../auth/application/auth_provider.dart';

final _repo = NotificationRepository();

final notificationsProvider =
    FutureProvider.autoDispose<List<AppNotification>>((ref) async {
  // Rebuild when auth changes so a new sign-in reloads the right inbox.
  ref.watch(supabaseAuthProvider);
  return _repo.fetch();
});

final unreadCountProvider = FutureProvider.autoDispose<int>((ref) async {
  ref.watch(supabaseAuthProvider);
  return _repo.unreadCount();
});
