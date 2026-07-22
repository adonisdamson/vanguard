import 'dart:typed_data';
import 'package:flutter/widgets.dart';
import 'package:image_picker/image_picker.dart';

/// Mobile/desktop: camera source only (never gallery) — returns JPEG bytes.
Future<Uint8List?> captureSelfie(BuildContext context) async {
  final img = await ImagePicker().pickImage(
    source: ImageSource.camera,
    preferredCameraDevice: CameraDevice.front,
    maxWidth: 900,
    imageQuality: 82,
  );
  if (img == null) return null;
  return img.readAsBytes();
}
