import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/env_config.dart';
import 'browser_info.dart';

class SupabaseService {
  static String get supabaseUrl => EnvConfig.supabaseUrl;
  static String get anonKey => EnvConfig.supabaseAnonKey;

  static final supabase = Supabase.instance.client;
  static final deviceInfo = DeviceInfoPlugin();
  static const adminEmail = 'alasdyahmed1@gmail.com';

  // إضافة مخزن آمن للبيانات
  static const _storage = FlutterSecureStorage();
  static const _sessionKey = 'supabase_session';

  // تحديث دالة الحصول على معرف الجهاز للتعامل مع جميع المنصات
  static Future<Map<String, dynamic>> _getDeviceInfo() async {
    try {
      if (kIsWeb) {
        return await BrowserInfo.getBrowserInfo();
      }

      if (Platform.isAndroid) {
        // للأندرويد
        final androidInfo = await DeviceInfoPlugin().androidInfo;
        return {
          'device_id': androidInfo.id,
          'platform': 'android',
          'model': androidInfo.model,
          'brand': androidInfo.brand,
        };
      } else if (Platform.isIOS) {
        // للآيفون
        final iosInfo = await DeviceInfoPlugin().iosInfo;
        return {
          'device_id': iosInfo.identifierForVendor ?? '',
          'platform': 'ios',
          'model': iosInfo.model,
          'brand': 'Apple',
        };
      } else if (Platform.isWindows) {
        // لنظام ويندوز
        final windowsInfo = await DeviceInfoPlugin().windowsInfo;
        final deviceId = sha256
            .convert(utf8.encode(
                '${windowsInfo.computerName}::${windowsInfo.numberOfCores}::${windowsInfo.systemMemoryInMegabytes}'))
            .toString();
        return {
          'device_id': deviceId,
          'platform': 'windows',
          'model': windowsInfo.computerName,
          'brand': 'PC',
        };
      } else if (Platform.isMacOS) {
        // لنظام ماك
        final macInfo = await DeviceInfoPlugin().macOsInfo;
        final deviceId = sha256
            .convert(utf8.encode(
                '${macInfo.computerName}::${macInfo.arch}::${macInfo.model}'))
            .toString();
        return {
          'device_id': deviceId,
          'platform': 'macos',
          'model': macInfo.model,
          'brand': 'Apple',
        };
      } else if (Platform.isLinux) {
        // لنظام لينكس
        final linuxInfo = await DeviceInfoPlugin().linuxInfo;
        final deviceId = sha256
            .convert(utf8.encode(
                '${linuxInfo.id}::${linuxInfo.version}::${linuxInfo.machineId}'))
            .toString();
        return {
          'device_id': deviceId,
          'platform': 'linux',
          'model': linuxInfo.prettyName,
          'brand': 'Linux',
        };
      }

      // لأي منصة أخرى
      final fallbackId = sha256
          .convert(
              utf8.encode(DateTime.now().millisecondsSinceEpoch.toString()))
          .toString();

      return {
        'device_id': fallbackId,
        'platform': 'unknown',
        'model': 'unknown',
        'brand': 'unknown',
      };
    } catch (e) {
      print('Error getting device info: $e');
      // في حالة حدوث خطأ، نستخدم معرف مؤقت
      final tempId = sha256
          .convert(
              utf8.encode(DateTime.now().millisecondsSinceEpoch.toString()))
          .toString();

      return {
        'device_id': tempId,
        'platform': 'unknown',
        'model': 'unknown',
        'brand': 'unknown',
      };
    }
  }

  // تعديل دالة التسجيل لعدم إرسال معلومات الجهاز في البداية
  static Future<Map<String, dynamic>> register({
    required String email,
    required String password,
  }) async {
    try {
      await supabase.auth.signOut();

      // 1. التحقق من وجود المستخدم أولاً - تم تغيير اسم الدالة
      final existingUser = await supabase
          .from('auth_users')
          .select()
          .eq('email', email)
          .maybeSingle();

      if (existingUser != null) {
        // التحقق من حالة التفعيل
        final isVerified = existingUser['verification_completed'] ?? false;

        if (isVerified) {
          return {
            'status': 'exists_verified',
            'message': 'هذا الحساب موجود بالفعل، يرجى تسجيل الدخول',
            'email': email,
          };
        } else {
          // إعادة إرسال رمز التحقق للمستخدم غير المفعل
          await supabase.auth.resend(
            type: OtpType.signup,
            email: email,
          );
          return {
            'status': 'exists_unverified',
            'message': 'الحساب موجود ولكن غير مفعل، تم إرسال رمز تحقق جديد',
            'email': email,
          };
        }
      }

      // 2. إنشاء حساب جديد إذا لم يكن موجوداً
      final authResponse = await supabase.auth.signUp(
        email: email,
        password: password,
      );

      if (authResponse.user == null) {
        throw 'فشل في إنشاء الحساب';
      }

      // استخدام الدالة الجديدة create_initial_user_record
      await supabase.rpc(
        'create_initial_user_record',
        params: {
          'user_id': authResponse.user!.id,
          'user_email': email,
        },
      );

      // 4. إرجاع نتيجة النجاح
      return {
        'status': 'success',
        'message': 'تم إرسال رمز التحقق إلى بريدك الإلكتروني',
        'email': email,
      };
    } catch (e) {
      print('Error in register: $e'); // إضافة للتحقق من نوع الخطأ
      if (e is AuthException) {
        if (e.statusCode == 429 || e.message.contains('rate limit')) {
          return _getArabicErrorMessage(e.message);
        }
        if (e.message.contains('User already registered')) {
          return {
            'status': 'exists_verified',
            'message': 'هذا البريد الإلكتروني مسجل بالفعل، يرجى تسجيل الدخول',
            'email': email,
          };
        }
        throw 'حدث خطأ في التسجيل: ${e.message}';
      }
      throw 'حدث خطأ غير متوقع في التسجيل';
    }
  }

  // دالة التحقق من وجود البريد الإلكتروني
  static Future<Map<String, dynamic>> _checkEmailExists(String email) async {
    try {
      // التحقق مباشرة من جدول auth_users
      final user = await supabase
          .from('auth_users')
          .select()
          .eq('email', email)
          .single();

      return {
        'exists': true,
        'id': user['id'],
        'isVerified': user['verification_completed'] ?? false,
      };
    } catch (e) {
      print('Error in _checkEmailExists: $e');
      return {
        'exists': false,
        'id': null,
        'isVerified': false,
      };
    }
  }

  // دالة تسجيل الدخول
  static Future<Map<String, dynamic>> signIn({
    required String email,
    required String password,
  }) async {
    try {
      // 1. محاولة تسجيل الدخول مباشرة
      final response = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user == null) {
        return {
          'status': 'invalid_credentials',
          'message': 'البريد الإلكتروني أو كلمة المرور غير صحيحة',
        };
      }

      // حفظ بيانات الجلسة
      await _saveSession(response.session);

      // 2. التحقق من حالة التفعيل
      final userStatus = await supabase
          .from('auth_users')
          .select('verification_completed, device_id, device_platform')
          .eq('id', response.user!.id)
          .single();

      final isVerified = userStatus['verification_completed'] ?? false;

      if (!isVerified) {
        await supabase.auth.resend(
          type: OtpType.signup,
          email: email,
        );

        return {
          'status': 'verification_needed',
          'message': 'يجب التحقق من بريدك الإلكتروني أولاً',
          'email': email,
        };
      }

      // التحقق مما إذا كان المستخدم هو المسؤول
      final isAdmin = email.toLowerCase() == EnvConfig.adminEmail.toLowerCase();

      // الحصول على معلومات الجهاز
      final deviceInfo = await _getDeviceInfo();

      // إذا كان المستخدم ليس مسؤولاً، نتحقق من الجهاز
      if (!isAdmin) {
        if (userStatus['device_id'] != deviceInfo['device_id'] ||
            userStatus['device_platform'] != deviceInfo['platform']) {
          return {
            'status': 'unauthorized_device',
            'message':
                'هذا الجهاز غير مصرح له بتسجيل الدخول. يرجى استخدام الجهاز الأصلي',
          };
        }
      }

      // تحديث آخر تسجيل دخول
      await supabase.rpc(
        'record_signin',
        params: {
          'user_id': response.user!.id,
          'device_identifier': deviceInfo['device_id'],
          'p_platform': deviceInfo['platform']
        },
      );

      return {
        'status': 'success',
        'user': response.user,
        'session': response.session,
        'is_admin': isAdmin,
        'message': 'تم تسجيل الدخول بنجاح'
      };
    } catch (e) {
      print('Error in signIn: $e');

      if (e.toString().contains('هذا الجهاز غير مصرح له')) {
        return {
          'status': 'unauthorized_device',
          'message':
              'هذا الجهاز غير مصرح له بتسجيل الدخول. يرجى استخدام الجهاز الأصلي',
        };
      }

      if (e is AuthException) {
        if (e.message.contains('Invalid login credentials')) {
          return {
            'status': 'invalid_credentials',
            'message': 'البريد الإلكتروني أو كلمة المرور غير صحيحة',
          };
        }
        if (e.message.contains('Email not confirmed')) {
          return {
            'status': 'verification_needed',
            'message': 'يجب التحقق من بريدك الإلكتروني أولاً',
            'email': email,
          };
        }

        // استخدام الدالة المساعدة لمعالجة رسائل التأخير بشكل موحد
        if (e.message.contains('rate limit') ||
            e.message.contains('Too many requests')) {
          return _getArabicErrorMessage(e.message);
        }
      }

      String errorMessage = 'حدث خطأ غير متوقع في تسجيل الدخول';
      if (e.toString().contains('not found') ||
          e.toString().contains('no rows')) {
        errorMessage = 'هذا الحساب غير موجود، يرجى التسجيل أولاً';
      }

      return {
        'status': 'error',
        'message': errorMessage,
      };
    }
  }

  // دالة جديدة لحفظ بيانات الجلسة
  static Future<void> _saveSession(Session? session) async {
    if (session != null) {
      final sessionData = {
        'access_token': session.accessToken,
        'refresh_token': session.refreshToken,
        // يمكن إضافة أي بيانات إضافية تحتاجها
      };
      await _storage.write(
        key: _sessionKey,
        value: json.encode(sessionData),
      );
    }
  }

  // دالة جديدة لاستعادة الجلسة المحفوظة
  static Future<bool> restoreSession() async {
    try {
      final persistedSession = await _storage.read(key: _sessionKey);

      if (persistedSession != null) {
        final sessionData = json.decode(persistedSession);
        final response =
            await supabase.auth.setSession(sessionData['access_token']);
        return response.session != null;
      }

      return false;
    } catch (e) {
      print('Error restoring session: $e');
      return false;
    }
  }

  // دالة التحقق من الجهاز
  static Future<Map<String, dynamic>> _verifyDevice(String userId) async {
    try {
      final deviceInfo = await _getDeviceInfo();
      final currentFingerprint = deviceInfo['device_fingerprint'];

      final devices = await supabase
          .from('user_devices')
          .select()
          .eq('user_id', userId)
          .eq('is_active', true)
          .eq('device_fingerprint', currentFingerprint);

      if (devices.isEmpty) {
        return {
          'verified': false,
          'message': 'هذا الجهاز غير مسجل لهذا الحساب'
        };
      }

      return {'verified': true};
    } catch (e) {
      print('Error verifying device: $e');
      return {'verified': false, 'message': 'حدث خطأ في التحقق من الجهاز'};
    }
  }

  // تعديل دالة التحقق من OTP لإضافة معلومات الجهاز بعد التحقق
  static Future<Map<String, dynamic>> verifyOTP({
    required String email,
    required String token,
  }) async {
    try {
      final response = await supabase.auth.verifyOTP(
        email: email,
        token: token,
        type: OtpType.signup,
      );

      if (response.user != null) {
        try {
          final deviceInfo = await _getDeviceInfo();
          await supabase.rpc(
            'update_device_info',
            params: {
              'user_id': response.user!.id,
              'device_identifier': deviceInfo['device_id'],
              'p_platform': deviceInfo['platform']
            },
          );

          final userRecord = await supabase
              .from('auth_users')
              .select()
              .eq('id', response.user!.id)
              .single();

          if (userRecord['verification_completed'] == true) {
            return {
              'status': 'success',
              'message': 'تم التحقق بنجاح',
              'user': response.user,
            };
          }
        } catch (updateError) {
          print('خطأ في تحديث معلومات الجهاز: $updateError');
          return {
            'status': 'error',
            'message': 'نجح التحقق لكن فشل تحديث معلومات الجهاز',
          };
        }
      }
    } catch (e) {
      print('خطأ في التحقق: $e');

      if (e is AuthException) {
        final errorMessage = e.message.toLowerCase();
        final errorStatus = e.statusCode ?? 0;

        // تحسين التحقق من نوع الخطأ
        if (errorStatus == 401 && !errorMessage.contains('expired')) {
          return {
            'status': 'invalid_otp',
            'message':
                'الرمز الذي أدخلته غير صحيح. يرجى التأكد من الرمز وإعادة المحاولة',
          };
        }

        // التحقق من انتهاء الصلاحية عن طريق الرسالة وكود الحالة معاً
        if ((errorStatus == 401 || errorStatus == 400) &&
            (errorMessage.contains('expired') ||
                errorMessage.contains('token has expired') ||
                errorMessage.contains('token is expired'))) {
          return {
            'status': 'expired',
            'message': 'انتهت صلاحية الرمز. يرجى طلب رمز جديد',
          };
        }

        // التحقق من تجاوز عدد المحاولات
        if (errorMessage.contains('rate limit')) {
          return {
            'status': 'rate_limit',
            'message':
                'تم تجاوز عدد المحاولات المسموح بها. يرجى الانتظار 5 دقائق',
            'waitTime': 300,
          };
        }
      }
    }

    // في حالة الفشل بدون سبب محدد
    return {
      'status': 'invalid',
      'message': 'الرمز غير صحيح. يرجى المحاولة مرة أخرى',
    };
  }

  // دالة إعادة إرسال رمز التحقق
  static Future<String> resendOTP({
    required String email,
  }) async {
    try {
      // إضافة تأخير 3 ثواني قبل إعادة الإرسال
      await Future.delayed(const Duration(seconds: 3));

      // استخدام نوع OTP الصحيح للتحقق من البريد
      final response = await supabase.auth.resend(
        type: OtpType.signup,
        email: email,
      );

      return 'تم إرسال رمز جديد بنجاح. يمكنك إرسال 30 طلب كحد أقصى في الساعة';
    } catch (e) {
      if (e.toString().contains('rate limit') ||
          e.toString().contains('Too many requests')) {
        throw 'تم تجاوز الحد المسموح به. يرجى الانتظار 5 دقائق قبل المحاولة مرة أخرى';
      }
      throw 'حدث خطأ في إعادة إرسال الرمز: ${e.toString()}';
    }
  }

  // دالة إعادة إرسال التحقق من البريد الإلكتروني
  static Future<void> resendVerificationEmail(String email) async {
    try {
      // إضافة تأخير لتجنب الإرسال المتكرر
      await Future.delayed(const Duration(seconds: 3));

      // استخدام resend OTP بدلاً من resetPasswordForEmail
      await supabase.auth.resend(
        type: OtpType.signup,
        email: email,
      );
    } catch (e) {
      if (e.toString().contains('rate limit')) {
        throw 'يرجى الانتظار قبل إعادة طلب رمز التحقق';
      }
      if (e.toString().contains('Invalid email')) {
        throw 'البريد الإلكتروني غير صحيح';
      }
      throw 'حدث خطأ في إرسال رمز التحقق: ${e.toString()}';
    }
  }

  // تحديث دالة التحقق من صلاحية الجلسة
  static Future<bool> hasValidSession() async {
    try {
      final session = supabase.auth.currentSession;
      if (session == null) return false;

      final deviceInfo = await _getDeviceInfo();
      final user = await supabase
          .from('auth_users')
          .select()
          .eq('id', session.user.id)
          .single();

      final isValidDevice = user['device_id'] == deviceInfo['device_id'];
      final isValidPlatform = user['platform_type'] == deviceInfo['platform'];

      return user['verification_completed'] == true &&
          isValidDevice &&
          isValidPlatform;
    } catch (e) {
      print('Error in hasValidSession: $e');
      return false;
    }
  }

  // دالة معالجة أخطاء المصادقة
  static void _handleAuthError(dynamic error) {
    if (error is AuthException) {
      switch (error.message) {
        case 'Invalid login credentials':
          throw 'البريد الإلكتروني أو كلمة المرور غير صحيحة';
        case 'Invalid verification code':
          throw 'رمز التحقق غير صحيح';
        default:
          throw 'حدث خطأ في المصادقة: ${error.message}';
      }
    }
    throw 'حدث خطأ غير متوقع: $error';
  }

  // دوال إضافية للتحكم في الجلسة
  static Future<void> signOut() async {
    await supabase.auth.signOut();
    await _storage.delete(key: _sessionKey); // حذف بيانات الجلسة المحفوظة
  }

  static Future<bool> isLoggedIn() async {
    return supabase.auth.currentSession != null;
  }

  static Future<bool> isEmailVerified(String email) async {
    try {
      final user = supabase.auth.currentUser;
      return user?.emailConfirmedAt != null;
    } catch (e) {
      return false;
    }
  }

  static Future<void> registerDevice(
      String userId, Map<String, dynamic> deviceInfo) async {
    try {
      final deviceRecord = {
        'user_id': userId,
        'device_fingerprint': deviceInfo['device_fingerprint'],
        'hardware_id': deviceInfo['hardware_id'],
        'device_model': deviceInfo['device_model'],
        'device_brand': deviceInfo['device_brand'],
        'os_version': deviceInfo['os_version'],
        'is_active': true,
      };
      await supabase.from('user_devices').upsert(deviceRecord);
    } catch (e) {
      print('Error registering device: $e');
      rethrow;
    }
  }

  static String getDeviceErrorMessage(String platform) {
    switch (platform) {
      case 'web':
        return 'لا يمكن تسجيل الدخول من متصفح مختلف';
      case 'android':
      case 'ios':
        return 'لا يمكن تسجيل الدخول من جهاز مختلف';
      case 'windows':
      case 'macos':
      case 'linux':
        return 'لا يمكن تسجيل الدخول من جهاز كمبيوتر مختلف';
      default:
        return 'لا يمكن تسجيل الدخول من هذا الجهاز';
    }
  }

  // دالة إرسال رابط إعادة تعيين كلمة المرور
  static Future<Map<String, dynamic>> resetPassword(String email) async {
    try {
      await supabase.auth.resetPasswordForEmail(
        email,
      );

      return {
        'status': 'success',
        'message': 'تم إرسال رابط إعادة تعيين كلمة المرور إلى بريدك الإلكتروني',
      };
    } catch (e) {
      print('Error in resetPassword: $e');
      if (e is AuthException) {
        if (e.message.contains('rate limit')) {
          return {
            'status': 'rate_limit',
            'message': 'يرجى الانتظار قليلاً قبل إعادة المحاولة',
          };
        }
        if (e.message.contains('Email not found')) {
          return {
            'status': 'error',
            'message': 'البريد الإلكتروني غير مسجل في النظام',
          };
        }
      }
      return {
        'status': 'error',
        'message': 'حدث خطأ غير متوقع',
      };
    }
  }

  /// دالة تحديث كلمة المرور
  static Future<void> updatePassword(String token, String newPassword) async {
    try {
      final response = await supabase.auth.updateUser(
        UserAttributes(
          password: newPassword,
        ),
      );

      if (response.user == null) {
        throw 'فشل في تحديث كلمة المرور';
      }
    } catch (e) {
      if (e.toString().contains('token expired')) {
        throw 'انتهت صلاحية الرابط. يرجى طلب رابط جديد';
      }
      throw 'حدث خطأ في تحديث كلمة المرور';
    }
  }

  // إرسال رمز OTP لإعادة تعيين كلمة المرور
  static Future<void> sendPasswordResetOTP(String email) async {
    try {
      await supabase.auth.resetPasswordForEmail(
        email,
        redirectTo: null,
      );
    } catch (e) {
      if (e.toString().contains('rate limit')) {
        throw 'يرجى الانتظار قبل إعادة المحاولة';
      }
      throw 'حدث خطأ في إرسال رمز التحقق';
    }
  }

  // التحقق من رمز OTP
  static Future<bool> verifyPasswordResetOTP({
    required String email,
    required String token,
  }) async {
    try {
      final response = await supabase.auth.verifyOTP(
        email: email,
        token: token,
        type: OtpType.recovery,
      );
      return response.user != null;
    } catch (e) {
      throw 'رمز التحقق غير صحيح';
    }
  }

  // تحديث كلمة المرور باستخدام OTP
  static Future<void> updatePasswordWithOTP({
    required String email,
    required String token,
    required String newPassword,
  }) async {
    try {
      final response = await supabase.auth.updateUser(
        UserAttributes(password: newPassword),
      );

      if (response.user == null) {
        throw 'فشل تحديث كلمة المرور';
      }
    } catch (e) {
      throw 'حدث خطأ في تحديث كلمة المرور';
    }
  }

  // إضافة دالة للتحقق من وجود جلسة نشطة
  static Future<bool> hasActiveSession() async {
    final currentSession = supabase.auth.currentSession;
    if (currentSession != null) {
      return true;
    }
    return await restoreSession();
  }

  // إضافة دالة معالجة رسائل الخطأ بالعربية
  static Map<String, dynamic> _getArabicErrorMessage(String error) {
    if (error.contains('too many requests') || error.contains('rate limit')) {
      return {
        'status': 'rate_limit',
        'message': 'يرجى الانتظار 5 دقائق قبل المحاولة مرة أخرى',
      };
    }
    return {
      'status': 'error',
      'message': 'حدث خطأ غير متوقع',
    };
  }
}
