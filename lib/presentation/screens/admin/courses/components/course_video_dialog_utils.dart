import 'package:flutter/material.dart';
import 'package:mycourses/core/utils/drm_helper.dart';
import 'package:mycourses/core/utils/video_diagnostics.dart';
import 'package:mycourses/models/course_video.dart';
import 'package:mycourses/presentation/screens/admin/courses/direct_video_player_screen.dart';
import 'package:mycourses/presentation/screens/admin/courses/modern_video_player_screen.dart';
import 'package:mycourses/presentation/screens/admin/courses/premium_video_player_screen.dart';
import 'package:mycourses/presentation/screens/admin/courses/simple_video_player_screen.dart';
import 'package:mycourses/presentation/screens/admin/courses/video_player_screen.dart';
import 'package:mycourses/presentation/screens/admin/courses/web_video_player_screen.dart';

/// Utility class for dialog operations
class CourseVideoDialogUtils {
  /// Shows a dialog with player options
  static void showPlayerOptionsDialog(
    BuildContext context,
    CourseVideo video,
    bool isDrmProtected,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            if (isDrmProtected)
              const Padding(
                padding: EdgeInsets.only(right: 8.0),
                child: Icon(Icons.security, color: Colors.orange, size: 20),
              ),
            Text(
                isDrmProtected ? 'فيديو محمي بتقنية DRM' : 'اختر مشغل الفيديو'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isDrmProtected)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'هذا الفيديو محمي بتقنية MediaCage DRM',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      DrmHelper.getDrmPlayerRecommendation(),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange.shade800,
                      ),
                    ),
                  ],
                ),
              )
            else
              const Text(
                'يمكنك اختيار نوع المشغل الذي ترغب في استخدامه لتشغيل الفيديو.',
              ),
          ],
        ),
        actions: [
          // DRM protected video options
          if (isDrmProtected)
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => WebVideoPlayerScreen(video: video),
                  ),
                );
              },
              icon: const Icon(Icons.security),
              label: const Text('مشغل iframe للفيديوهات المحمية'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
            ),

          // Regular player options
          if (!isDrmProtected) ...[
            // Modern player
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ModernVideoPlayerScreen(video: video),
                  ),
                );
              },
              icon: const Icon(Icons.smart_display),
              label: const Text('المشغل الحديث'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromRGBO(0, 128, 255, 1),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),

            // Premium player
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PremiumVideoPlayerScreen(video: video),
                  ),
                );
              },
              icon: const Icon(Icons.hd),
              label: const Text('المشغل المتطور'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),

            const Divider(height: 16),

            // Legacy players
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => VideoPlayerScreen(video: video),
                  ),
                );
              },
              child: const Text('مشغل الويب'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DirectVideoPlayerScreen(video: video),
                  ),
                );
              },
              child: const Text('مشغل Chewie'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SimpleVideoPlayerScreen(video: video),
                  ),
                );
              },
              child: const Text('مشغل بسيط'),
            ),
          ],

          // Diagnostic option
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              VideoDiagnostics.showDiagnosticsDialog(context, video.videoId);
            },
            child: const Text('تشخيص المشكلة'),
          ),
        ],
      ),
    );
  }

  /// Shows a delete confirmation dialog
  static Future<bool> showDeleteConfirmationDialog(
    BuildContext context,
    String title,
    String content,
  ) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(content),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('إلغاء'),
              ),
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red,
                ),
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('حذف'),
              ),
            ],
          ),
        ) ??
        false;
  }

  /// Shows a file delete confirmation dialog with warning
  static Future<bool> showFileDeleteConfirmationDialog(
    BuildContext context,
    String fileName,
  ) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('تأكيد الحذف'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('هل أنت متأكد من حذف الملف "$fileName"؟'),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded,
                          color: Colors.red.shade700, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'سيتم حذف الملف نهائياً من الخادم ولا يمكن استعادته!',
                          style: TextStyle(
                            color: Colors.red.shade700,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('إلغاء'),
              ),
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red,
                ),
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('حذف نهائياً'),
              ),
            ],
          ),
        ) ??
        false;
  }

  /// Shows a loading dialog with message
  static void showLoadingDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(message),
          ],
        ),
      ),
    );
  }

  /// Shows a snackbar with message
  static void showSnackBar(
    BuildContext context,
    String message, {
    Color backgroundColor = Colors.black,
    Duration duration = const Duration(seconds: 2),
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        duration: duration,
      ),
    );
  }
}
