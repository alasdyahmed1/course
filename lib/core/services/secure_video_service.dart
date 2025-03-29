import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:convert';
import 'supabase_service.dart'; // استيراد الخدمة المركزية

class SecureVideoService {
  static const _storage = FlutterSecureStorage(); // تصحيح التعريف
  static final _supabase = SupabaseService.supabase; // استخدام المثيل المركزي
  
  /// تحميل الفيديو بشكل آمن
  static Future<String> downloadAndEncrypt({
    required String videoUrl,
    required String videoId,
    required String userId,
  }) async {
    try {
      // 1. إنشاء مسار آمن للتخزين
      final directory = await getApplicationDocumentsDirectory();
      final encryptedPath = '${directory.path}/secured_videos';
      await Directory(encryptedPath).create(recursive: true);

      // 2. إنشاء مفتاح تشفير فريد
      final key = base64.encode(
        List<int>.generate(32, (_) => DateTime.now().millisecondsSinceEpoch % 256)
      );

      // 3. تحميل وتشفير الفيديو
      final encryptedFile = File('$encryptedPath/$videoId.enc');
      // ... تنفيذ التحميل والتشفير

      // 4. حفظ المعلومات في قاعدة البيانات
      await _supabase.from('downloaded_videos').upsert({
        'user_id': userId,
        'video_id': videoId,
        'local_path': encryptedFile.path,
        'encryption_key': key,
      });

      return encryptedFile.path;
    } catch (e) {
      rethrow;
    }
  }

  /// تشغيل الفيديو المحمل
  static Future<String> getSecureVideoPath(String videoId) async {
    try {
      // التحقق من صلاحية النسخة المحملة
      final result = await _supabase
          .from('downloaded_videos')
          .select()
          .eq('video_id', videoId)
          .single();

      if (!result['is_valid']) {
        throw Exception('الفيديو غير متوفر. يرجى إعادة التحميل');
      }

      // تحديث وقت آخر مشاهدة
      await _supabase
          .from('downloaded_videos')
          .update({ 'last_watched': DateTime.now().toIso8601String() })
          .eq('video_id', videoId);

      return result['local_path'];
    } catch (e) {
      rethrow;
    }
  }

  /// الحصول على توكن الفيديو المشفر
  static Future<String> getVideoToken(String videoId) async {
    try {
      final result = await _supabase
          .from('downloaded_videos')
          .select('encryption_key')
          .eq('video_id', videoId)
          .single();
      
      return result['encryption_key'] as String;
    } catch (e) {
      throw Exception('فشل في الحصول على توكن الفيديو');
    }
  }
}
