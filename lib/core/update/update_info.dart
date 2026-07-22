/// Details of a newer release than the one currently installed.
class UpdateInfo {
  final String version; // e.g. "1.0.86"
  final String downloadUrl; // our Worker /download (streams via Cloudflare)
  final int? sizeBytes;

  const UpdateInfo({
    required this.version,
    required this.downloadUrl,
    this.sizeBytes,
  });

  String get sizeLabel {
    if (sizeBytes == null) return '';
    final mb = sizeBytes! / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} MB';
  }
}
