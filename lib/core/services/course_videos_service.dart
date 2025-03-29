import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;

import '../../models/course_section.dart';
import '../../models/course_video.dart';
import 'supabase_service.dart';

class CourseVideosService {
  static final _supabase = SupabaseService.supabase;

  // Configuración de Bunny.net Stream (Video)
  static final String? _bunnyStreamApiKey = dotenv.env['BUNNY_API_KEY'];
  static final String? _bunnyLibraryId = dotenv.env['BUNNY_LIBRARY_ID'];
  static final String? _bunnyStreamHostname =
      dotenv.env['BUNNY_STREAM_HOSTNAME'];
  static final String? _bunnyPullZone = dotenv.env['BUNNY_PULL_ZONE'];

  // Configuración de Bunny.net Storage
  static final String? _bunnyStorageZone = dotenv.env['BUNNY_STORAGE_ZONE'];
  static final String? _bunnyStorageZoneId =
      dotenv.env['BUNNY_STORAGE_ZONE_ID'];
  static final String? _bunnyStoragePassword =
      dotenv.env['BUNNY_STORAGE_PASSWORD'];
  static final String? _bunnyStorageHostname =
      dotenv.env['BUNNY_STORAGE_HOSTNAME'];
  static final String? _bunnyCdnDomain =
      dotenv.env['BUNNY_CDN_DOMAIN']; // إضافة نطاق CDN

  // Obtener los videos de un curso
  static Future<List<CourseVideo>> getCourseVideos(String courseId) async {
    try {
      final response = await _supabase.from('course_videos').select('''
            *,
            attachments:course_files(*)
          ''').eq('course_id', courseId).order('order_number', ascending: true);
      return (response as List)
          .map((data) => CourseVideo.fromJson(data))
          .toList();
    } catch (e) {
      debugPrint('Error fetching course videos: $e');
      throw Exception('فشل في تحميل الفيديوهات: $e');
    }
  }

  // Add new method to get course sections
  static Future<List<CourseSection>> getCourseSections(String courseId) async {
    try {
      final response = await _supabase
          .from('course_sections')
          .select('*')
          .eq('course_id', courseId)
          .order('order_number');
      return (response as List)
          .map((data) => CourseSection.fromJson(data))
          .toList();
    } catch (e) {
      debugPrint('Error fetching course sections: $e');
      throw Exception('فشل في تحميل أقسام الكورس: $e');
    }
  }

  // Add new method to create a course section
  static Future<CourseSection> createCourseSection(
      String courseId, String title, String? description) async {
    try {
      final data = {
        'course_id': courseId,
        'title': title,
        'description': description,
        'is_published': true,
      };
      final response = await _supabase
          .from('course_sections')
          .insert(data)
          .select()
          .single();
      return CourseSection.fromJson(response);
    } catch (e) {
      debugPrint('Error creating course section: $e');
      throw Exception('فشل في إنشاء قسم جديد: $e');
    }
  }

  // Agregar un nuevo video - Fix the section_id handling
  static Future<CourseVideo> addCourseVideo(CourseVideo video) async {
    try {
      // Obtener el último orden para este curso
      final lastOrderResponse = await _supabase
          .from('course_videos')
          .select('order_number')
          .eq('course_id', video.courseId)
          .order('order_number', ascending: false)
          .limit(1);
      int nextOrder = 1;
      if ((lastOrderResponse as List).isNotEmpty) {
        nextOrder = lastOrderResponse[0]['order_number'] + 1;
      }
      // Create a data map without section_id first
      final videoData = {
        'course_id': video.courseId,
        'title': video.title,
        'description': video.description,
        'video_id': video.videoId,
        'duration': video.duration,
        'order_number': nextOrder,
        'created_at': video.createdAt.toIso8601String(),
      };
      // Only add section_id if it's not null and not empty
      if (video.sectionId != null && video.sectionId!.isNotEmpty) {
        videoData['section_id'] = video.sectionId;
        debugPrint('Adding section_id: ${video.sectionId} to video data');
      } else {
        debugPrint('No section_id added to video data');
      }
      // Add debug info
      debugPrint('Sending video data to database: $videoData');
      final response = await _supabase
          .from('course_videos')
          .insert(videoData)
          .select()
          .single();
      // Actualizar el recuento de videos en el curso
      await _updateCourseVideoCount(video.courseId);
      debugPrint('Video created successfully: ${response['id']}');
      return CourseVideo.fromJson(response);
    } catch (e) {
      debugPrint('Error adding course video: $e');
      throw Exception('فشل في إضافة الفيديو: $e');
    }
  }

  // Actualizar un video existente - Fix the section_id handling
  static Future<CourseVideo> updateCourseVideo(
      String id, CourseVideo video) async {
    try {
      // Create a data map without section_id first
      final videoData = {
        'course_id': video.courseId,
        'title': video.title,
        'description': video.description,
        'video_id': video.videoId,
        'duration': video.duration,
        'order_number': video.orderNumber,
      };
      // Only add section_id if it's not null and not empty
      if (video.sectionId != null && video.sectionId!.isNotEmpty) {
        videoData['section_id'] = video.sectionId;
      }
      final response = await _supabase
          .from('course_videos')
          .update(videoData)
          .eq('id', id)
          .select()
          .single();
      return CourseVideo.fromJson(response);
    } catch (e) {
      debugPrint('Error updating course video: $e');
      throw Exception('فشل في تحديث الفيديو: $e');
    }
  }

  // Eliminar un video
  static Future<bool> deleteCourseVideo(String id, String courseId) async {
    try {
      // Eliminar los archivos asociados primero
      await _supabase.from('course_files').delete().eq('video_id', id);
      // Eliminar el video
      await _supabase.from('course_videos').delete().eq('id', id);
      // Actualizar el recuento de videos en el curso
      await _updateCourseVideoCount(courseId);
      return true;
    } catch (e) {
      debugPrint('Error deleting course video: $e');
      throw Exception('فشل في حذف الفيديو: $e');
    }
  }

  // Cambiar el orden de un video
  static Future<bool> reorderVideo(
      String videoId, int newOrder, String courseId) async {
    try {
      await _supabase
          .from('course_videos')
          .update({'order_number': newOrder}).eq('id', videoId);
      return true;
    } catch (e) {
      debugPrint('Error reordering video: $e');
      throw Exception('فشل في تغيير ترتيب الفيديو: $e');
    }
  }

  // Agregar un archivo adjunto a un video
  static Future<CourseFile> addCourseFile(CourseFile file) async {
    try {
      // Obtener el último orden para este video
      final lastOrderResponse = await _supabase
          .from('course_files')
          .select('order_number')
          .eq('video_id', file.videoId)
          .order('order_number', ascending: false)
          .limit(1);
      int nextOrder = 1;
      if ((lastOrderResponse as List).isNotEmpty) {
        nextOrder = lastOrderResponse[0]['order_number'] + 1;
      }
      // Crear un mapa de datos con el orden calculado
      final fileData = {
        ...file.toJson(),
        'order_number': nextOrder,
      };
      final response = await _supabase
          .from('course_files')
          .insert(fileData)
          .select()
          .single();
      return CourseFile.fromJson(response);
    } catch (e) {
      debugPrint('Error adding course file: $e');
      throw Exception('فشل في إضافة الملف: $e');
    }
  }

  // تحسين دالة حذف الملف المرفق لتكون أكثر موثوقية وتوفر تفاصيل أكثر
  static Future<bool> deleteCourseFile(String id) async {
    try {
      debugPrint('بدء عملية حذف الملف: $id');

      // الحصول على معلومات الملف من قاعدة البيانات
      final fileResponse = await _supabase
          .from('course_files')
          .select('file_id, title')
          .eq('id', id)
          .maybeSingle();

      if (fileResponse == null) {
        debugPrint('❌ لم يتم العثور على الملف في قاعدة البيانات');
        throw Exception('الملف غير موجود في قاعدة البيانات');
      }

      final String fileId = fileResponse['file_id'] ?? '';
      final String fileTitle = fileResponse['title'] ?? 'ملف غير معروف';

      debugPrint('📄 معلومات الملف: المعرف=$fileId، العنوان=$fileTitle');

      if (fileId.isEmpty) {
        debugPrint('⚠️ تحذير: معرف الملف فارغ!');
      } else {
        // محاولة حذف الملف من Bunny.net Storage
        debugPrint('🔍 محاولة حذف الملف من Bunny.net: $fileId');

        if (_bunnyStorageZone != null && _bunnyStoragePassword != null) {
          try {
            final url =
                'https://$_bunnyStorageHostname/$_bunnyStorageZone/$fileId';
            debugPrint('🌐 URL للحذف: $url');

            final response = await http.delete(
              Uri.parse(url),
              headers: {'AccessKey': _bunnyStoragePassword!},
            );

            if (response.statusCode >= 200 && response.statusCode < 300) {
              debugPrint('✅ تم حذف الملف من Bunny.net بنجاح');
            } else {
              // لا نريد إيقاف العملية إذا فشل الحذف من التخزين، فقط نسجل الخطأ
              debugPrint(
                  '⚠️ فشل في حذف الملف من Bunny.net: ${response.statusCode}, ${response.body}');
              // نحاول دائمًا حذف الملف من قاعدة البيانات حتى إذا فشل الحذف من التخزين
              debugPrint(
                  '! فشل في حذف الملف من Bunny.net، ولكن سنستمر في حذفه من قاعدة البيانات');
            }
          } catch (storageError) {
            debugPrint(
                '⚠️ خطأ أثناء محاولة حذف الملف من التخزين: $storageError');
            // استمر في الحذف من قاعدة البيانات
          }
        } else {
          debugPrint('⚠️ تحذير: بيانات اعتماد Bunny Storage غير مكتملة');
        }
      }

      // خطوة 2: حذف الملف من قاعدة البيانات بغض النظر عن نتيجة الحذف من التخزين
      await _supabase.from('course_files').delete().eq('id', id);
      debugPrint('✅ تم حذف الملف من قاعدة البيانات بنجاح');

      return true;
    } catch (e) {
      debugPrint('❌ خطأ في حذف ملف الدورة: $e');
      throw Exception('فشل في حذف الملف: $e');
    }
  }

  // Subir un video a Bunny.net con la API real
  static Future<String> uploadVideoToBunny(File videoFile, String title) async {
    try {
      if (_bunnyStreamApiKey == null || _bunnyLibraryId == null) {
        throw Exception(
            'فشل في الرفع: مفاتيح API لـ Bunny.net Stream غير مكتملة');
      }
      // إظهار رسالة تحذير للتطوير
      debugPrint(
          'جاري رفع الفيديو إلى Bunny.net (قد يستغرق وقتاً طويلاً للملفات الكبيرة)');
      // 1. إنشاء الفيديو في Bunny Stream
      final createResponse = await http.post(
        Uri.parse('https://video.bunnycdn.com/library/$_bunnyLibraryId/videos'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'AccessKey': _bunnyStreamApiKey!,
        },
        body: jsonEncode({
          'title': title,
          'collectionId': null, // يمكن استخدامه لتنظيم الفيديوهات في مجموعات
        }),
      );
      if (createResponse.statusCode != 201 &&
          createResponse.statusCode != 200) {
        throw Exception('فشل في إنشاء الفيديو: ${createResponse.body}');
      }
      final videoData = jsonDecode(createResponse.body);
      final String videoId = videoData['guid'] ?? '';
      if (videoId.isEmpty) {
        throw Exception('لم يتم الحصول على معرف الفيديو من API');
      }
      // 2. رفع ملف الفيديو
      final uploadUrl =
          'https://video.bunnycdn.com/library/$_bunnyLibraryId/videos/$videoId';
      // قراءة الملف كـ bytes
      final videoBytes = await videoFile.readAsBytes();
      final uploadResponse = await http.put(
        Uri.parse(uploadUrl),
        headers: {
          'Accept': 'application/json',
          'AccessKey': _bunnyStreamApiKey!,
        },
        body: videoBytes,
      );
      if (uploadResponse.statusCode != 200) {
        throw Exception('فشل في رفع الفيديو: ${uploadResponse.body}');
      }
      debugPrint('تم رفع الفيديو بنجاح إلى Bunny.net، معرف الفيديو: $videoId');

      // للتطوير فقط (مُعلّق في وضع الإنتاج)
      // return "989b0866-b522-4c56-b7c3-487d858943ed"; // معرف ثابت للاختبار
      // في الإنتاج، عد معرف الفيديو الفعلي
      return videoId;
    } catch (e) {
      debugPrint('Error uploading video to Bunny.net: $e');
      throw Exception('فشل في رفع الفيديو: $e');
    }
  }

  // Subir un archivo a Bunny.net Storage
  static Future<String> uploadFileToBunny(File file, String title) async {
    try {
      if (_bunnyStoragePassword == null ||
          _bunnyStorageZone == null ||
          _bunnyStorageHostname == null) {
        throw Exception(
            'فشل في الرفع: مفاتيح API لـ Bunny.net Storage غير مكتملة');
      }
      // Generar un nombre de archivo único
      final String fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${path.basename(file.path)}';
      final String formattedFileName = Uri.encodeComponent(fileName);
      // URL para subir el archivo al almacenamiento
      final uploadUrl =
          'https://$_bunnyStorageHostname/$_bunnyStorageZone/$formattedFileName';
      // Leer el archivo como bytes
      final fileBytes = await file.readAsBytes();
      final response = await http.put(
        Uri.parse(uploadUrl),
        headers: {
          'AccessKey': _bunnyStoragePassword!,
          'Content-Type': 'application/octet-stream',
        },
        body: fileBytes,
      );
      if (response.statusCode != 201) {
        throw Exception('فشل في رفع الملف: ${response.body}');
      }
      // Simulación para desarrollo
      // await Future.delayed(const Duration(seconds: 2));
      // return "bunny_file_id_${DateTime.now().millisecondsSinceEpoch}";
      // En producción devolver el nombre del archivo para referencias futuras
      return fileName;
    } catch (e) {
      debugPrint('Error uploading file to Bunny.net: $e');
      throw Exception('فشل في رفع الملف: $e');
    }
  }

  // Obtener URL de descarga de un archivo - تحديث لاستخدام CDN
  static String getBunnyFileUrl(String fileId) {
    // استخدام النطاق المعرف في ملف .env، أو استخدام القيمة الافتراضية إذا لم تكن متوفرة
    final cdnDomain = _bunnyCdnDomain ?? 'myzoneit32.b-cdn.net';

    // التحقق من أن معرف الملف ليس فارغاً
    if (fileId.isEmpty) {
      debugPrint('Warning: Empty file ID provided to getBunnyFileUrl');
      return '';
    }

    // طباعة الرابط للتشخيص
    final url = 'https://$cdnDomain/$fileId';
    debugPrint('Generated file URL: $url');

    return url;
  }

  // دالة لتوليد روابط محددة باستخدام الوصول المباشر
  static String getDirectStorageUrl(String fileId) {
    if (_bunnyStorageZone == null ||
        _bunnyStoragePassword == null ||
        _bunnyStorageHostname == null) {
      return '';
    }

    // تحديد ما إذا كان المعرف هو مسار كامل أو مجرد اسم ملف
    String filePath = fileId;
    if (!filePath.contains('/')) {
      // إذا كان مجرد اسم ملف، أضف المسار الافتراضي
      filePath = 'course_files/$fileId';
    }

    // استخدام واجهة API مباشرة مع إضافة مفتاح الوصول كمعلمة
    final url =
        'https://$_bunnyStorageHostname/$_bunnyStorageZone/$filePath?AccessKey=$_bunnyStoragePassword';
    debugPrint('🔗 رابط مباشر للملف: $url');
    return url;
  }

  // دالة جديدة لإنشاء توقيع مصادقة للملف
  static String _generateStorageSignature(String path, DateTime expiry) {
    if (_bunnyStoragePassword == null) return '';

    final expiryTimestamp = (expiry.millisecondsSinceEpoch ~/ 1000).toString();
    final dataToSign = '$_bunnyStorageZone$path$expiryTimestamp';
    final hmacSha256 = Hmac(sha256, utf8.encode(_bunnyStoragePassword!));
    final digest = hmacSha256.convert(utf8.encode(dataToSign));
    return digest.toString();
  }

  // إضافة دالة جديدة للحصول على تفاصيل الفيديو من Bunny.net
  static Future<Map<String, dynamic>> getVideoDetails(String videoId) async {
    try {
      if (_bunnyStreamApiKey == null || _bunnyLibraryId == null) {
        throw Exception(
            'فشل في الحصول على تفاصيل الفيديو: مفاتيح API غير مكتملة');
      }
      final url =
          'https://video.bunnycdn.com/library/$_bunnyLibraryId/videos/$videoId';

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'AccessKey': _bunnyStreamApiKey!,
        },
      );
      if (response.statusCode == 200) {
        final videoData = jsonDecode(response.body);
        return videoData;
      } else {
        throw Exception('فشل في الحصول على تفاصيل الفيديو: ${response.body}');
      }
    } catch (e) {
      debugPrint('Error fetching video details: $e');
      throw Exception('فشل في الحصول على تفاصيل الفيديو: $e');
    }
  }

  /// Check if a video has DRM protection enabled
  static Future<bool> isVideoDrmProtected(String videoId) async {
    try {
      // Handle empty videoId
      if (videoId.isEmpty) {
        debugPrint('Empty videoId provided to isVideoDrmProtected');
        return false;
      }

      final details = await getVideoDetails(videoId);

      // Safely check DRM status with null handling
      final encodeProgress = details['encodeProgress'] ?? 0;
      final mediaCage =
          details['mediaCage']; // This could be null, true, or 'Basic'

      return encodeProgress == 100 &&
          (mediaCage == true || mediaCage == 'Basic');
    } catch (e) {
      debugPrint('Error checking DRM status: $e');
      return false;
    }
  }

  // Actualizar el recuento de videos y la duración total en el curso
  static Future<void> _updateCourseVideoCount(String courseId) async {
    try {
      // Obtener todos los videos del curso
      final videos = await _supabase
          .from('course_videos')
          .select('duration')
          .eq('course_id', courseId);

      int totalVideos = videos.length;
      int totalDuration = 0;

      for (var video in videos) {
        totalDuration += video['duration'] as int;
      }

      // Actualizar el curso
      await _supabase.from('courses').update({
        'total_videos': totalVideos,
        'total_duration': totalDuration ~/ 60, // Convertir segundos a minutos
      }).eq('id', courseId);
    } catch (e) {
      debugPrint('Error updating course video count: $e');
    }
  }
}
