import 'dart:convert';

import 'package:crypto/crypto.dart';

class BrowserInfo {
  static Future<Map<String, dynamic>> getBrowserInfo() async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    var browserInfo = 'unknown_browser';

    // Generate a consistent device ID for web
    final deviceId =
        sha256.convert(utf8.encode('web_${browserInfo}_$timestamp')).toString();

    return {
      'device_id': deviceId,
      'platform': 'web',
      'model': 'browser',
      'brand': browserInfo,
    };
  }
}
