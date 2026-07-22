// Cross-platform facade. Mobile/desktop gets the real APK updater; web gets a
// no-op stub (the browser always loads the latest deploy). `UpdateInfo` is the
// shared data type either implementation returns.
export 'update_info.dart';
export 'update_service_io.dart'
    if (dart.library.html) 'update_service_web.dart';
