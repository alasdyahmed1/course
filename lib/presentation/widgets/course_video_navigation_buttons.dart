import 'package:flutter/material.dart';
import 'package:mycourses/core/constants/app_colors.dart';
import 'package:mycourses/models/course_video.dart';

/// مكون يعرض أزرار التنقل بين الفيديوهات (التالي والسابق)
class CourseVideoNavigationButtons extends StatelessWidget {
  /// قائمة الفيديوهات المتاحة
  final List<CourseVideo> videos;

  /// الفيديو الحالي المحدد
  final CourseVideo? selectedVideo;

  /// وظيفة يتم استدعاؤها عند النقر على زر التالي أو السابق
  final Function(CourseVideo video) onNavigate;

  const CourseVideoNavigationButtons({
    super.key,
    required this.videos,
    required this.selectedVideo,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    // لا نعرض شيئًا إذا لم تكن هناك فيديوهات أو فيديو محدد
    if (videos.isEmpty || selectedVideo == null) {
      return const SizedBox.shrink();
    }

    // الحصول على الفيديو التالي والسابق
    final currentIndex = videos.indexWhere((v) => v.id == selectedVideo!.id);
    final hasPrevious = currentIndex > 0;
    final hasNext = currentIndex < videos.length - 1 && currentIndex >= 0;

    // استخدام القيم لإنشاء الأزرار
    final CourseVideo? previousVideo =
        hasPrevious ? videos[currentIndex - 1] : null;
    final CourseVideo? nextVideo = hasNext ? videos[currentIndex + 1] : null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // زر الانتقال للفيديو السابق
          _buildNavigationButton(
            video: previousVideo,
            icon: Icons.arrow_back_ios_rounded,
            text: 'السابق',
            isNext: false,
          ),

          // معلومات الفيديو الحالي
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Text(
                'فيديو ${currentIndex + 1} من ${videos.length}',
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),

          // زر الانتقال للفيديو التالي
          _buildNavigationButton(
            video: nextVideo,
            icon: Icons.arrow_forward_ios_rounded,
            text: 'التالي',
            isNext: true,
          ),
        ],
      ),
    );
  }

  /// إنشاء زر التنقل مع مراعاة إذا كان الفيديو متاح أم لا
  Widget _buildNavigationButton({
    required CourseVideo? video,
    required IconData icon,
    required String text,
    required bool isNext,
  }) {
    final bool isDisabled = video == null;
    final Color textColor = isDisabled ? Colors.grey : AppColors.buttonPrimary;

    // Helper method to create consistent icon
    Widget buildIcon() => Icon(
          icon,
          size: 12,
          color: textColor,
        );

    // Helper method to create consistent text
    Widget buildText() => Text(
          text,
          style: TextStyle(
            fontSize: 10,
            color: textColor,
          ),
        );

    Widget button;
    if (isNext) {
      // For "Next" button - text then icon
      button = TextButton(
        onPressed: isDisabled ? null : () => onNavigate(video),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          backgroundColor:
              isDisabled ? null : AppColors.primaryLight.withOpacity(0.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            buildText(),
            const SizedBox(width: 4),
            buildIcon(),
          ],
        ),
      );
    } else {
      // For "Previous" button - icon then text
      button = TextButton(
        onPressed: isDisabled ? null : () => onNavigate(video),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          backgroundColor:
              isDisabled ? null : AppColors.primaryLight.withOpacity(0.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            buildIcon(),
            const SizedBox(width: 4),
            buildText(),
          ],
        ),
      );
    }

    // Apply opacity for disabled state
    return isDisabled
        ? Opacity(
            opacity: 0.5,
            child: button,
          )
        : button;
  }
}
