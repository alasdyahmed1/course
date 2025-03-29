import 'package:flutter/material.dart';

/// مساعد للتعامل مع الشاشات المختلفة الأحجام
class ResponsiveHelper {
  /// التحقق إذا كانت الشاشة صغيرة (أقل من 360 بكسل عرض)
  static bool isSmallScreen(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return size.width < 360 || size.height < 600;
  }

  /// التحقق إذا كان الجهاز صغيراً وبطيئاً (للتحسينات)
  static bool isLowEndDevice(BuildContext context) {
    // صغير الشاشة مع كثافة بكسل عالية غالباً جهاز ضعيف الأداء
    final size = MediaQuery.of(context).size;
    final pixelRatio = MediaQuery.of(context).devicePixelRatio;

    return size.width < 360 && pixelRatio > 2.5;
  }

  /// الحصول على حجم خط مناسب للشاشة الحالية
  static double getAdaptiveFontSize(BuildContext context, double baseFontSize) {
    final width = MediaQuery.of(context).size.width;

    if (width < 320) {
      return baseFontSize - 2; // تخفيض حجم الخط للشاشات الصغيرة جداً
    } else if (width < 360) {
      return baseFontSize - 1; // تخفيض بسيط للشاشات الصغيرة
    } else {
      return baseFontSize; // الحجم الافتراضي
    }
  }

  /// الحصول على مقاس الأيقونات المناسب للشاشة
  static double getAdaptiveIconSize(BuildContext context, double baseIconSize) {
    final width = MediaQuery.of(context).size.width;

    if (width < 320) {
      return baseIconSize - 4; // تصغير الأيقونات للشاشات الصغيرة جداً
    } else if (width < 360) {
      return baseIconSize - 2; // تصغير بسيط للشاشات الصغيرة
    } else {
      return baseIconSize; // الحجم الافتراضي
    }
  }

  /// الحصول على حواف مناسبة للشاشة
  static EdgeInsets getAdaptivePadding(
      BuildContext context, EdgeInsets basePadding) {
    final width = MediaQuery.of(context).size.width;

    if (width < 320) {
      return basePadding / 2; // نصف الحواف للشاشات الصغيرة جداً
    } else if (width < 360) {
      return basePadding * 0.75; // تقليل الحواف للشاشات الصغيرة
    } else {
      return basePadding; // الحواف الافتراضية
    }
  }
}

/// امتداد على EdgeInsets للحصول على حواف متناسبة
extension EdgeInsetsExtension on EdgeInsets {
  /// تقسيم الحواف بقيمة معينة
  EdgeInsets operator /(double value) {
    return EdgeInsets.only(
      top: top / value,
      right: right / value,
      bottom: bottom / value,
      left: left / value,
    );
  }

  /// ضرب الحواف بقيمة معينة
  EdgeInsets operator *(double value) {
    return EdgeInsets.only(
      top: top * value,
      right: right * value,
      bottom: bottom * value,
      left: left * value,
    );
  }
}
