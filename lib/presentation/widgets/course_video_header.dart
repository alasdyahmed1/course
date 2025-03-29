import 'package:flutter/material.dart';
import 'package:mycourses/core/constants/app_text_styles.dart';
import 'package:mycourses/presentation/widgets/player_selector_widget.dart';

class CourseVideoHeader extends StatelessWidget {
  /// عنوان الكورس
  final String title;

  /// استدعاء عند النقر على زر الرجوع
  final VoidCallback onBack;

  /// استدعاء عند النقر على زر التحديث
  final VoidCallback onRefresh;

  /// المشغل المحدد حالياً
  final String selectedPlayerId;

  /// استدعاء عند تغيير المشغل
  final Function(String) onPlayerChanged;

  /// ما إذا كان الفيديو الحالي محمي بتقنية DRM
  final bool isDrmProtected;

  const CourseVideoHeader({
    super.key,
    required this.title,
    required this.onBack,
    required this.onRefresh,
    required this.selectedPlayerId,
    required this.onPlayerChanged,
    this.isDrmProtected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      child: Row(
        children: [
          // زر الرجوع
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: onBack,
            tooltip: 'رجوع',
          ),

          // عنوان الكورس
          Expanded(
            child: Text(
              title,
              style: AppTextStyles.titleMedium.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // إذا كان الفيديو محمي بتقنية DRM، نعرض أيقونة إضافية
          if (isDrmProtected)
            const Tooltip(
              message: 'فيديو محمي بتقنية DRM',
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Icon(
                  Icons.security,
                  color: Colors.orange,
                  size: 16,
                ),
              ),
            ),

          // زر اختيار المشغل
          PlayerSelectorWidget(
            selectedPlayerId: selectedPlayerId,
            onPlayerChanged: onPlayerChanged,
            isDrmProtected: isDrmProtected,
          ),

          // زر التحديث
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: onRefresh,
            tooltip: 'تحديث',
          ),
        ],
      ),
    );
  }
}
