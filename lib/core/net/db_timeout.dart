/// Hard ceiling for any single database/storage call. A hung request must
/// surface as a catchable (and mapped) error — never an indefinite spinner.
/// Apply at every repository await site: `await query.dbTimeout()`.
extension DbTimeout<T> on Future<T> {
  Future<T> dbTimeout() => timeout(const Duration(seconds: 15));
}
