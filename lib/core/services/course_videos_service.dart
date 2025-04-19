import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:mycourses/core/utils/logging_utils.dart';
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

  // Add a variable for API base URL
  static const String apiBaseUrl =
      '/api'; // Replace with your actual API base URL

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

  // Modify the getCourseSections method to ensure ascending order
  static Future<List<CourseSection>> getCourseSections(String courseId) async {
    try {
      // Get the sections with explicit ascending order by order_number
      final sectionsResponse = await _supabase
          .from('course_sections')
          .select('*')
          .eq('course_id', courseId)
          .order('order_number', ascending: true); // صريحة للترتيب التصاعدي

      final List<CourseSection> sections = (sectionsResponse as List)
          .map((data) => CourseSection.fromJson(data))
          .toList();

      debugPrint('📋 تم تحميل ${sections.length} قسم بترتيب تصاعدي');

      // تأكد من ترتيب الأقسام تصاعدياً (مرتبة حسب order_number) - خطوة احتياطية
      sections.sort((a, b) => a.orderNumber.compareTo(b.orderNumber));

      // Get the video counts for each section
      if (sections.isNotEmpty) {
        for (var section in sections) {
          final videoCountResponse = await _supabase
              .from('course_videos')
              .select('*')
              .eq('section_id', section.id)
              .eq('course_id', courseId);

          final count = (videoCountResponse as List).length;
          section.videoCount = count;
          debugPrint(
              '📊 القسم ${section.title} [${section.orderNumber}]: يحتوي على $count فيديو');
        }
      }

      return sections;
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

  // تعديل دالة إضافة فيديو جديد لتتناسب مع التسلسل العام
  static Future<CourseVideo> addCourseVideo(CourseVideo video) async {
    try {
      // بدلاً من الحصول على آخر ترتيب في القسم، نحصل على آخر ترتيب في الكورس كله
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

      debugPrint('🆕 إضافة فيديو جديد برقم ترتيب تسلسلي: $nextOrder');

      // Create a data map without section_id first
      final videoData = {
        'course_id': video.courseId,
        'title': video.title,
        'description': video.description,
        'video_id': video.videoId,
        'duration': video.duration,
        'order_number': nextOrder,
      };

      // Only add section_id if it's not null and not empty
      if (video.sectionId != null && video.sectionId!.isNotEmpty) {
        videoData['section_id'] = video.sectionId as dynamic;
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
      debugPrint(
          'Video created successfully: ${response['id']} with order number $nextOrder');
      return CourseVideo.fromJson(response);
    } catch (e) {
      debugPrint('Error adding course video: $e');
      throw Exception('فشل في إضافة الفيديو: $e');
    }
  }

  // Actualizar un video existente - Fix the section_id handling and null safety
  static Future<CourseVideo> updateCourseVideo(
      String id, CourseVideo video) async {
    try {
      // Create a data map without section_id first
      final Map<String, dynamic> videoData = {
        'course_id': video.courseId,
        'title': video.title,
        'description': video.description,
        'video_id': video.videoId,
        'duration': video.duration,
        'order_number': video.orderNumber,
      };

      // Only add section_id if it's not null and not empty
      if (video.sectionId != null && video.sectionId!.isNotEmpty) {
        // Cast String? to dynamic which is accepted by Map<String, dynamic>
        videoData['section_id'] = video.sectionId as dynamic;
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

  /// تحديث ترتيب القسم مع استخدام خوارزمية محسنة
  static Future<void> updateSectionOrder(
      String sectionId, int orderNumber) async {
    try {
      // 1. الحصول على معرف الكورس وكافة البيانات المطلوبة للقسم
      final sectionResponse = await _supabase
          .from('course_sections')
          .select('*') // استرجاع جميع الحقول لنتأكد من وجود جميع البيانات
          .eq('id', sectionId)
          .single();

      final String courseId = sectionResponse['course_id'];
      final String title =
          sectionResponse['title'] ?? ''; // معالجة القيم الفارغة
      final String? description = sectionResponse['description'];
      final bool isPublished = sectionResponse['is_published'] ?? true;

      LoggingUtils.debugLog(
          '🔍 تحديث ترتيب القسم $sectionId ($title) للكورس $courseId');

      // 2. الحصول على جميع أقسام الكورس مع كافة البيانات
      final sectionsResponse = await _supabase
          .from('course_sections')
          .select('*') // استرجاع جميع الحقول
          .eq('course_id', courseId)
          .order('order_number', ascending: true);

      LoggingUtils.debugLog(
          '📋 تم استرجاع ${sectionsResponse.length} قسم للترتيب');

      // 3. تحويل البيانات إلى مصفوفة من خرائط البيانات مع التأكد من وجود جميع الحقول
      final List<Map<String, dynamic>> sections = [];
      for (var section in (sectionsResponse as List)) {
        // نسخ جميع الحقول كما هي
        sections.add(Map<String, dynamic>.from(section));
      }

      LoggingUtils.debugLog('🔄 بدء عملية تغيير الترتيب...');

      // 4. معالجة تغيير الترتيب
      // إيجاد القسم المطلوب نقله
      final int currentIndex = sections.indexWhere((s) => s['id'] == sectionId);
      if (currentIndex == -1) {
        throw Exception('القسم غير موجود في قائمة الأقسام');
      }

      // حفظ القسم المطلوب نقله
      final Map<String, dynamic> movedSection =
          Map<String, dynamic>.from(sections[currentIndex]);
      final int currentOrderNumber = movedSection['order_number'] ?? 0;

      LoggingUtils.debugLog(
          '📋 القسم المحدد: الترتيب الحالي $currentOrderNumber، الترتيب الجديد $orderNumber');

      // حذف القسم من موقعه الحالي
      sections.removeAt(currentIndex);

      // إضافة القسم في الموقع الجديد
      int newIndex = orderNumber - 1;
      newIndex = newIndex.clamp(0, sections.length);
      sections.insert(newIndex, movedSection);

      // 5. إنشاء عمليات التحديث مع التأكد من وجود جميع الحقول المطلوبة
      final List<Map<String, dynamic>> updateData = [];
      for (int i = 0; i < sections.length; i++) {
        final sectionData = sections[i];
        final int newOrderNum = i + 1;

        // التأكد من تضمين جميع الحقول المطلوبة
        final Map<String, dynamic> updatedData = {
          'id': sectionData['id'],
          'course_id': sectionData['course_id'],
          'title': sectionData['title'] ?? '', // تأكد من أن العنوان ليس فارغاً
          'description': sectionData['description'],
          'is_published': sectionData['is_published'] ?? true,
          'order_number': newOrderNum,
          // لا نحتاج لإرسال هذه الحقول لأنها ستُحدث تلقائياً
          // 'created_at': sectionData['created_at'],
          // 'updated_at': sectionData['updated_at'],
        };

        updateData.add(updatedData);

        if (sectionData['id'] == sectionId) {
          LoggingUtils.debugLog(
              '📝 تغيير ترتيب القسم $sectionId من $currentOrderNumber إلى $newOrderNum');
        }
      }

      // طباعة بيانات التحديث للقسم المستهدف للتحقق منها
      final targetUpdateData = updateData
          .firstWhere((item) => item['id'] == sectionId, orElse: () => {});
      if (targetUpdateData.isNotEmpty) {
        LoggingUtils.debugLog(
            '🔍 بيانات التحديث للقسم $sectionId: $targetUpdateData');
      }

      // 6. تنفيذ عملية التحديث
      final response = await _supabase
          .from('course_sections')
          .upsert(updateData, onConflict: 'id');

      LoggingUtils.debugLog('✅ تم تحديث ترتيب الأقسام بنجاح');

      // 7. إعادة ترتيب الفيديوهات بناءً على الأقسام الجديدة
      await _reorderAllCourseVideos(courseId);

      LoggingUtils.debugLog(
          '✅ تم إعادة ترتيب فيديوهات الكورس بعد تغيير ترتيب القسم');
    } catch (e) {
      LoggingUtils.debugLog('❌ خطأ في تحديث ترتيب القسم: $e');
      rethrow;
    }
  }

  /// إعادة ترتيب جميع فيديوهات الكورس بشكل تسلسلي عبر جميع الأقسام
  /// هذه الدالة تضمن أن جميع الفيديوهات لها ترقيم متسلسل مستمر بغض النظر عن القسم
  static Future<void> _reorderAllCourseVideos(String courseId) async {
    try {
      LoggingUtils.debugLog(
          '🔄 بدء إعادة ترتيب جميع فيديوهات الكورس $courseId بشكل متسلسل...');

      // 1. الحصول على أقسام الكورس مرتبة تصاعدياً
      final sectionsResponse = await _supabase
          .from('course_sections')
          .select('id, title, order_number')
          .eq('course_id', courseId)
          .order('order_number', ascending: true);

      List<Map<String, dynamic>> sections =
          List<Map<String, dynamic>>.from(sectionsResponse);

      LoggingUtils.debugLog('📋 تم العثور على ${sections.length} قسم للكورس');

      // 2. جمع جميع فيديوهات الكورس دفعة واحدة للتحسين - استرجاع كافة الحقول المطلوبة
      final allVideosResponse = await _supabase
          .from('course_videos')
          .select('*') // استخدام * لاستعادة جميع الحقول
          .eq('course_id', courseId);

      List<Map<String, dynamic>> allVideos =
          List<Map<String, dynamic>>.from(allVideosResponse);

      LoggingUtils.debugLog(
          '📋 تم العثور على ${allVideos.length} فيديو للكورس');

      // 3. تنظيم الفيديوهات حسب الأقسام
      Map<String?, List<Map<String, dynamic>>> videosBySection = {};

      // تهيئة القوائم لكل قسم
      for (var section in sections) {
        videosBySection[section['id']] = [];
      }

      // إضافة قائمة للفيديوهات غير المصنفة
      videosBySection[null] = [];

      // توزيع الفيديوهات على الأقسام
      for (var video in allVideos) {
        String? sectionId = video['section_id'];

        if (!videosBySection.containsKey(sectionId)) {
          videosBySection[sectionId] = [];
        }

        videosBySection[sectionId]!.add(video);
      }

      // 4. إنشاء قائمة مرتبة لجميع معرفات الفيديوهات حسب الأقسام
      int orderCounter = 1; // بدء الترتيب من 1
      List<Map<String, dynamic>> orderedVideosWithNewOrder = [];

      // المرور على الأقسام بالترتيب وإضافة فيديوهاتها
      for (var section in sections) {
        String sectionId = section['id'];
        List<Map<String, dynamic>> sectionVideos =
            videosBySection[sectionId] ?? [];

        LoggingUtils.debugLog(
            '📊 يتم ترتيب فيديوهات القسم "${section['title']}" (${sectionVideos.length} فيديو)');

        for (var video in sectionVideos) {
          // نسخ كامل بيانات الفيديو قبل التعديل عليه
          final videoData = Map<String, dynamic>.from(video);

          // تعديل رقم الترتيب فقط
          videoData['order_number'] = orderCounter++;

          orderedVideosWithNewOrder.add(videoData);
        }
      }

      // إضافة الفيديوهات غير المصنفة في النهاية
      List<Map<String, dynamic>> uncategorizedVideos =
          videosBySection[null] ?? [];
      LoggingUtils.debugLog(
          '📊 يتم ترتيب الفيديوهات غير المصنفة (${uncategorizedVideos.length} فيديو)');

      for (var video in uncategorizedVideos) {
        // نسخ كامل بيانات الفيديو قبل التعديل عليه
        final videoData = Map<String, dynamic>.from(video);

        // تعديل رقم الترتيب فقط
        videoData['order_number'] = orderCounter++;

        orderedVideosWithNewOrder.add(videoData);
      }

      // 5. تحديث ترتيب جميع الفيديوهات في قاعدة البيانات
      if (orderedVideosWithNewOrder.isNotEmpty) {
        LoggingUtils.debugLog(
            '📊 تحديث ترتيب ${orderedVideosWithNewOrder.length} فيديو');

        // تقسيم التحديثات إلى دفعات لتسريع العملية وتقليل الحمل
        final batchSize = 30;
        for (int i = 0; i < orderedVideosWithNewOrder.length; i += batchSize) {
          final end = (i + batchSize < orderedVideosWithNewOrder.length)
              ? i + batchSize
              : orderedVideosWithNewOrder.length;

          final batch = orderedVideosWithNewOrder.sublist(i, end);

          try {
            // تحديث فقط الحقول المطلوبة مع التأكد من وجود جميع الحقول الإلزامية
            final updateBatch = batch
                .map((video) => {
                      'id': video['id'],
                      'course_id': video['course_id'],
                      'order_number': video['order_number'],
                      'title':
                          video['title'] ?? '', // تأكد من أن العنوان ليس null
                      'description':
                          video['description'] ?? '', // تأكد من تضمين الوصف
                      'video_id':
                          video['video_id'] ?? '', // تأكد من تضمين معرف الفيديو
                      'section_id': video['section_id'], // يمكن أن يكون null
                      'duration':
                          video['duration'] ?? 0, // تأكد من تضمين المدة الزمنية
                    })
                .toList();

            await _supabase.from('course_videos').upsert(
                  updateBatch,
                  onConflict: 'id',
                );

            LoggingUtils.debugLog(
                '✅ تم تحديث الدفعة ${(i ~/ batchSize) + 1}: فيديوهات من ${i + 1} إلى $end');
          } catch (e) {
            LoggingUtils.debugLog(
                '❌ خطأ في تحديث دفعة الفيديوهات ${i + 1} إلى $end: $e');

            // في حالة فشل التحديث الجماعي، نحاول تحديث كل فيديو بشكل منفرد
            for (var video in batch) {
              try {
                await _supabase.from('course_videos').upsert({
                  'id': video['id'],
                  'course_id': video['course_id'],
                  'title': video['title'] ?? '', // تأكد من أن العنوان ليس null
                  'description':
                      video['description'] ?? '', // تأكد من تضمين الوصف
                  'video_id':
                      video['video_id'] ?? '', // تأكد من تضمين معرف الفيديو
                  'order_number': video['order_number'],
                  'section_id': video['section_id'],
                  'duration': video['duration'] ?? 0,
                }, onConflict: 'id');

                LoggingUtils.debugLog(
                    '✅ تم تحديث الفيديو ${video['id']} بشكل فردي');
              } catch (individualError) {
                LoggingUtils.debugLog(
                    '❌ فشل في تحديث الفيديو ${video['id']}: $individualError');

                // طباعة بيانات الفيديو للتحقق
                LoggingUtils.debugLog('📝 بيانات الفيديو: ${video.toString()}');

                // تحديث رقم الترتيب فقط كحل بديل
                try {
                  await _supabase.from('course_videos').update({
                    'order_number': video['order_number'],
                  }).eq('id', video['id']);

                  LoggingUtils.debugLog(
                      '✅ تم تحديث رقم ترتيب الفيديو ${video['id']} فقط');
                } catch (fallbackError) {
                  LoggingUtils.debugLog(
                      '❌ فشل حتى في تحديث رقم الترتيب: $fallbackError');
                }
              }
            }
          }
        }
      }

      LoggingUtils.debugLog('✅ تمت إعادة ترتيب جميع الفيديوهات بنجاح');
    } catch (e) {
      LoggingUtils.debugLog('❌ خطأ أثناء إعادة ترتيب الفيديوهات: $e');
      // لا نريد إيقاف العملية بالكامل إذا فشلت عملية إعادة الترتيب
    }
  }

  /// تحديث ترتيب فيديو أو نقله بين الأقسام
  static Future<void> updateVideoOrder(
      String videoId, int newIndex, String? sectionId) async {
    try {
      LoggingUtils.debugLog(
          '🔄 Starting updateVideoOrder for video $videoId to position $newIndex in section $sectionId');

      // Get video and validate data
      final videoResponse = await _supabase
          .from('course_videos')
          .select('*')
          .eq('id', videoId)
          .single();

      final String courseId = videoResponse['course_id'];
      final String? currentSectionId = videoResponse['section_id'];

      LoggingUtils.debugLog(
          '📊 Video info: courseId=$courseId, currentSection=$currentSectionId, targetSection=$sectionId');

      // Validate course ID
      if (courseId.isEmpty) {
        throw Exception('معرف الكورس غير موجود في الفيديو المحدد');
      }

      // Get target section videos using proper null handling
      final query =
          _supabase.from('course_videos').select('*').eq('course_id', courseId);

      LoggingUtils.debugLog(
          '🔍 Getting videos for section: $sectionId (null means uncategorized)');

      // Only add section filter if sectionId is not null
      final targetVideos = await (sectionId != null
              ? query.eq('section_id', sectionId)
              : query.isFilter('section_id', null))
          .order('order_number', ascending: true);

      LoggingUtils.debugLog(
          '📊 Found ${targetVideos.length} videos in target section');

      // Calculate new order number ensuring it's always > 0
      int newOrderNumber = 1;
      if (newIndex > 0 && newIndex <= targetVideos.length) {
        // Get the order numbers of adjacent videos
        final prevVideo = targetVideos[newIndex - 1];
        final prevOrder = prevVideo['order_number'] as int;

        if (newIndex < targetVideos.length) {
          final nextVideo = targetVideos[newIndex];
          final nextOrder = nextVideo['order_number'] as int;
          // Place between videos
          newOrderNumber = prevOrder + ((nextOrder - prevOrder) ~/ 2);
          LoggingUtils.debugLog(
              '📊 Setting order between videos: prevOrder=$prevOrder, nextOrder=$nextOrder, newOrder=$newOrderNumber');
        } else {
          // Place at end
          newOrderNumber = prevOrder + 1;
          LoggingUtils.debugLog(
              '📊 Setting order at the end: prevOrder=$prevOrder, newOrder=$newOrderNumber');
        }
      } else {
        LoggingUtils.debugLog(
            '📊 Setting order at the beginning: newOrder=$newOrderNumber');
      }

      // Update the video with new section and order
      final updateData = {
        'order_number': newOrderNumber,
        'section_id': sectionId, // This is fine as nullable
        // Include all required fields
        'course_id': courseId,
        'title': videoResponse['title'],
        'description': videoResponse['description'] ?? '',
        'video_id': videoResponse['video_id'],
        'duration': videoResponse['duration'],
      };

      LoggingUtils.debugLog('📝 Updating video with data: $updateData');

      // Perform the update
      await _supabase
          .from('course_videos')
          .update(updateData)
          .eq('id', videoId);

      // If needed, reorder all videos to ensure consistent numbering
      LoggingUtils.debugLog(
          '📊 Reordering all videos in the course for consistency');
      await _reorderAllCourseVideos(courseId);

      LoggingUtils.debugLog('✅ Successfully updated video order');
    } catch (e) {
      LoggingUtils.debugLog('❌ Error updating video order: $e');
      rethrow;
    }
  }

  // إضافة دالة مساعدة جديدة لإدراج فيديو في موضع محدد
  static List<Map<String, dynamic>> _insertVideoAtPosition(
      List<Map<String, dynamic>> videos,
      Map<String, dynamic> videoToInsert,
      int position) {
    // نسخة جديدة من القائمة
    final List<Map<String, dynamic>> result = List.from(videos);

    // التأكد من أن الموضع ضمن النطاق
    final int safePosition = position.clamp(0, result.length);

    // إدراج الفيديو في الموضع المطلوب
    result.insert(safePosition, videoToInsert);

    return result;
  }
}
