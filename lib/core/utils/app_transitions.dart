import 'package:flutter/material.dart';

/// Tags للانتقالات المشتركة بين الشاشات
class HeroTags {
  // تعديل الأسماء لتكون أكثر وضوحاً
  static const String emailField = 'auth_email_field';
  static const String passwordField = 'auth_password_field';
  static const String actionButton = 'auth_action_button';
  static const String pageTitle = 'auth_page_title';
  static const String browseText = 'browse_text'; // لنص تصفح الكورسات
  static const String authAnimation = 'auth_animation'; // للأيقونة المتحركة
}

/// أنواع الانتقالات المتوفرة
enum TransitionType {
  fadeIn,
  slideUp,
  slideDown,
  slideLeft,
  slideRight,
  scale,
  rotate,
  size,
  rightToLeft,
  leftToRight,
  topToBottom,
  bottomToTop,
  fade,
  dissolve
}

class AppTransitions {
  // المدة الافتراضية للانتقالات حسب Figma
  static const Duration defaultDuration = Duration(milliseconds: 300);

  /// انتقال Figma Smart
  static PageRouteBuilder smart({
    required Widget page,
    Curve curve = Curves.easeOut,
    Duration duration = defaultDuration,
  }) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: duration,
      reverseTransitionDuration: duration,
      maintainState: true,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: curve,
        );

        return FadeTransition(
          opacity: Tween<double>(begin: 0.0, end: 1.0).animate(curvedAnimation),
          child: Transform(
            transform: Matrix4.identity()
              ..translate(0.0, 10.0 * (1 - curvedAnimation.value))
              ..scale(Tween<double>(begin: 0.95, end: 1.0)
                  .evaluate(curvedAnimation)),
            alignment: Alignment.center,
            child: child,
          ),
        );
      },
    );
  }

  /// انتقال مع تأثيرات مخصصة
  static PageRouteBuilder custom({
    required Widget page,
    required TransitionType type,
    Curve curve = Curves.easeOut,
    Duration duration = defaultDuration,
  }) {
    switch (type) {
      case TransitionType.fadeIn:
        return smart(page: page, duration: duration, curve: curve);

      case TransitionType.rightToLeft:
        return PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionDuration: duration,
          reverseTransitionDuration: duration,
          maintainState: true,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.2, 0),
                end: Offset.zero,
              ).animate(CurvedAnimation(parent: animation, curve: curve)),
              child: child,
            );
          },
        );

      case TransitionType.leftToRight:
        return PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionDuration: duration,
          reverseTransitionDuration: duration,
          maintainState: true,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(-0.2, 0),
                end: Offset.zero,
              ).animate(CurvedAnimation(parent: animation, curve: curve)),
              child: child,
            );
          },
        );

      default:
        return smart(page: page, duration: duration, curve: curve);
    }
  }

  /// انتقال مخصص لصفحة نسيت كلمة المرور
  static PageRouteBuilder forgotPassword({
    required Widget page,
    bool isReverse = false,
  }) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: const Duration(milliseconds: 500),
      reverseTransitionDuration: const Duration(milliseconds: 500),
      maintainState: true,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        var curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeInOut,
        );

        return FadeTransition(
          opacity: Tween<double>(
            begin: 0.0,
            end: 1.0,
          ).animate(curvedAnimation),
          child: SlideTransition(
            position: Tween<Offset>(
              begin:
                  isReverse ? const Offset(0.0, -0.1) : const Offset(0.0, 0.1),
              end: Offset.zero,
            ).animate(curvedAnimation),
            child: child,
          ),
        );
      },
    );
  }

  /// انتقال مخصص للتنقل بين تسجيل الدخول وإنشاء الحساب
  static PageRouteBuilder authTransition({
    required Widget page,
    bool isReverse = false,
  }) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: const Duration(milliseconds: 500),
      reverseTransitionDuration: const Duration(milliseconds: 500),
      maintainState: true,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        var curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeInOut,
        );

        return FadeTransition(
          opacity: Tween<double>(
            begin: 0.0,
            end: 1.0,
          ).animate(curvedAnimation),
          child: SlideTransition(
            position: Tween<Offset>(
              begin:
                  isReverse ? const Offset(0.0, -0.1) : const Offset(0.0, 0.1),
              end: Offset.zero,
            ).animate(curvedAnimation),
            child: child,
          ),
        );
      },
    );
  }

  /// انتقال القوائم
  static Widget list({
    required Widget child,
    required int index,
    Duration delay = defaultDuration,
  }) {
    return AnimatedBuilder(
      animation: CurvedAnimation(
        parent: const AlwaysStoppedAnimation(1.0),
        curve: Interval(
          0.1 * index,
          1.0,
          curve: Curves.easeOutCubic,
        ),
      ),
      builder: (context, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.1),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: const AlwaysStoppedAnimation(1.0),
            curve: Interval(
              0.1 * index,
              1.0,
              curve: Curves.easeOutCubic,
            ),
          )),
          child: child,
        );
      },
      child: child,
    );
  }
}
