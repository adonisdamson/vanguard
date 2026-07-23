import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:http/http.dart' as http;

/// An [ImageProvider] that fetches image bytes with custom headers via `http`,
/// then decodes them. Unlike `Image.network` / `CachedNetworkImage`, this works
/// on **web** too, because the browser `<img>` element can't send an
/// `Authorization` header — we fetch the bytes ourselves and decode them.
///
/// Flutter's global `ImageCache` de-dupes by the [url] key, so repeat loads of
/// the same photo are cheap.
@immutable
class AuthedNetworkImage extends ImageProvider<AuthedNetworkImage> {
  final String url;
  final Map<String, String> headers;

  const AuthedNetworkImage(this.url, this.headers);

  @override
  Future<AuthedNetworkImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture<AuthedNetworkImage>(this);

  @override
  ImageStreamCompleter loadImage(
      AuthedNetworkImage key, ImageDecoderCallback decode) {
    return MultiFrameImageStreamCompleter(
      codec: _fetch(decode),
      scale: 1.0,
      debugLabel: url,
    );
  }

  Future<ui.Codec> _fetch(ImageDecoderCallback decode) async {
    final resp = await http.get(Uri.parse(url), headers: headers);
    if (resp.statusCode != 200 || resp.bodyBytes.isEmpty) {
      throw Exception('Image load failed (${resp.statusCode})');
    }
    final buffer = await ui.ImmutableBuffer.fromUint8List(resp.bodyBytes);
    return decode(buffer);
  }

  @override
  bool operator ==(Object other) =>
      other is AuthedNetworkImage && other.url == url;

  @override
  int get hashCode => url.hashCode;
}
