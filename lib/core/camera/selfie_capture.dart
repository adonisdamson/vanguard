import 'dart:typed_data';
import 'package:flutter/widgets.dart';

import 'selfie_capture_io.dart'
    if (dart.library.html) 'selfie_capture_web.dart' as impl;

/// Capture a **live selfie** (front camera) cross-platform and return the JPEG
/// bytes, or null if cancelled.
///
/// - Mobile/desktop: opens the device camera via image_picker (camera source
///   only — never the gallery).
/// - Web: opens a live getUserMedia camera sheet with a Capture button, so the
///   user can't upload an existing photo from disk.
Future<Uint8List?> captureSelfie(BuildContext context) =>
    impl.captureSelfie(context);
