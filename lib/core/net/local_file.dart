// Cross-platform "does this local file path exist?" — resolves to the dart:io
// implementation on mobile/desktop and a web stub (always false) on web, where
// image_picker returns transient blob URLs that don't persist.
export 'local_file_io.dart' if (dart.library.html) 'local_file_web.dart';
