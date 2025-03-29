import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

/// خدمة للتعامل مع Bunny Storage API
class BunnyStorageService {
  // استيراد المعلومات من ملف البيئة
  static final String _storageZone = dotenv.env['BUNNY_STORAGE_ZONE'] ?? '';
  static final String _storagePassword =
      dotenv.env['BUNNY_STORAGE_PASSWORD'] ?? '';
  static final String _storageUsername =
      dotenv.env['BUNNY_STORAGE_USERNAME'] ?? '';
  static final String _storageHostname =
      dotenv.env['BUNNY_STORAGE_HOSTNAME'] ?? 'storage.bunnycdn.com';
  // IMPORTANTE: Pull Zone URL debe ser la URL pública correcta para usar en imágenes
  static final String _pullZoneUrl =
      dotenv.env['BUNNY_PULLZONE_URL'] ?? 'https://myzoneit32.b-cdn.net';

  /// رفع ملف إلى Bunny Storage
  static Future<String?> uploadFile(File file, String remotePath,
      {String? contentType}) async {
    try {
      final uri =
          Uri.parse('https://$_storageHostname/$_storageZone/$remotePath');

      // قراءة بيانات الملف
      final bytes = await file.readAsBytes();

      // إنشاء طلب PUT
      final request = http.Request('PUT', uri);
      request.headers['AccessKey'] = _storagePassword;
      request.headers['Content-Length'] = bytes.length.toString();

      // تعيين نوع المحتوى إذا تم تمريره
      if (contentType != null) {
        request.headers['Content-Type'] = contentType;
      }

      request.bodyBytes = bytes;

      // إرسال الطلب
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        // تم الرفع بنجاح
        return remotePath;
      } else {
        debugPrint(
            'فشل رفع الملف إلى Bunny.net: ${response.statusCode}: ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('خطأ في رفع الملف إلى Bunny.net: $e');
      return null;
    }
  }

  /// الحصول على رابط عام للملف المخزن
  static String getPublicUrl(String remotePath) {
    // تأكد من وجود رابط قاعدة صحيح
    String url = _pullZoneUrl;
    if (!url.endsWith('/')) url += '/';

    // تنظيف المسار وإزالة أي أشرطة متكررة
    String cleanPath = remotePath.trim();

    // إزالة الشرطة الأمامية إذا وجدت لتجنب الشرطة المزدوجة
    if (cleanPath.startsWith('/')) {
      cleanPath = cleanPath.substring(1);
    }

    // تحقق مما إذا كان المسار يحتوي بالفعل على 'courses_photo'
    if (cleanPath.startsWith('courses_photo/')) {
      // المسار يحتوي بالفعل على مجلد الصور، استخدمه كما هو
    } else if (cleanPath.contains('/courses_photo/')) {
      // إذا كان المسار يحتوي على مسار كامل، استخرج الجزء بعد courses_photo
      final coursesPhotoIndex = cleanPath.indexOf('/courses_photo/');
      cleanPath = cleanPath.substring(coursesPhotoIndex + 1);
    }

    // عندما تكون الصورة مخزنة في قاعدة البيانات كـ /courses_photo/XXX.jpg
    // يتم إضافة شرطة مائلة في البداية، مما يؤدي إلى مشكلة
    if (cleanPath.startsWith('/')) {
      cleanPath = cleanPath.substring(1);
    }

    // أخيراً، تأكد من عدم وجود مسارات متكررة
    final fullUrl = '$url$cleanPath';

    debugPrint('BunnyStorage - URL صحيح: $fullUrl');
    return fullUrl;
  }

  /// تحويل رابط التخزين إلى رابط العرض العام
  static String convertStorageUrlToCdnUrl(String storageUrl) {
    if (storageUrl.isEmpty) return '';

    // تحليل الرابط بدقة، مع الحفاظ على البروتوكول
    String normalizedUrl = storageUrl;

    // فصل البروتوكول (https:// أو http://) عن باقي الرابط
    final protocolMatch = RegExp(r'^(https?:\/\/)').firstMatch(normalizedUrl);
    final protocol =
        protocolMatch != null ? (protocolMatch.group(0) ?? '') : '';

    // إذا وجدنا بروتوكول، نقوم بمعالجة الرابط
    if (protocol.isNotEmpty) {
      // نحذف البروتوكول من النص
      normalizedUrl = normalizedUrl.substring(protocol.length);
    }

    // إذا كان الرابط يبدأ بشرطة مائلة، قم بإزالتها
    if (normalizedUrl.startsWith('/')) {
      normalizedUrl = normalizedUrl.substring(1);
    }

    // إذا كان الرابط يحتوي على cdn بالفعل، أعده كما هو
    if (protocol.isNotEmpty && normalizedUrl.contains('b-cdn.net')) {
      return '$protocol$normalizedUrl';
    }

    // إذا كان الرابط يحتوي على storage.bunnycdn.com
    if (normalizedUrl.contains('storage.bunnycdn.com')) {
      try {
        // تحليل الرابط على النحو الصحيح مع مراعاة البروتوكول
        final uri = Uri.parse('$protocol$normalizedUrl');
        final pathSegments = uri.pathSegments;

        if (pathSegments.length > 1) {
          // استخرج المسار بدون اسم المنطقة التخزينية
          final relativePath = pathSegments.sublist(1).join('/');
          return getPublicUrl(relativePath);
        }
      } catch (e) {
        debugPrint('خطأ في تحويل رابط التخزين: $e');
      }
    }

    // في حالة المسار النسبي
    return getPublicUrl(normalizedUrl);
  }

  /// حذف ملف من Bunny Storage
  static Future<bool> deleteFile(String remotePath) async {
    try {
      // تنظيف المسار قبل الاستخدام
      String cleanPath = remotePath.trim();
      
      // Registrar el intento de eliminación para depuración
      debugPrint('🗑️ محاولة حذف ملف من Bunny Storage: $cleanPath');
      
      // إذا كان المسار لا يبدأ بـ courses_photo، نضيف المجلد
      if (!cleanPath.startsWith('courses_photo/')) {
        cleanPath = 'courses_photo/$cleanPath';
        debugPrint('🔄 تصحيح المسار للحذف: $cleanPath');
      }
      
      // تأكد من عدم وجود '/' في بداية المسار 
      if (cleanPath.startsWith('/')) {
        cleanPath = cleanPath.substring(1);
        debugPrint('🔄 إزالة الشرطة من بداية المسار: $cleanPath');
      }
      
      final uri = Uri.parse('https://$_storageHostname/$_storageZone/$cleanPath');
      debugPrint('🌐 محاولة الحذف من العنوان: $uri');

      final response = await http.delete(
        uri,
        headers: {'AccessKey': _storagePassword},
      );
      
      final success = response.statusCode >= 200 && response.statusCode < 300;
      
      if (success) {
        debugPrint('✅ تم حذف الملف بنجاح! رمز الاستجابة: ${response.statusCode}');
      } else {
        debugPrint('❌ فشل حذف الملف! رمز الاستجابة: ${response.statusCode}, الرد: ${response.body}');
      }
      
      return success;
    } catch (e) {
      debugPrint('❌ خطأ استثنائي في حذف الملف من Bunny.net: $e');
      return false;
    }
  }

  /// التحقق من وجود ملف
  static Future<bool> fileExists(String remotePath) async {
    try {
      final uri =
          Uri.parse('https://$_storageHostname/$_storageZone/$remotePath');
      final response = await http.head(
        uri,
        headers: {'AccessKey': _storagePassword},
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('خطأ في التحقق من وجود الملف: $e');
      return false;
    }
  }
}
