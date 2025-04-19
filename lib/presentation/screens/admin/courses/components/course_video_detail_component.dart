import 'package:flutter/material.dart';
import 'package:mycourses/core/constants/app_colors.dart';
import 'package:mycourses/models/course_video.dart';

class CourseVideoDetailComponent {
  static Widget buildCollapsibleVideoDetails({
    Key? key, // Add key parameter for stability
    required CourseVideo? selectedVideo,
    required bool showVideoDetails,
    required void Function(bool) onToggleDetails, // Keep this parameter type
    required Function(CourseVideo) onPlayVideo,
    required Function(CourseVideo) onEditVideo,
    required Function(CourseVideo) onDeleteVideo,
    required Function(CourseFile) onOpenAttachment,
    required Function(CourseFile) onDeleteAttachment,
  }) {
    if (selectedVideo == null) {
      return const SizedBox.shrink();
    }

    return Material(
      key: key, // Use the key
      color: Colors.transparent, // إزالة الخلفية
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(10),
        bottomRight: Radius.circular(10),
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: showVideoDetails
            ? Container(
                constraints: const BoxConstraints(maxHeight: 200),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Expandable details section
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        padding: const EdgeInsets.fromLTRB(10, 0, 10, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (selectedVideo.description.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.description,
                                        size: 10,
                                        color: AppColors.buttonPrimary,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'الوصف:',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.buttonPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    constraints:
                                        const BoxConstraints(maxHeight: 75),
                                    child: SingleChildScrollView(
                                      physics: const BouncingScrollPhysics(),
                                      child: Text(
                                        selectedVideo.description,
                                        style: TextStyle(
                                          fontSize: 9,
                                          height: 1.4,
                                          color: AppColors.buttonPrimary,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            // Action buttons with larger sizing
                            const SizedBox(height: 6), // زيادة المسافة
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _buildActionButton(
                                  'عرض',
                                  Icons.play_arrow,
                                  AppColors.buttonSecondary,
                                  () => onPlayVideo(selectedVideo),
                                  fontSize: 9, // زيادة حجم الخط
                                  iconSize: 13, // زيادة حجم الأيقونة
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 7), // زيادة الحشو
                                ),
                                const SizedBox(width: 12),
                                _buildActionButton(
                                  'تعديل',
                                  Icons.edit,
                                  AppColors.buttonPrimary,
                                  () => onEditVideo(selectedVideo),
                                  fontSize: 9,
                                  iconSize: 13,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 7),
                                ),
                                const SizedBox(width: 12),
                                _buildActionButton(
                                  'حذف',
                                  Icons.delete,
                                  AppColors.error,
                                  () => onDeleteVideo(selectedVideo),
                                  fontSize: 9,
                                  iconSize: 13,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 7),
                                ),
                              ],
                            ),

                            // Attachments section
                            if (selectedVideo.files != null &&
                                selectedVideo.files!.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Divider(
                                height: 1,
                                thickness: 0.5,
                                color:
                                    AppColors.buttonPrimary.withOpacity(0.08),
                              ),
                              Container(
                                margin: const EdgeInsets.symmetric(vertical: 8),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: AppColors.buttonPrimary
                                            .withOpacity(0.08),
                                        borderRadius: BorderRadius.circular(5),
                                      ),
                                      child: Icon(
                                        Icons.attach_file,
                                        size: 10,
                                        color: AppColors.buttonPrimary,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'الملفات المرفقة',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 10,
                                        color: AppColors.buttonPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              ...selectedVideo.files!.map(
                                (file) => _buildAttachmentItem(
                                  file,
                                  onOpenAttachment,
                                  onDeleteAttachment,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : const SizedBox.shrink(),
      ),
    );
  }

  static Widget _buildActionButton(
      String label, IconData icon, Color color, VoidCallback onTap,
      {double fontSize = 10,
      double iconSize = 12,
      EdgeInsetsGeometry padding =
          const EdgeInsets.symmetric(horizontal: 10, vertical: 6)}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(13),
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(13),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.2),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: iconSize,
              color: Colors.white,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: fontSize,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _buildAttachmentItem(
    CourseFile file,
    Function(CourseFile) onOpen,
    Function(CourseFile) onDelete,
  ) {
    IconData fileIcon;
    Color fileColor;

    // Set icon and color based on file type
    switch (file.fileType.toLowerCase()) {
      case 'pdf':
        fileIcon = Icons.picture_as_pdf;
        fileColor = Colors.red;
        break;
      case 'doc':
      case 'docx':
        fileIcon = Icons.description;
        fileColor = AppColors.buttonSecondary;
        break;
      case 'xls':
      case 'xlsx':
        fileIcon = Icons.table_chart;
        fileColor = Colors.green;
        break;
      case 'ppt':
      case 'pptx':
        fileIcon = Icons.slideshow;
        fileColor = Colors.orange;
        break;
      case 'jpg':
      case 'jpeg':
      case 'png':
        fileIcon = Icons.image;
        fileColor = AppColors.buttonThird;
        break;
      case 'zip':
      case 'rar':
        fileIcon = Icons.archive;
        fileColor = AppColors.buttonPrimary;
        break;
      default:
        fileIcon = Icons.insert_drive_file;
        fileColor = AppColors.buttonPrimary;
    }

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      minVerticalPadding: 0,
      dense: true,
      leading: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: fileColor.withOpacity(0.2),
            width: 0.5,
          ),
        ),
        child: Icon(fileIcon, size: 14, color: fileColor),
      ),
      title: Text(
        file.title,
        style: TextStyle(
          fontSize: 10,
          color: AppColors.buttonPrimary,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Container(
        margin: const EdgeInsets.only(top: 2),
        child: Text(
          file.formattedSize,
          style: TextStyle(
            fontSize: 8,
            color: AppColors.buttonPrimary.withOpacity(0.7),
          ),
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
            ),
            child: IconButton(
              icon: const Icon(Icons.open_in_new, size: 12),
              color: AppColors.buttonPrimary,
              onPressed: () => onOpen(file),
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(
                minWidth: 24,
                minHeight: 24,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Container(
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.05),
              borderRadius: BorderRadius.circular(6),
            ),
            child: IconButton(
              icon: const Icon(Icons.delete_outline, size: 12),
              color: Colors.red,
              onPressed: () => onDelete(file),
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(
                minWidth: 24,
                minHeight: 24,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
