import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/operator_repository.dart';

final operatorPageProvider = StateProvider<int>((ref) => 0);

final operatorsProvider = FutureProvider.autoDispose<List<OperatorDetail>>((ref) async {
  final page = ref.watch(operatorPageProvider);
  return OperatorRepository().listOperators(page: page);
});

final operatorStatsProvider = FutureProvider.autoDispose<Map<String, int>>((ref) async {
  return OperatorRepository().countByRole();
});
