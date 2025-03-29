import 'package:flutter/material.dart';

/// نموذج خيار المشغل - يحتوي على معلومات المشغل
class PlayerOption {
  /// المعرف الفريد للمشغل
  final String id;

  /// اسم المشغل المعروض في الواجهة
  final String name;

  /// وصف قصير للمشغل (اختياري)
  final String? description;

  /// أيقونة المشغل
  final IconData icon;

  /// لون المشغل المميز (اختياري)
  final Color? color;

  /// ما إذا كان هذا المشغل يدعم DRM
  final bool supportsDrm;

  /// ما إذا كان هذا المشغل يتطلب مكتبات خارجية إضافية
  final bool requiresExternalDependencies;

  const PlayerOption({
    required this.id,
    required this.name,
    this.description,
    required this.icon,
    this.color,
    this.supportsDrm = false,
    this.requiresExternalDependencies = false,
  });
}
