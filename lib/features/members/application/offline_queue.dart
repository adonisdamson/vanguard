import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../data/member_repository.dart';
import '../data/capture_metadata_service.dart';
import '../../../core/net/local_file.dart';

const _boxName = 'offline_registrations';
const _keyName = 'offline_queue_key_v1';

// A queued item that keeps failing is surfaced (not retried forever) once it
// crosses this many attempts. Registrations older than the max age are dropped
// so member PII never lingers on the device indefinitely.
const _maxAttempts = 5;
const _maxAgeDays = 14;

class OfflineRegistration {
  final Map<String, dynamic> insertData;
  final String? photoLocalPath;
  final String registeredBy;
  final String enqueuedAt;
  final int attempts;
  final String? lastError;

  const OfflineRegistration({
    required this.insertData,
    required this.photoLocalPath,
    required this.registeredBy,
    required this.enqueuedAt,
    this.attempts = 0,
    this.lastError,
  });

  Map<String, dynamic> toJson() => {
        'insertData': insertData,
        'photoLocalPath': photoLocalPath,
        'registeredBy': registeredBy,
        'enqueuedAt': enqueuedAt,
        'attempts': attempts,
        'lastError': lastError,
      };

  factory OfflineRegistration.fromJson(Map<String, dynamic> json) =>
      OfflineRegistration(
        insertData: Map<String, dynamic>.from(json['insertData'] as Map),
        photoLocalPath: json['photoLocalPath'] as String?,
        registeredBy: json['registeredBy'] as String,
        enqueuedAt: json['enqueuedAt'] as String,
        attempts: json['attempts'] as int? ?? 0,
        lastError: json['lastError'] as String?,
      );

  OfflineRegistration _withFailure(String error) => OfflineRegistration(
        insertData: insertData,
        photoLocalPath: photoLocalPath,
        registeredBy: registeredBy,
        enqueuedAt: enqueuedAt,
        attempts: attempts + 1,
        lastError: error,
      );

  DateTime get enqueuedTime =>
      DateTime.tryParse(enqueuedAt) ?? DateTime.now();

  bool get isExpired =>
      DateTime.now().difference(enqueuedTime).inDays >= _maxAgeDays;

  // Repeatedly failed — needs the operator's attention rather than silent retry.
  bool get isStuck => attempts >= _maxAttempts;
}

/// Offline registration queue. Backed by an AES-encrypted Hive box (the key
/// lives in the platform keystore via flutter_secure_storage) so member PII is
/// never written to disk in the clear.
class OfflineQueue {
  static const _secure = FlutterSecureStorage();

  /// Opens the encrypted box. Call once at startup before any queue access.
  static Future<void> init() async {
    final key = await _encryptionKey();
    final cipher = HiveAesCipher(key);
    try {
      await Hive.openBox<String>(_boxName, encryptionCipher: cipher);
    } catch (_) {
      // A pre-existing plaintext box (or a lost key) can't be read under a
      // cipher. Discard it and recreate encrypted — un-synced items are lost,
      // which is the right trade against leaving cleartext PII on disk.
      await Hive.deleteBoxFromDisk(_boxName);
      await Hive.openBox<String>(_boxName, encryptionCipher: cipher);
    }
  }

  static Future<List<int>> _encryptionKey() async {
    final existing = await _secure.read(key: _keyName);
    if (existing != null) return base64Decode(existing);
    final key = Hive.generateSecureKey();
    await _secure.write(key: _keyName, value: base64Encode(key));
    return key;
  }

  static Box<String> get _box => Hive.box<String>(_boxName);

  static bool get hasItems => _box.isNotEmpty;
  static int get count => _box.length;

  /// Items that have repeatedly failed to sync — surfaced in the UI.
  static int get stuckCount {
    var n = 0;
    for (final key in _box.keys) {
      final reg = _decode(_box.get(key));
      if (reg != null && reg.isStuck) n++;
    }
    return n;
  }

  static OfflineRegistration? _decode(String? raw) {
    if (raw == null) return null;
    try {
      return OfflineRegistration.fromJson(
          jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  static Future<void> enqueue(OfflineRegistration reg) async {
    await _box.add(jsonEncode(reg.toJson()));
  }

  // Attempt to flush the queue. Returns number of successfully synced items.
  static Future<int> flush() async {
    if (_box.isEmpty) return 0;
    final repo = MemberRepository();
    int synced = 0;
    final keysToDelete = <dynamic>[];

    for (final key in _box.keys.toList()) {
      final reg = _decode(_box.get(key));
      if (reg == null) {
        keysToDelete.add(key); // undecodable — drop it
        continue;
      }

      // Expired: stop holding member PII on device past the retention window.
      if (reg.isExpired) {
        keysToDelete.add(key);
        continue;
      }

      try {
        String? storagePath;
        if (reg.photoLocalPath != null &&
            localFileExists(reg.photoLocalPath!)) {
          try {
            storagePath =
                await repo.uploadPhoto(reg.photoLocalPath!, reg.registeredBy);
          } catch (_) {
            // Photo upload failed — proceed without photo
          }
        }

        final data = Map<String, dynamic>.from(reg.insertData);
        if (storagePath != null) data['photo_path'] = storagePath;

        final result = await repo.insertMember(data);
        final memberId = result['id']!;
        CaptureMetadataService.capture(memberId).ignore();

        keysToDelete.add(key);
        synced++;
      } catch (e) {
        // Record the failure instead of swallowing it, so the item can be
        // surfaced as "needs attention" after repeated attempts.
        await _box.put(
            key, jsonEncode(reg._withFailure(e.toString()).toJson()));
      }
    }

    for (final key in keysToDelete) {
      await _box.delete(key);
    }

    return synced;
  }
}
