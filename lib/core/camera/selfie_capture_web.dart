import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import '../../shared/theme/app_colors.dart';

/// Web: live front-camera capture via getUserMedia. The user sees a mirrored
/// video feed and a Capture button — there is no file/gallery option, so a
/// selfie is enforced. Returns JPEG bytes or null if cancelled/denied.
Future<Uint8List?> captureSelfie(BuildContext context) {
  return showDialog<Uint8List?>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _WebSelfieDialog(),
  );
}

class _WebSelfieDialog extends StatefulWidget {
  const _WebSelfieDialog();
  @override
  State<_WebSelfieDialog> createState() => _WebSelfieDialogState();
}

class _WebSelfieDialogState extends State<_WebSelfieDialog> {
  final String _viewType =
      'selfie-cam-${DateTime.now().microsecondsSinceEpoch}';
  web.HTMLVideoElement? _video;
  web.MediaStream? _stream;
  bool _ready = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    try {
      final v = web.HTMLVideoElement()
        ..autoplay = true
        ..muted = true
        ..setAttribute('playsinline', 'true')
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.objectFit = 'cover'
        ..style.transform = 'scaleX(-1)'; // mirror the preview only

      final constraints = web.MediaStreamConstraints(
        video: web.MediaTrackConstraints(facingMode: 'user'.toJS) as JSAny,
        audio: false.toJS,
      );
      final stream = await web.window.navigator.mediaDevices
          .getUserMedia(constraints)
          .toDart;
      v.srcObject = stream;

      ui_web.platformViewRegistry
          .registerViewFactory(_viewType, (int id) => v);

      _video = v;
      _stream = stream;
      if (mounted) setState(() => _ready = true);
    } catch (_) {
      if (mounted) {
        setState(() =>
            _error = 'Camera unavailable. Allow camera access and try again.');
      }
    }
  }

  void _stopStream() {
    final s = _stream;
    if (s == null) return;
    final tracks = s.getTracks().toDart;
    for (final t in tracks) {
      t.stop();
    }
    _stream = null;
  }

  Future<void> _capture() async {
    final v = _video;
    if (v == null) return;
    final w = v.videoWidth;
    final h = v.videoHeight;
    if (w == 0 || h == 0) return;
    final canvas = web.HTMLCanvasElement()
      ..width = w
      ..height = h;
    final ctx = canvas.getContext('2d') as web.CanvasRenderingContext2D;
    ctx.drawImage(v, 0, 0);
    final dataUrl = canvas.toDataURL('image/jpeg', 0.82.toJS);
    final b64 = dataUrl.substring(dataUrl.indexOf(',') + 1);
    final bytes = base64Decode(b64);
    _stopStream();
    if (mounted) Navigator.of(context).pop(bytes);
  }

  @override
  void dispose() {
    _stopStream();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.ink,
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AspectRatio(
                aspectRatio: 3 / 4,
                child: _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(_error!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white70)),
                        ),
                      )
                    : _ready
                        ? HtmlElementView(viewType: _viewType)
                        : const Center(
                            child: CircularProgressIndicator(
                                color: AppColors.canopyGreen)),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () {
                          _stopStream();
                          Navigator.of(context).pop(null);
                        },
                        child: const Text('Cancel',
                            style: TextStyle(color: Colors.white70)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                            backgroundColor: AppColors.canopyGreen),
                        onPressed: (_ready && _error == null) ? _capture : null,
                        icon: const Icon(Icons.camera_alt, size: 18),
                        label: const Text('Capture'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
