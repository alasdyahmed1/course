import 'dart:math' as Math;

import 'package:flutter/material.dart';
import 'package:mycourses/core/utils/video_diagnostics.dart';
import 'package:mycourses/models/course_video.dart';
import 'package:mycourses/presentation/screens/admin/courses/direct_video_player_screen.dart';
import 'package:mycourses/presentation/screens/admin/courses/modern_video_player_screen.dart';
import 'package:mycourses/presentation/screens/admin/courses/premium_video_player_screen.dart';
import 'package:mycourses/presentation/screens/admin/courses/simple_video_player_screen.dart';
import 'package:mycourses/presentation/screens/admin/courses/web_video_player_screen.dart';

/// Component for video player related functionality
class CourseVideoPlayerComponent {
  /// Builds the appropriate player based on selected type
  static Widget buildPlayerByType({
    required BuildContext context,
    required CourseVideo? selectedVideo,
    required String playerType,
    required Duration startPosition,
    required bool isNavigating,
    required Map<String, Duration> videoPositions,
    required CourseVideo? Function() findPreviousVideo,
    required CourseVideo? Function() findNextVideo,
    required VoidCallback navigateToPreviousVideo,
    required VoidCallback navigateToNextVideo,
    required Function(dynamic) onPlayerCreated,
    required Function(Duration) onPositionChanged,
  }) {
    if (selectedVideo == null) return const SizedBox.shrink();

    // استخدام مفتاح فريد لكن بدون استخدام timestamp لتجنب إعادة الإنشاء المستمرة
    // استخدم معرّف الفيديو ونوع المشغل فقط
    final uniquePlayerKey = ValueKey('player_${selectedVideo.id}_$playerType');

    // Use saved position or default
    final Duration position = isNavigating
        ? startPosition
        : (videoPositions[selectedVideo.id] ?? startPosition);

    // Check for previous/next video
    final hasPrevious = findPreviousVideo() != null;
    final hasNext = findNextVideo() != null;

    debugPrint(
        '🎬 بناء مشغل فيديو جديد للفيديو: ${selectedVideo.id}, نوع المشغل: $playerType');

    // تأكد من أن دوال التنقل بين الفيديوهات آمنة
    VoidCallback? safeNavigateNext = hasNext
        ? () {
            debugPrint("تم طلب الانتقال للفيديو التالي");
            navigateToNextVideo();
          }
        : null;

    VoidCallback? safeNavigatePrevious = hasPrevious
        ? () {
            debugPrint("تم طلب الانتقال للفيديو السابق");
            navigateToPreviousVideo();
          }
        : null;

    // إحاطة المشغل في FutureBuilder لتأخير إنشائه قليلًا
    // هذا سيمنع إنشاء المشغلات المتعددة في نفس الوقت
    return KeyedSubtree(
      key: uniquePlayerKey,
      child: Builder(builder: (builderContext) {
        try {
          // استخدام RepaintBoundary لعزل إعادة الرسم والتحديثات
          return RepaintBoundary(
            child: _buildPlayerWidget(
              context: builderContext,
              selectedVideo: selectedVideo,
              playerType: playerType,
              position: position,
              hasPrevious: hasPrevious,
              hasNext: hasNext,
              safeNavigatePrevious: safeNavigatePrevious,
              safeNavigateNext: safeNavigateNext,
              onPlayerCreated: onPlayerCreated,
              onPositionChanged: onPositionChanged,
            ),
          );
        } catch (e) {
          debugPrint('خطأ في إنشاء مشغل الفيديو: $e');
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 32),
                const SizedBox(height: 8),
                Text(
                  'خطأ في تحميل المشغل: ${e.toString().substring(0, Math.min(50, e.toString().length))}...',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    // استخدام مشغل بديل
                    try {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DirectVideoPlayerScreen(
                            video: selectedVideo,
                            startPosition: position,
                          ),
                        ),
                      );
                    } catch (e) {
                      debugPrint('خطأ في تحميل المشغل البديل: $e');
                    }
                  },
                  child: const Text('استخدام مشغل بديل'),
                ),
              ],
            ),
          );
        }
      }),
    );
  }

  // استخدام دالة منفصلة لإنشاء الويدجت الفعلي - هذا يمنع إنشاء كائنات Tooltip متعددة
  static Widget _buildPlayerWidget({
    required BuildContext context,
    required CourseVideo selectedVideo,
    required String playerType,
    required Duration position,
    required bool hasPrevious,
    required bool hasNext,
    required VoidCallback? safeNavigatePrevious,
    required VoidCallback? safeNavigateNext,
    required Function(dynamic) onPlayerCreated,
    required Function(Duration) onPositionChanged,
  }) {
    switch (playerType) {
      case 'direct':
        return DirectVideoPlayerScreen(
          video: selectedVideo,
          embedded: true,
          startPosition: position,
          onPlayerCreated: onPlayerCreated,
          onPositionChanged: onPositionChanged,
          onNextVideo: safeNavigateNext,
          onPreviousVideo: safeNavigatePrevious,
        );
      case 'iframe':
        return WebVideoPlayerScreen(
          video: selectedVideo,
          embedded: true,
          startPosition: position,
          hasNextVideo: hasNext,
          hasPreviousVideo: hasPrevious,
          onNextVideo: safeNavigateNext,
          onPreviousVideo: safeNavigatePrevious,
          onPlayerCreated: onPlayerCreated,
          onPositionChanged: onPositionChanged,
        );
      case 'modern':
        return ModernVideoPlayerScreen(
          video: selectedVideo,
          embedded: true,
          startPosition: position,
          onPlayerCreated: onPlayerCreated,
          onPositionChanged: onPositionChanged,
        );
      case 'premium':
        return PremiumVideoPlayerScreen(
          video: selectedVideo,
          embedded: true,
          startPosition: position,
          onPlayerCreated: onPlayerCreated,
          onPositionChanged: onPositionChanged,
        );
      case 'simple':
        return SimpleVideoPlayerScreen(
          video: selectedVideo,
          embedded: true,
        );
      case 'diagnose':
        // للتشخيص، عرض أداة تشخيص
        Future.microtask(() {
          if (scaffoldContext is BuildContext) {
            VideoDiagnostics.showDiagnosticsDialog(
                scaffoldContext as BuildContext, selectedVideo.videoId);
          }
        });
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.bug_report,
                  size: 48, color: Colors.white.withOpacity(0.7)),
              const SizedBox(height: 16),
              const Text(
                'تشخيص مشكلة الفيديو',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ],
          ),
        );
      default:
        return const Center(
          child: Text('اختر نوع المشغل', style: TextStyle(color: Colors.white)),
        );
    }
  }
}

// A global key that we use for the dialog context
final GlobalKey<ScaffoldState> scaffoldContext = GlobalKey<ScaffoldState>();
