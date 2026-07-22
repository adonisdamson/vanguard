import 'dart:convert';
import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CaptureMetadataService {
  static Future<void> capture(String memberId, {double? lat, double? lng}) async {
    final token = Supabase.instance.client.auth.currentSession?.accessToken;
    if (token == null) return;

    final baseUrl =
        dotenv.env['API_BASE_URL'] ?? dotenv.env['RAILWAY_API_URL'] ?? '';
    final uri = Uri.parse('$baseUrl/api/members/$memberId/capture-metadata');

    final client = HttpClient();
    try {
      final request = await client.postUrl(uri);
      request.headers.set('Authorization', 'Bearer $token');
      request.headers.set('Content-Type', 'application/json');
      request.write(jsonEncode({'lat': lat, 'lng': lng}));
      final response = await request.close().timeout(const Duration(seconds: 15));
      await response.drain<void>();
    } catch (_) {
      // Non-fatal — member row exists, metadata capture is best-effort
    } finally {
      client.close();
    }
  }

  static Future<Position?> requestLocation() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        final requested = await Geolocator.requestPermission();
        if (requested == LocationPermission.denied ||
            requested == LocationPermission.deniedForever) {
          return null;
        }
      }
      if (permission == LocationPermission.deniedForever) return null;
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
      ).timeout(const Duration(seconds: 10));
    } catch (_) {
      return null;
    }
  }
}
