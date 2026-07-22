import 'dart:typed_data';

import 'file_saver_io.dart' if (dart.library.html) 'file_saver_web.dart'
    as impl;

/// Save (or share) [bytes] as a file, cross-platform.
///
/// - Mobile: writes to a temp file and opens the OS share sheet so the user can
///   save/send it (the app's private dir is invisible to them).
/// - Web: triggers a normal browser download of the file.
Future<void> saveOrShareBytes(
  Uint8List bytes, {
  required String filename,
  required String mime,
  String? subject,
  String? text,
}) {
  return impl.saveOrShareBytes(
    bytes,
    filename: filename,
    mime: mime,
    subject: subject,
    text: text,
  );
}
