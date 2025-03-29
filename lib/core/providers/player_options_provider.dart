import 'package:flutter/material.dart';
import 'package:mycourses/core/models/player_option.dart';

/// مزود خيارات المشغلات المتاحة في التطبيق
class PlayerOptionsProvider {
  /// الحصول على قائمة بجميع خيارات المشغلات المتاحة
  static List<PlayerOption> getAvailablePlayerOptions() {
    return [
      const PlayerOption(
        id: 'iframe',
        name: 'مشغل الويب',
        description: 'مشغل الويب المدمج (يدعم الفيديوهات المحمية DRM)',
        icon: Icons.web,
        color: Colors.blue,
        supportsDrm: true,
      ),
      const PlayerOption(
        id: 'modern',
        name: 'المشغل الحديث',
        description: 'مشغل فيديو بواجهة حديثة',
        icon: Icons.smart_display,
        color: Colors.teal,
      ),
      const PlayerOption(
        id: 'premium',
        name: 'المشغل المتطور',
        description: 'مشغل فيديو متطور - يتطلب مكتبات إضافية',
        icon: Icons.hd,
        color: Colors.deepPurple,
        requiresExternalDependencies: true,
      ),
      const PlayerOption(
        id: 'direct',
        name: 'مشغل Chewie',
        description: 'مشغل فيديو Chewie المباشر',
        icon: Icons.ondemand_video,
        color: Colors.orange,
      ),
      const PlayerOption(
        id: 'simple',
        name: 'المشغل البسيط',
        description: 'مشغل فيديو بسيط وخفيف',
        icon: Icons.play_circle_outline,
        color: Colors.green,
      ),
    ];
  }

  /// الحصول على المشغل الافتراضي
  static PlayerOption getDefaultPlayerOption() {
    return getAvailablePlayerOptions().first;
  }

  /// البحث عن مشغل بالمعرف
  static PlayerOption getPlayerOptionById(String id) {
    return getAvailablePlayerOptions().firstWhere(
      (option) => option.id == id,
      orElse: () => getDefaultPlayerOption(),
    );
  }
}
