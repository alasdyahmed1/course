import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

/// تنفيذ مبسط لتهيئة منصة WebView
class WebViewPlatformImplementation {
  /// تهيئة منصة WebView بناءً على النظام الحالي
  static void initializeWebView() {
    if (kIsWeb) {
      debugPrint('WebView غير مدعوم على منصة الويب');
      return;
    }

    try {
      // في الإصدارات الحديثة من webview_flutter، PlatformWebViewControllerFactory غير مطلوب
      if (Platform.isAndroid) {
        // طريقة التهيئة الصحيحة للإصدار الجديد
        WebViewPlatform.instance = AndroidWebViewPlatform();

        // تمكين تصحيح الأخطاء لـ Android WebView
        // هذا مثال على استخدام ميزة خاصة بـ Android
        if (WebViewPlatform.instance is AndroidWebViewPlatform) {
          AndroidWebViewController.enableDebugging(true);
        }

        debugPrint('✅ تم تهيئة منصة Android WebView بنجاح');
      } else if (Platform.isIOS) {
        // طريقة التهيئة الصحيحة للإصدار الجديد
        WebViewPlatform.instance = WebKitWebViewPlatform();

        debugPrint('✅ تم تهيئة منصة iOS WebView بنجاح');
      } else {
        debugPrint(
            '⚠️ WebView غير مدعوم على هذه المنصة: ${Platform.operatingSystem}');
      }
    } catch (e) {
      debugPrint('⚠️ خطأ في تهيئة WebView: $e');
    }
  }
}
