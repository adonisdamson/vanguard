import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Member photos live in a private Cloudflare R2 bucket, reached only through
/// the authenticated Worker endpoints (never a public URL). Uploads POST the
/// raw bytes to `/api/photos/upload`; reads load `/api/photos/view` with an
/// Authorization header. Object keys keep the historical `{uid}/...` format,
/// so `photo_path` / `avatar_path` values are unchanged.
class PhotoService {
  static String get _base =>
      dotenv.env['API_BASE_URL'] ?? dotenv.env['RAILWAY_API_URL'] ?? '';

  static String? get _token =>
      Supabase.instance.client.auth.currentSession?.accessToken;

  /// Uploads [bytes] under [key] (must be `{uid}/...`). Returns the stored key.
  static Future<String> upload({
    required String key,
    required Uint8List bytes,
    required String contentType,
  }) async {
    final token = _token;
    if (token == null) throw Exception('Not authenticated');

    final uri = Uri.parse(
        '$_base/api/photos/upload?key=${Uri.encodeQueryComponent(key)}');
    final client = HttpClient();
    try {
      final req = await client.postUrl(uri);
      req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      req.headers.set(HttpHeaders.contentTypeHeader, contentType);
      req.add(bytes);
      final resp = await req.close().timeout(const Duration(seconds: 30));
      final body = await resp.transform(utf8.decoder).join();
      if (resp.statusCode != 200) {
        throw Exception('Photo upload failed (${resp.statusCode}): $body');
      }
      return (jsonDecode(body) as Map<String, dynamic>)['key'] as String;
    } finally {
      client.close();
    }
  }

  /// The authenticated view URL for [key]. Load with [authHeaders].
  static String viewUrl(String key) =>
      '$_base/api/photos/view?key=${Uri.encodeQueryComponent(key)}';

  /// Bearer header for image loaders (cached_network_image `httpHeaders`).
  static Map<String, String> authHeaders() {
    final token = _token;
    return token == null ? const {} : {'Authorization': 'Bearer $token'};
  }
}
