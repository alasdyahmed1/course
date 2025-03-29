import 'package:flutter/foundation.dart' show kIsWeb;

import 'platform_io.dart' if (dart.library.html) 'platform_web.dart';

class PlatformHelper {
  static bool get isDesktopOS {
    if (kIsWeb) return false;
    try {
      return PlatformWrapper.isWindows ||
          PlatformWrapper.isMacOS ||
          PlatformWrapper.isLinux;
    } catch (_) {
      return false;
    }
  }

  static bool get isWindows {
    if (kIsWeb) return false;
    try {
      return PlatformWrapper.isWindows;
    } catch (_) {
      return false;
    }
  }
}
