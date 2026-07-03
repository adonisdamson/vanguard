import 'dart:convert';
import 'dart:io';
import 'package:hive_flutter/hive_flutter.dart';
import '../data/member_repository.dart';
import '../data/capture_metadata_service.dart';

const _boxName = 'offline_registrations';

class OfflineRegistration {
  final Map<String, dynamic> insertData;
  final String? photoLocalPath;
  final String registeredBy;
  final String enqueuedAt;

  const OfflineRegistration({
    required this.insertData,
    required this.photoLocalPath,
    required this.registeredBy,
    required this.enqueuedAt,
  });

  Map<String, dynamic> toJson() => {
        'insertData': insertData,
        'photoLocalPath': photoLocalPath,
        'registeredBy': registeredBy,
        'enqueuedAt': enqueuedAt,
      };

  factory OfflineRegistration.fromJson(Map<String, dynamic> json) =>
      OfflineRegistration(
        insertData: Map<String, dynamic>.from(json['insertData'] as Map),
        photoLocalPath: json['photoLocalPath'] as String?,
        registeredBy: json['registeredBy'] as String,
        enqueuedAt: json['enqueuedAt'] as String,
      );
}

class OfflineQueue {
  static Box<String> get _box => Hive.box<String>(_boxName);

  static bool get hasItems => _box.isNotEmpty;
  static int get count => _box.length;

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
      final raw = _box.get(key);
      if (raw == null) continue;

      try {
        final reg = OfflineRegistration.fromJson(
          jsonDecode(raw) as Map<String, dynamic>,
        );

        // Try to upload photo if local file still exists
        String? storagePath;
        if (reg.photoLocalPath != null && File(reg.photoLocalPath!).existsSync()) {
          try {
            storagePath = await repo.uploadPhoto(reg.photoLocalPath!, reg.registeredBy);
          } catch (_) {
            // Photo upload failed — proceed without photo
          }
        }

        final data = Map<String, dynamic>.from(reg.insertData);
        if (storagePath != null) data['photo_path'] = storagePath;

        final result = await repo.insertMember(data);
        final memberId = result['id']!;

        // Fire and forget capture-metadata
        CaptureMetadataService.capture(memberId).ignore();

        keysToDelete.add(key);
        synced++;
      } catch (_) {
        // Keep in queue for next attempt
      }
    }

    for (final key in keysToDelete) {
      await _box.delete(key);
    }

    return synced;
  }
}
