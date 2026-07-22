import 'update_info.dart';

/// Web build: there is no sideloaded APK to update — the browser always loads
/// the latest deployed version. Every method is a safe no-op so the shared
/// UpdateGate simply does nothing on web.
class UpdateService {
  static Future<UpdateInfo?> check() async => null;

  static Future<String> download(
    String url, {
    void Function(double progress)? onProgress,
  }) async =>
      '';

  static Future<void> install(String path) async {}

  static int compareVersions(String a, String b) => 0;
}
