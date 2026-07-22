import 'dart:convert';
import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../constants/build_info.dart';
import 'update_info.dart';

/// In-app updater for the sideloaded APK (mobile/desktop). Checks the backend's
/// `/download/version`, compares it to this build's [BuildInfo.version], and —
/// when newer — downloads the APK through our own Worker `/download` (streamed
/// via Cloudflare; GitHub is never referenced) and hands it to the system
/// installer.
///
/// The download runs silently in the background (see UpdateGate); the final
/// install is one OS tap — the platform ceiling for sideloaded apps.
class UpdateService {
  static String get _base =>
      dotenv.env['API_BASE_URL'] ?? dotenv.env['RAILWAY_API_URL'] ?? '';

  /// Returns update details if a newer version is available, else null.
  /// Never throws — a failed check simply yields null (offline, etc.).
  static Future<UpdateInfo?> check() async {
    final current = BuildInfo.version;
    if (current == 'dev' || current.isEmpty) return null;
    if (_base.isEmpty) return null;

    final client = HttpClient();
    try {
      final req = await client.getUrl(Uri.parse('$_base/download/version'));
      final resp = await req.close().timeout(const Duration(seconds: 10));
      if (resp.statusCode != 200) return null;
      final body = await resp.transform(utf8.decoder).join();
      final json = jsonDecode(body) as Map<String, dynamic>;

      final latest = json['version'] as String?;
      final hasAsset = json['download_url'] != null;
      if (latest == null || !hasAsset) return null;
      if (compareVersions(latest, current) <= 0) return null;

      return UpdateInfo(
        version: latest,
        downloadUrl: '$_base/download',
        sizeBytes: (json['size_bytes'] as num?)?.toInt(),
      );
    } catch (_) {
      return null;
    } finally {
      client.close();
    }
  }

  /// Downloads the APK to a temp file; returns the saved file path.
  static Future<String> download(
    String url, {
    void Function(double progress)? onProgress,
  }) async {
    final client = HttpClient();
    try {
      final req = await client.getUrl(Uri.parse(url));
      final resp = await req.close();
      if (resp.statusCode != 200) {
        throw Exception('Download failed (${resp.statusCode})');
      }
      final total = resp.contentLength;
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/temawest-update.apk');
      final sink = file.openWrite();
      var received = 0;
      await for (final chunk in resp) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) onProgress?.call(received / total);
      }
      await sink.flush();
      await sink.close();
      return file.path;
    } finally {
      client.close();
    }
  }

  /// Opens the APK at [path] in the system installer. The user confirms.
  static Future<void> install(String path) async {
    final result = await OpenFilex.open(
      path,
      type: 'application/vnd.android.package-archive',
    );
    if (result.type != ResultType.done) {
      throw Exception('Could not open installer: ${result.message}');
    }
  }

  /// Numeric dotted-version comparison. Returns >0 if [a] > [b].
  static int compareVersions(String a, String b) {
    final pa = a.split('.').map((x) => int.tryParse(x) ?? 0).toList();
    final pb = b.split('.').map((x) => int.tryParse(x) ?? 0).toList();
    final n = pa.length > pb.length ? pa.length : pb.length;
    for (var i = 0; i < n; i++) {
      final ai = i < pa.length ? pa[i] : 0;
      final bi = i < pb.length ? pb[i] : 0;
      if (ai != bi) return ai - bi;
    }
    return 0;
  }
}
