import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Mobile/desktop: write to a temp file and open the OS share sheet.
Future<void> saveOrShareBytes(
  Uint8List bytes, {
  required String filename,
  required String mime,
  String? subject,
  String? text,
}) async {
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$filename');
  await file.writeAsBytes(bytes);
  await SharePlus.instance.share(ShareParams(
    files: [XFile(file.path, mimeType: mime)],
    subject: subject,
    text: text,
  ));
}
