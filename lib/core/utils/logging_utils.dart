import 'dart:collection';

import 'package:flutter/foundation.dart';

/// مساعد لتسجيل رسائل التشخيص والمعلومات بشكل منظم
class LoggingUtils {
  // قائمة لتتبع عدد مرات طباعة نفس الرسالة
  static final HashMap<String, int> _logCounts = HashMap<String, int>();
  static const int _maxRepeatCount = 5; // الحد الأقصى لتكرار نفس الرسالة

  // متغير للتحكم في تفعيل التسجيل التشخيصي
  static bool _debugLoggingEnabled = true;

  /// تكوين نظام تسجيل الرسائل التشخيصية
  static void configureLogging({bool enableDebugLogs = !kReleaseMode}) {
    _debugLoggingEnabled = enableDebugLogs;

    // تخصيص سلوك طباعة الاستثناءات
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      debugLog('❌ استثناء غير معالج: ${details.exception}');
      debugLog('🔍 تفاصيل: ${details.summary}');
    };
  }

  /// طباعة رسالة تشخيصية مع التحكم في التكرار
  static void debugLog(String message) {
    if (!_debugLoggingEnabled) return;

    // تنظيف المحتوى الزائد لتحسين المقارنة
    final cleanMessage = message.trim();

    // تجاهل الرسائل الفارغة
    if (cleanMessage.isEmpty) return;

    final logCount = (_logCounts[cleanMessage] ?? 0) + 1;
    _logCounts[cleanMessage] = logCount;

    if (logCount <= _maxRepeatCount) {
      debugPrint(cleanMessage);
    } else if (logCount == _maxRepeatCount + 1) {
      debugPrint(
          '⚠️ رسالة "$cleanMessage" تكررت أكثر من $_maxRepeatCount مرات، سيتم تجاهلها');
    }
    // تجاهل الرسائل المتكررة بعد الحد الأقصى
  }

  /// إعادة تعيين عدادات تكرار الرسائل
  static void resetLogCounters() {
    _logCounts.clear();
  }

  /// تسجيل بداية عملية مع تتبع الوقت
  static Stopwatch startOperation(String operationName) {
    final stopwatch = Stopwatch()..start();
    debugLog('⏱️ بدء العملية: $operationName');
    return stopwatch;
  }

  /// تسجيل انتهاء عملية مع الوقت المستغرق
  static void endOperation(String operationName, Stopwatch stopwatch) {
    stopwatch.stop();
    final duration = stopwatch.elapsedMilliseconds;
    debugLog('✅ انتهت العملية: $operationName في $duration مللي ثانية');
  }
}
