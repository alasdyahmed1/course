import 'package:flutter/material.dart';
import 'package:mycourses/core/constants/app_colors.dart';
import 'package:mycourses/core/constants/app_text_styles.dart';
import 'package:mycourses/models/course_video.dart';
import 'package:mycourses/presentation/screens/admin/courses/components/course_video_ui_utils.dart';

/// Component for video details and attachments
class CourseVideoDetailComponent {
  /// Builds a collapsible video details panel
  static Widget buildCollapsibleVideoDetails({
    required CourseVideo? selectedVideo,
    required bool showVideoDetails,
    required Function(bool) onToggleDetails,
    required Function(CourseVideo) onPlayVideo,
    required Function(CourseVideo) onEditVideo,
    required Function(CourseVideo) onDeleteVideo,
    required Function(CourseFile) onOpenAttachment,
    required Function(CourseFile) onDeleteAttachment,
  }) {
    if (selectedVideo == null) return const SizedBox.shrink();

    // تحديد ما إذا كان هناك وصف للفيديو أو ملفات مرفقة
    bool hasDescription = selectedVideo.description.isNotEmpty;
    bool hasAttachments =
        selectedVideo.files != null && selectedVideo.files!.isNotEmpty;
    bool hasDetails = hasDescription || hasAttachments;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.shade200,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Video title and duration
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  selectedVideo.title,
                  style: AppTextStyles.titleMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: const Color.fromRGBO(0, 128, 255, 0.9),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color.fromRGBO(0, 128, 255, 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.access_time,
                      size: 14,
                      color: Color.fromRGBO(0, 128, 255, 0.7),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      selectedVideo.formattedDuration,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color.fromRGBO(0, 128, 255, 0.7),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Show more/less button - إظهار زر فقط عندما تكون هناك تفاصيل
          if (hasDetails)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: InkWell(
                onTap: () => onToggleDetails(!showVideoDetails),
                borderRadius: BorderRadius.circular(4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      showVideoDetails ? 'عرض أقل' : 'عرض المزيد',
                      style: const TextStyle(
                        color: Color.fromRGBO(0, 128, 255, 0.7),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    Icon(
                      showVideoDetails
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      color: const Color.fromRGBO(0, 128, 255, 0.7),
                      size: 14,
                    ),
                  ],
                ),
              ),
            ),

          // Expanded details
          if (showVideoDetails && hasDetails)
            buildExpandedDetails(
              context: null, // Will be populated by the build context
              selectedVideo: selectedVideo,
              hasDescription: hasDescription,
              hasAttachments: hasAttachments,
              onOpenAttachment: onOpenAttachment,
              onDeleteAttachment: onDeleteAttachment,
            ),

          // Indicators for collapsed details
          if (!showVideoDetails && hasDetails)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  if (hasDescription)
                    Text(
                      'يوجد وصف',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 10,
                      ),
                    ),
                  if (hasDescription && hasAttachments)
                    Text(
                      ' • ',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 10,
                      ),
                    ),
                  if (hasAttachments)
                    Text(
                      '${selectedVideo.files!.length} ملف مرفق',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 10,
                      ),
                    ),
                ],
              ),
            ),

          // Action buttons
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              CourseVideoUIUtils.buildActionButton(
                icon: Icons.play_arrow,
                label: 'تشغيل',
                color: const Color.fromRGBO(0, 128, 255, 0.7),
                onTap: () => onPlayVideo(selectedVideo),
              ),
              const SizedBox(width: 8),
              CourseVideoUIUtils.buildActionButton(
                icon: Icons.edit,
                label: 'تعديل',
                color: AppColors.accent,
                onTap: () => onEditVideo(selectedVideo),
              ),
              const SizedBox(width: 8),
              CourseVideoUIUtils.buildActionButton(
                icon: Icons.delete,
                label: 'حذف',
                color: Colors.red,
                onTap: () => onDeleteVideo(selectedVideo),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Builds the expanded details section with description and attachments
  static Widget buildExpandedDetails({
    required BuildContext? context,
    required CourseVideo selectedVideo,
    required bool hasDescription,
    required bool hasAttachments,
    required Function(CourseFile) onOpenAttachment,
    required Function(CourseFile) onDeleteAttachment,
  }) {
    return Builder(builder: (builderContext) {
      // Use the passed context if available, otherwise use the builder context
      final ctx = context ?? builderContext;

      return Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(ctx).size.height * 0.3,
        ),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              // Video description
              if (hasDescription)
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.grey.shade200,
                      width: 1,
                    ),
                  ),
                  width: double.infinity,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.description_outlined,
                            size: 14,
                            color: Colors.grey.shade700,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'وصف الفيديو',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        selectedVideo.description,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
              // Attachments
              if (hasDescription && hasAttachments) const SizedBox(height: 12),
              if (hasAttachments)
                buildAttachmentsList(
                  attachments: selectedVideo.files!,
                  onOpenAttachment: onOpenAttachment,
                  onDeleteAttachment: onDeleteAttachment,
                ),
            ],
          ),
        ),
      );
    });
  }

  /// Builds a list of attachments
  static Widget buildAttachmentsList({
    required List<CourseFile> attachments,
    required Function(CourseFile) onOpenAttachment,
    required Function(CourseFile) onDeleteAttachment,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.grey.shade200,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                const Icon(
                  Icons.attach_file,
                  size: 14,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  'الملفات المرفقة (${attachments.length})',
                  style: AppTextStyles.titleSmall.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: attachments.length > 3 ? 150 : double.infinity,
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: attachments.length > 3
                  ? const AlwaysScrollableScrollPhysics()
                  : const NeverScrollableScrollPhysics(),
              itemCount: attachments.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) => buildAttachmentItem(
                file: attachments[index],
                onOpen: () => onOpenAttachment(attachments[index]),
                onDelete: () => onDeleteAttachment(attachments[index]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds a single attachment item
  static Widget buildAttachmentItem({
    required CourseFile file,
    required VoidCallback onOpen,
    required VoidCallback onDelete,
  }) {
    final icon = CourseVideoUIUtils.getFileIcon(file.fileType);

    return InkWell(
      onTap: onOpen,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: AppColors.buttonSecondary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    file.title,
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: const Color.fromRGBO(0, 128, 255, 1),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    file.formattedSize,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 16),
              onPressed: onDelete,
              color: Colors.red,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }
}
