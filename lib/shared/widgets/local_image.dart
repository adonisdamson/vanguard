import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/material.dart';

/// Cross-platform preview of a just-picked local image.
///
/// image_picker gives a file path on mobile and a blob URL on web; `XFile`
/// abstracts both and reads bytes without touching `dart:io`, so this renders
/// the picked photo identically on every platform (via `Image.memory`).
class LocalImage extends StatelessWidget {
  final String path;
  final double? width;
  final double? height;
  final BoxFit fit;
  final WidgetBuilder? placeholder;

  const LocalImage({
    super.key,
    required this.path,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: XFile(path).readAsBytes(),
      builder: (context, snap) {
        if (snap.hasData) {
          return Image.memory(
            snap.data!,
            width: width,
            height: height,
            fit: fit,
            gaplessPlayback: true,
          );
        }
        return placeholder?.call(context) ??
            SizedBox(width: width, height: height);
      },
    );
  }
}
