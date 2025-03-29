import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;

import '../../models/course.dart';
import '../../models/department.dart';
import '../../models/pricing.dart';
import '../../models/stage.dart';
import 'bunny_storage_service.dart'; // استيراد خدمة Bunny.net
import 'supabase_service.dart';

class AdminService {
  static final _supabase = SupabaseService.supabase;

  // Departments
  static Future<List<Department>> getDepartments() async {
    final response = await _supabase.from('departments').select();
    return (response as List).map((data) => Department.fromJson(data)).toList();
  }

  static Future<void> addDepartment(Department department) async {
    await _supabase.from('departments').insert(department.toJson());
  }

  static Future<void> updateDepartment(String id, Department department) async {
    await _supabase
        .from('departments')
        .update(department.toJson())
        .eq('id', id);
  }

  static Future<void> deleteDepartment(String id) async {
    await _supabase.from('departments').delete().eq('id', id);
  }

  // Stages
  static Future<List<Stage>> getStages() async {
    final response = await _supabase.from('stages').select();
    return (response as List).map((data) => Stage.fromJson(data)).toList();
  }

  static Future<void> addStage(Stage stage) async {
    await _supabase.from('stages').insert(stage.toJson());
  }

  static Future<void> updateStage(String id, Stage stage) async {
    await _supabase.from('stages').update(stage.toJson()).eq('id', id);
  }

  static Future<void> deleteStage(String id) async {
    await _supabase.from('stages').delete().eq('id', id);
  }

  /// طريقة قديمة لم تعد تستخدم - للتوافقية الخلفية فقط
  static Future<String?> uploadLegacyToSupabase(File image) async {
    try {
      final fileName = path.basename(image.path);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileExt = fileName.split('.').last;
      final newFileName = 'course_$timestamp.$fileExt';

      final response =
          await _supabase.storage.from('courses').upload(newFileName, image);

      final publicUrl =
          _supabase.storage.from('courses').getPublicUrl(newFileName);

      debugPrint('تم رفع الصورة بنجاح إلى Supabase (طريقة قديمة): $publicUrl');
      return publicUrl;
    } catch (e) {
      debugPrint('خطأ في رفع الصورة إلى Supabase (طريقة قديمة): $e');
      return null;
    }
  }

  /// طريقة أساسية لرفع صور الكورسات إلى Bunny.net
  static Future<String?> uploadCourseThumbnailToBunny(File imageFile) async {
    try {
      final filename = path.basename(imageFile.path);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileExt = filename.split('.').last.toLowerCase();

      if (!['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(fileExt)) {
        throw Exception(
            'نوع الملف غير مدعوم. الأنواع المدعومة هي: jpg, jpeg, png, gif, webp');
      }

      final newFileName = 'course_$timestamp.$fileExt';
      final uploadResult = await BunnyStorageService.uploadFile(
          imageFile, 'courses_photo/$newFileName',
          contentType: 'image/$fileExt');

      if (uploadResult == null) {
        throw Exception('فشل رفع الصورة إلى Bunny.net');
      }

      final url =
          BunnyStorageService.getPublicUrl('courses_photo/$newFileName');
      debugPrint('تم رفع الصورة بنجاح إلى Bunny.net: $url');
      return url;
    } catch (e) {
      debugPrint('خطأ في رفع الصورة إلى Bunny.net: $e');
      return null;
    }
  }

  /// الطريقة الرئيسية والموحدة لرفع صور الكورسات - استخدم هذه الطريقة في كل الملفات
  static Future<String?> uploadCourseImage(File imageFile,
      {bool useBunny = true}) async {
    if (useBunny) {
      return uploadCourseThumbnailToBunny(imageFile);
    } else {
      return uploadLegacyToSupabase(imageFile);
    }
  }

  /// إعادة تعريف الدالة uploadImage لتستخدم Bunny.net كخيار افتراضي
  /// هذه فقط للتوافقية مع الكود القديم
  static Future<String?> uploadImage(File imageFile) async {
    debugPrint(
        '⚠️ تم استدعاء uploadImage القديمة، ننصح باستخدام uploadCourseImage بدلاً منها');
    return uploadCourseImage(imageFile, useBunny: true);
  }

  // Courses
  static Future<List<Course>> getCourses() async {
    final response = await _supabase.from('courses').select('''
          *,
          course_department_semesters (
            department:departments(*),
            stage:stages(*),
            semester:semesters(*)
          ),
          pricing:course_pricing(*)
        ''').order('created_at', ascending: false);

    return (response as List).map((data) => Course.fromJson(data)).toList();
  }

  /// إضافة كورس جديد
  static Future<Map<String, dynamic>> addCourse(
      Course course, String thumbnailUrl) async {
    try {
      // إضافة الكورس الأساسي
      final courseResponse = await _supabase
          .from('courses')
          .insert({
            'title': course.title,
            'description': course.description,
            'thumbnail_url': thumbnailUrl,
            'semester_id': course.semesterId,
            'total_videos': course.totalVideos,
            'total_duration': course.totalDuration,
          })
          .select()
          .single();

      final courseId = courseResponse['id'];

      // إضافة معلومات التسعير إذا كانت موجودة
      if (course.pricing != null) {
        await _supabase.from('course_pricing').insert({
          'course_id': courseId,
          'price': course.pricing!.price,
          'discount_price': course.pricing!.discountPrice,
          'is_active': course.pricing!.isActive,
        });
      }

      // إضافة ارتباطات الأقسام والمراحل
      for (var dept in course.departmentDetails) {
        await _supabase.from('course_department_semesters').insert({
          'course_id': courseId,
          'department_id': dept.departmentId,
          'stage_id': dept.stageId,
          'semester_id': dept.semesterId,
        });
      }

      return courseResponse;
    } catch (e) {
      debugPrint('خطأ في إضافة الكورس: $e');
      throw 'فشل في إضافة الكورس: $e';
    }
  }

  /// حذف كورس بواسطة المعرف
  static Future<bool> deleteCourse(String courseId) async {
    try {
      // حذف ارتباطات الأقسام أولاً
      await _supabase
          .from('course_department_semesters')
          .delete()
          .eq('course_id', courseId);

      // حذف معلومات التسعير
      await _supabase.from('course_pricing').delete().eq('course_id', courseId);

      // حذف الكورس نفسه
      await _supabase.from('courses').delete().eq('id', courseId);

      return true;
    } catch (e) {
      debugPrint('خطأ في حذف الكورس: $e');
      throw Exception('فشل في حذف الكورس: $e');
    }
  }

  /// تعديل كورس موجود
  static Future<bool> updateCourse(Course course) async {
    try {
      // تحديث بيانات الكورس الأساسية
      await _supabase.from('courses').update({
        'title': course.title,
        'description': course.description,
        'thumbnail_url': course.thumbnailUrl,
        'semester_id': course.semesterId,
        'total_videos': course.totalVideos,
        'total_duration': course.totalDuration,
      }).eq('id', course.id);

      // إذا كان هناك سعر، قم بتحديثه
      if (course.pricing != null) {
        // التحقق ما إذا كان هناك سجل موجود أولاً
        final pricingExists = await _supabase
            .from('course_pricing')
            .select()
            .eq('course_id', course.id);

        if ((pricingExists as List).isNotEmpty) {
          // تحديث السعر الموجود
          await _supabase.from('course_pricing').update({
            'price': course.pricing!.price,
            'discount_price': course.pricing!.discountPrice,
            'is_active': course.pricing!.isActive,
            'updated_at': DateTime.now().toIso8601String(),
          }).eq('course_id', course.id);
        } else {
          // إضافة سعر جديد
          await _supabase.from('course_pricing').insert({
            'course_id': course.id,
            'price': course.pricing!.price,
            'discount_price': course.pricing!.discountPrice,
            'is_active': course.pricing!.isActive,
          });
        }
      }

      // إعادة تعيين أقسام الكورس
      await _supabase
          .from('course_department_semesters')
          .delete()
          .eq('course_id', course.id);

      for (var dept in course.departmentDetails) {
        await _supabase.from('course_department_semesters').insert({
          'course_id': course.id,
          'department_id': dept.departmentId,
          'stage_id': dept.stageId,
          'semester_id': dept.semesterId,
        });
      }

      return true;
    } catch (e) {
      debugPrint('خطأ في تعديل الكورس: $e');
      throw Exception('فشل في تعديل الكورس: $e');
    }
  }

  // Pricing
  static Future<List<Pricing>> getPricing() async {
    final response = await _supabase.from('pricing').select('''
      *,
      courses:course_id(*)
    ''');
    return (response as List).map((data) => Pricing.fromJson(data)).toList();
  }

  static Future<void> addPricing(Pricing pricing) async {
    await _supabase.from('pricing').insert(pricing.toJson());
  }

  static Future<void> updatePricing(String id, Pricing pricing) async {
    await _supabase.from('pricing').update(pricing.toJson()).eq('id', id);
  }

  static Future<void> deletePricing(String id) async {
    await _supabase.from('pricing').delete().eq('id', id);
  }

  // دالة إضافية للحصول على رابط الصورة بناءً على اسم الملف في Bunny.net
  static String getImageUrl(String fileName) {
    // استخدام Bunny.net للحصول على عنوان URL للصورة
    if (fileName.startsWith('http')) {
      return fileName;
    } else {
      return BunnyStorageService.getPublicUrl('courses_photo/$fileName');
    }
  }

  // إضافة دالة مساعدة لتحويل روابط Supabase إلى Bunny
  static bool isSupabaseUrl(String? url) {
    if (url == null || url.isEmpty) return false;
    return url.contains('supabase') ||
        url.contains('storage.googleapis') ||
        url.contains('course-thumbnails');
  }

  // دالة جديدة للتحقق من مصدر الصورة وتحسينها
  static String optimizeImageUrl(String? url) {
    if (url == null || url.isEmpty) {
      return 'https://via.placeholder.com/150';
    }

    // تنظيف الرابط من الشرطات المائلة المزدوجة مع الحفاظ على البروتوكول
    String cleanUrl = url;

    // فصل البروتوكول (https:// أو http://) عن باقي الرابط
    final protocolMatch = RegExp(r'^(https?:\/\/)').firstMatch(cleanUrl);
    final protocol = protocolMatch != null ? protocolMatch.group(0) ?? '' : '';

    if (protocol.isNotEmpty) {
      // نحذف البروتوكول من النص الأصلي
      final pathPart = cleanUrl.substring(protocol.length);
      // نقوم بتنظيف المسار فقط (استبدال // بـ /)
      final cleanPath = pathPart.replaceAll('//', '/');
      // إعادة دمج البروتوكول مع المسار المنظف
      cleanUrl = '$protocol$cleanPath';
    } else if (cleanUrl.startsWith('/')) {
      // إذا كان المسار يبدأ بشرطة مائلة، قم بإزالتها
      cleanUrl = cleanUrl.substring(1);
    }

    // طباعة تشخيصية للتحقق من تنظيف الرابط
    if (url != cleanUrl) {
      debugPrint('تنظيف الرابط: $url -> $cleanUrl');
    }

    // تحقق مما إذا كان الرابط من Bunny.net
    if (cleanUrl.contains('bunny') ||
        cleanUrl.contains('b-cdn.net') ||
        cleanUrl.contains('storage.bunnycdn.com')) {
      return BunnyStorageService.convertStorageUrlToCdnUrl(cleanUrl);
    }

    // تحقق مما إذا كان الرابط من Supabase
    if (isSupabaseUrl(cleanUrl)) {
      debugPrint('صورة قديمة من Supabase: $cleanUrl');
      return cleanUrl;
    }

    // تحقق مما إذا كان المسار يحتوي بالفعل على courses_photo
    // لتجنب تكرار المجلد عند استدعاء getPublicUrl
    if (cleanUrl.startsWith('courses_photo/')) {
      return BunnyStorageService.getPublicUrl(cleanUrl);
    }

    // إذا لم يبدأ بـ http، افترض أنه اسم ملف في Bunny.net
    if (!cleanUrl.startsWith('http')) {
      // للتأكد من عدم تكرار courses_photo في المسار
      if (cleanUrl.contains('courses_photo/')) {
        return BunnyStorageService.getPublicUrl(cleanUrl);
      } else {
        return BunnyStorageService.getPublicUrl('courses_photo/$cleanUrl');
      }
    }

    return cleanUrl;
  }
}
