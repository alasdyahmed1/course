import 'package:flutter/material.dart';
import 'package:mycourses/core/constants/app_colors.dart';
import 'package:mycourses/core/utils/drm_helper.dart';
import 'package:mycourses/core/utils/video_diagnostics.dart';
import 'package:mycourses/models/course_section.dart';
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

  /// Dialog to reorder a video by selecting section and position
  static Future<Map<String, dynamic>?> showReorderVideoDialog(
    BuildContext context,
    CourseVideo video,
    List<CourseSection> sections,
    Map<String, List<CourseVideo>> videosBySection,
    List<CourseVideo> uncategorizedVideos,
  ) async {
    String? selectedSectionId = video.sectionId;
    int selectedPosition = 0;

    // Get initial position based on current video location
    List<CourseVideo> currentSectionVideos =
        selectedSectionId?.isNotEmpty == true
            ? videosBySection[selectedSectionId] ?? []
            : uncategorizedVideos;

    // Find current position in section
    selectedPosition = currentSectionVideos.indexWhere((v) => v.id == video.id);
    if (selectedPosition < 0) selectedPosition = 0;

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (BuildContext context) {
        final double screenWidth = MediaQuery.of(context).size.width;
        final double screenHeight = MediaQuery.of(context).size.height;
        final bool isSmallScreen = screenWidth < 360;

        return StatefulBuilder(
          builder: (context, setState) {
            // Get current section videos for position options
            List<CourseVideo> targetSectionVideos =
                selectedSectionId?.isNotEmpty == true
                    ? videosBySection[selectedSectionId] ?? []
                    : uncategorizedVideos;

            // Find section title for display
            String currentSectionTitle = 'بدون تصنيف';
            if (selectedSectionId?.isNotEmpty == true) {
              final section = sections.firstWhere(
                (s) => s.id == selectedSectionId,
                orElse: () => CourseSection(
                  id: '',
                  courseId: '',
                  title: 'غير معروف',
                  orderNumber: 0,
                  isPublished: true,
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                ),
              );
              currentSectionTitle = section.title;
            }

            // Generate position options
            final List<Map<String, dynamic>> positionOptions = [];

            // Add beginning of section option
            positionOptions.add({
              'position': 0,
              'label': 'بداية القسم',
              'details': targetSectionVideos.isEmpty
                  ? ''
                  : '(قبل: ${targetSectionVideos.first.title})',
            });

            // Add middle positions
            for (int i = 1; i < targetSectionVideos.length; i++) {
              // Skip current video's position when moving within same section
              if (targetSectionVideos[i].id != video.id) {
                positionOptions.add({
                  'position': i,
                  'label': 'بعد: ${targetSectionVideos[i - 1].title}',
                  'details': 'قبل: ${targetSectionVideos[i].title}',
                });
              }
            }

            // Add end of section option
            if (targetSectionVideos.isNotEmpty) {
              final int endPosition = targetSectionVideos.length;

              // Only add end position if it's different from current position or section changed
              if (selectedSectionId != video.sectionId ||
                  endPosition > 0 && selectedPosition != endPosition - 1) {
                positionOptions.add({
                  'position': endPosition,
                  'label': 'نهاية القسم',
                  'details': '(بعد: ${targetSectionVideos.last.title})',
                });
              }
            } else {
              // Empty section case
              positionOptions.add({
                'position': 0,
                'label': 'القسم فارغ',
                'details': '',
              });
            }

            // Ensure position selection is valid for current section
            if (selectedPosition >= positionOptions.length) {
              selectedPosition =
                  positionOptions.isEmpty ? 0 : positionOptions.length - 1;
            }

            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Container(
                width: screenWidth > 600 ? 450 : screenWidth * 0.9,
                constraints: BoxConstraints(
                  maxHeight: screenHeight * 0.7,
                  maxWidth: 450,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header
                    Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: isSmallScreen ? 12 : 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight.withOpacity(0.1),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(12),
                          topRight: Radius.circular(12),
                        ),
                        border: Border(
                          bottom: BorderSide(
                            color: AppColors.primaryLight.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.swap_vert,
                            color: AppColors.buttonPrimary,
                            size: isSmallScreen ? 18 : 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'تغيير موضع الفيديو',
                            style: TextStyle(
                              fontSize: isSmallScreen ? 14 : 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.buttonPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Scrollable content
                    Flexible(
                      child: SingleChildScrollView(
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: isSmallScreen ? 12 : 16,
                            vertical: 16,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Video title
                              const Text(
                                'الفيديو:',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border:
                                      Border.all(color: Colors.grey.shade200),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.videocam,
                                      size: 16,
                                      color: AppColors.buttonPrimary,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        video.title,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Section Selection
                              const Text(
                                'القسم المستهدف:',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                decoration: BoxDecoration(
                                  border:
                                      Border.all(color: Colors.grey.shade300),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: ButtonTheme(
                                    alignedDropdown: true,
                                    child: DropdownButton<String?>(
                                      value: selectedSectionId,
                                      isExpanded: true,
                                      icon: const Icon(Icons.arrow_drop_down),
                                      iconSize: 24,
                                      elevation: 16,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12),
                                      style: const TextStyle(fontSize: 13),
                                      onChanged: (String? newValue) {
                                        setState(() {
                                          selectedSectionId = newValue;
                                          selectedPosition =
                                              0; // Reset position on section change
                                        });
                                      },
                                      items: [
                                        // Add sections
                                        ...sections.map((section) {
                                          return DropdownMenuItem<String?>(
                                            value: section.id,
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons.folder,
                                                  size: 16,
                                                  color: AppColors.primaryLight,
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    section.title,
                                                    style: const TextStyle(
                                                      color: Colors.black87,
                                                      fontSize: 13,
                                                    ),
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                if (section.videoCount > 0)
                                                  Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                      horizontal: 6,
                                                      vertical: 2,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color:
                                                          Colors.grey.shade100,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              10),
                                                    ),
                                                    child: Text(
                                                      '${section.videoCount}',
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        color: Colors
                                                            .grey.shade700,
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          );
                                        }),
                                        // Add uncategorized option
                                        DropdownMenuItem<String?>(
                                          value: null,
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.folder_off,
                                                size: 16,
                                                color: Colors.grey.shade600,
                                              ),
                                              const SizedBox(width: 8),
                                              const Text(
                                                'بدون تصنيف',
                                                style: TextStyle(
                                                  color: Colors.black87,
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 16),

                              // Position Selection
                              Row(
                                children: [
                                  const Text(
                                    'الموضع:',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      currentSectionTitle,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontStyle: FontStyle.italic,
                                        color: Colors.grey.shade700,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),

                              if (positionOptions.isEmpty)
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border:
                                        Border.all(color: Colors.grey.shade200),
                                  ),
                                  child: const Text(
                                    'لا توجد خيارات متاحة للموضع في هذا القسم',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontStyle: FontStyle.italic,
                                      color: Colors.grey,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                )
                              else
                                Container(
                                  decoration: BoxDecoration(
                                    border:
                                        Border.all(color: Colors.grey.shade300),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: ButtonTheme(
                                      alignedDropdown: true,
                                      child: DropdownButton<int>(
                                        value: selectedPosition <
                                                positionOptions.length
                                            ? positionOptions[selectedPosition]
                                                ['position']
                                            : positionOptions.first['position'],
                                        isExpanded: true,
                                        icon: const Icon(Icons.arrow_drop_down),
                                        iconSize: 24,
                                        elevation: 16,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12),
                                        style: const TextStyle(fontSize: 13),
                                        onChanged: (int? newValue) {
                                          if (newValue != null) {
                                            final index = positionOptions
                                                .indexWhere((option) =>
                                                    option['position'] ==
                                                    newValue);
                                            if (index >= 0) {
                                              setState(() {
                                                selectedPosition = index;
                                              });
                                            }
                                          }
                                        },
                                        items: positionOptions.map((option) {
                                          return DropdownMenuItem<int>(
                                            value: option['position'] as int,
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Row(
                                                  children: [
                                                    Icon(
                                                      option['position'] == 0
                                                          ? Icons
                                                              .vertical_align_top
                                                          : (option['position'] ==
                                                                  targetSectionVideos
                                                                      .length
                                                              ? Icons
                                                                  .vertical_align_bottom
                                                              : Icons
                                                                  .swap_vert),
                                                      size: 16,
                                                      color: AppColors
                                                          .buttonPrimary,
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Expanded(
                                                      child: Text(
                                                        option['label']
                                                            as String,
                                                        style: const TextStyle(
                                                          fontSize: 13,
                                                          color: Colors.black87,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                if (option['details'] != null &&
                                                    option['details']
                                                        .isNotEmpty)
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                            right: 24, top: 2),
                                                    child: Text(
                                                      option['details']
                                                          as String,
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        color: Colors
                                                            .grey.shade600,
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Divider
                    Divider(color: Colors.grey.shade200, height: 1),

                    // Action Buttons
                    Padding(
                      padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.symmetric(
                                horizontal: isSmallScreen ? 12 : 16,
                                vertical: 8,
                              ),
                            ),
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text(
                              'إلغاء',
                              style: TextStyle(fontSize: 13),
                            ),
                          ),
                          SizedBox(width: isSmallScreen ? 6 : 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.buttonPrimary,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(
                                horizontal: isSmallScreen ? 12 : 16,
                                vertical: 8,
                              ),
                            ),
                            onPressed: positionOptions.isEmpty
                                ? null // Disable button if no positions available
                                : () {
                                    final selectedOption =
                                        positionOptions[selectedPosition];
                                    Navigator.of(context).pop({
                                      'sectionId': selectedSectionId,
                                      'position': selectedOption['position'],
                                      'originalSection': video.sectionId,
                                      'originalPosition':
                                          currentSectionVideos.indexOf(video),
                                    });
                                  },
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.check, size: 16),
                                const SizedBox(width: 4),
                                const Text(
                                  'تأكيد النقل',
                                  style: TextStyle(fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
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
