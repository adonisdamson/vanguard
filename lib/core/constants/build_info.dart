/// Build provenance, injected at CI build time via --dart-define
/// (see .github/workflows/build-apk.yml). Local/debug builds show defaults,
/// so a stamp reading "dev · local" means the APK did NOT come from CI.
class BuildInfo {
  static const version =
      String.fromEnvironment('APP_VERSION', defaultValue: 'dev');
  static const gitSha = String.fromEnvironment('GIT_SHA', defaultValue: 'local');
  static const buildDate =
      String.fromEnvironment('BUILD_DATE', defaultValue: 'unbuilt');
  static const stamp = 'v$version · $gitSha · $buildDate';

  /// Version only — safe to show in-app (no build timestamp / commit).
  static const versionLabel = 'v$version';
}
