import 'package:flutter/material.dart';
import 'package:mycourses/core/config/bunny_config.dart';
import 'package:mycourses/core/constants/app_colors.dart';
import 'package:mycourses/core/constants/app_text_styles.dart';
import 'package:mycourses/models/course_section.dart';
import 'package:mycourses/models/course_video.dart';
import 'package:mycourses/presentation/screens/admin/courses/components/course_video_ui_utils.dart';
import 'package:mycourses/presentation/widgets/empty_state.dart';

/// Component for video lists and sections
class CourseVideoListComponent {
  /// Builds a list of videos, either grouped by section or flat
  static Widget buildVideosList({
    required List<CourseVideo> videos,
    required List<CourseSection> sections,
    required Map<String, List<CourseVideo>> videosBySection,
    required List<CourseVideo> uncategorizedVideos,
    required Set<String> expandedSections,
    required ScrollController scrollController,
    required CourseVideo? selectedVideo,
    required Function(String) onToggleSection,
    required Function(CourseVideo, {bool resetPosition}) onPlayVideoInline,
    required VoidCallback onAddNewVideo,
    required Function(CourseVideo) onPlayVideo,
    required Map<String, Duration> videoPositions,
  }) {
    if (videos.isEmpty) {
      return EmptyState(
        icon: Icons.videocam_off_outlined,
        message: 'لا توجد فيديوهات',
        details: 'لم يتم إضافة أي فيديو لهذا الكورس بعد',
        buttonLabel: 'إضافة فيديو',
        onButtonPressed: onAddNewVideo,
      );
    }

    // Check if we have any valid sections with videos
    final bool hasValidSections = sections.isNotEmpty &&
        sections
            .any((section) => videosBySection[section.id]?.isNotEmpty == true);

    // If no valid sections, show a flat list
    if (!hasValidSections && uncategorizedVideos.isEmpty) {
      return Container(
        margin: const EdgeInsets.only(top: 1),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'محتويات الكورس (${videos.length} فيديو)',
                style: AppTextStyles.titleSmall.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 1),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                itemCount: videos.length,
                itemBuilder: (context, index) {
                  final video = videos[index];
                  final isSelected = selectedVideo?.id == video.id;
                  return buildCompactVideoItem(
                    video: video,
                    index: index,
                    isSelected: isSelected,
                    onTap: () => onPlayVideoInline(video),
                    onPlayPressed: () => onPlayVideo(video),
                    videoPositions: videoPositions,
                  );
                },
              ),
            ),
          ],
        ),
      );
    }

    // Show sections with videos
    return Container(
      margin: const EdgeInsets.only(top: 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'محتويات الكورس (${videos.length} فيديو)',
              style: AppTextStyles.titleSmall.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
              children: [
                // Render all sections with their videos
                ...sections.map((section) => buildSectionWidget(
                      section: section,
                      videos: videosBySection[section.id] ?? [],
                      isExpanded: expandedSections.contains(section.id),
                      selectedVideo: selectedVideo,
                      onToggleSection: () => onToggleSection(section.id),
                      onPlayVideoInline: onPlayVideoInline,
                      onPlayVideo: onPlayVideo,
                      videoPositions: videoPositions,
                    )),

                // Render uncategorized videos if any
                if (uncategorizedVideos.isNotEmpty)
                  buildUncategorizedVideosSection(
                    videos: uncategorizedVideos,
                    isExpanded: expandedSections.contains('uncategorized'),
                    selectedVideo: selectedVideo,
                    onToggleSection: () => onToggleSection('uncategorized'),
                    onPlayVideoInline: onPlayVideoInline,
                    onPlayVideo: onPlayVideo,
                    videoPositions: videoPositions,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Builds a section widget with its videos
  static Widget buildSectionWidget({
    required CourseSection section,
    required List<CourseVideo> videos,
    required bool isExpanded,
    required CourseVideo? selectedVideo,
    required VoidCallback onToggleSection,
    required Function(CourseVideo, {bool resetPosition}) onPlayVideoInline,
    required Function(CourseVideo) onPlayVideo,
    required Map<String, Duration> videoPositions,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        InkWell(
          onTap: onToggleSection,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: const Color.fromRGBO(0, 128, 255, 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: const Color.fromRGBO(0, 128, 255, 0.3),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isExpanded ? Icons.folder_open : Icons.folder,
                  color: const Color.fromRGBO(0, 128, 255, 1),
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        section.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Color.fromRGBO(0, 128, 255, 1),
                        ),
                      ),
                      if (section.description != null &&
                          section.description!.isNotEmpty)
                        Text(
                          section.description!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color.fromRGBO(0, 128, 255, 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${videos.length} فيديو',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color.fromRGBO(0, 128, 255, 1),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  isExpanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: const Color.fromRGBO(0, 128, 255, 0.7),
                  size: 20,
                ),
              ],
            ),
          ),
        ),

        // Section videos
        if (isExpanded) ...[
          if (videos.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 16, right: 16),
              child: Text(
                'لا توجد فيديوهات في هذا القسم',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic,
                ),
              ),
            )
          else
            Column(
              children: List.generate(videos.length, (index) {
                final video = videos[index];
                final isSelected = selectedVideo?.id == video.id;
                return buildCompactVideoItem(
                  video: video,
                  index: index,
                  isSelected: isSelected,
                  onTap: () => onPlayVideoInline(video),
                  onPlayPressed: () => onPlayVideo(video),
                  videoPositions: videoPositions,
                );
              }),
            ),
        ],

        const SizedBox(height: 8),
      ],
    );
  }

  /// Builds the uncategorized videos section
  static Widget buildUncategorizedVideosSection({
    required List<CourseVideo> videos,
    required bool isExpanded,
    required CourseVideo? selectedVideo,
    required VoidCallback onToggleSection,
    required Function(CourseVideo, {bool resetPosition}) onPlayVideoInline,
    required Function(CourseVideo) onPlayVideo,
    required Map<String, Duration> videoPositions,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: onToggleSection,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.grey.shade300,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isExpanded ? Icons.folder_open : Icons.folder,
                  color: Colors.grey.shade700,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'فيديوهات غير مصنفة',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${videos.length} فيديو',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  isExpanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: Colors.grey.shade500,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
        if (isExpanded)
          Column(
            children: List.generate(videos.length, (index) {
              final video = videos[index];
              final isSelected = selectedVideo?.id == video.id;
              return buildCompactVideoItem(
                video: video,
                index: index,
                isSelected: isSelected,
                onTap: () => onPlayVideoInline(video),
                onPlayPressed: () => onPlayVideo(video),
                videoPositions: videoPositions,
              );
            }),
          ),
        const SizedBox(height: 8),
      ],
    );
  }

  /// Builds a compact video item
  static Widget buildCompactVideoItem({
    required CourseVideo video,
    required int index,
    required bool isSelected,
    required VoidCallback onTap,
    required VoidCallback onPlayPressed,
    required Map<String, Duration> videoPositions,
  }) {
    final hasThumbnail = video.videoId.isNotEmpty;
    final thumbnailUrl =
        hasThumbnail ? BunnyConfig.getThumbnailUrl(video.videoId) : null;

    // Calculate progress for this video
    final progress =
        CourseVideoUIUtils.calculateVideoProgress(video, videoPositions);

    return Container(
      key: Key(video.id),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color:
            isSelected ? AppColors.primaryLight.withOpacity(0.1) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSelected
              ? const Color.fromRGBO(0, 128, 255, 1)
              : Colors.grey.shade200,
          width: isSelected ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        onTap: () {
          // منع أي سلوك آخر قبل الاستدعاء
          onTap();
        },
        child: Column(
          children: [
            Row(
              children: [
                // Thumbnail with progress indicator
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(8),
                        bottomLeft: Radius.circular(8),
                      ),
                      child: SizedBox(
                        width: 90,
                        height: 60,
                        child: hasThumbnail && thumbnailUrl != null
                            ? Image.network(
                                thumbnailUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    CourseVideoUIUtils
                                        .buildThumbnailPlaceholder(),
                              )
                            : CourseVideoUIUtils.buildThumbnailPlaceholder(),
                      ),
                    ),
                    // Progress indicator
                    if (progress > 0)
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          height: 3,
                          alignment: Alignment.centerLeft,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade700,
                          ),
                          child: FractionallySizedBox(
                            widthFactor: progress,
                            child: Container(
                              color: AppColors.buttonPrimary,
                            ),
                          ),
                        ),
                      ),
                    // Remaining time or watched indicator
                    if (progress > 0)
                      Positioned(
                        top: 3,
                        right: 3,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            progress >= 0.95
                                ? 'تم المشاهدة'
                                : '${((1 - progress) * 100).toInt()}% متبقي',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                // Video information
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          video.title,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: isSelected
                                ? const Color.fromRGBO(0, 128, 255, 1)
                                : Colors.grey.shade800,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          video.formattedDuration,
                          style: TextStyle(
                            fontSize: 12,
                            color: isSelected
                                ? const Color.fromRGBO(0, 128, 255, 0.7)
                                : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Play button
                IconButton(
                  icon: Icon(
                    Icons.play_arrow,
                    color: isSelected
                        ? const Color.fromRGBO(0, 128, 255, 1)
                        : Colors.grey.shade600,
                  ),
                  onPressed: onPlayPressed,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 40),
                ),
              ],
            ),
            // Progress bar
            if (progress > 0)
              Container(
                height: 2,
                margin: const EdgeInsets.only(top: 4),
                alignment: Alignment.centerLeft,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(1),
                ),
                child: FractionallySizedBox(
                  widthFactor: progress,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.buttonPrimary,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
