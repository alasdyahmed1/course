import 'package:flutter/material.dart';
import 'package:mycourses/core/constants/app_colors.dart';
import 'package:mycourses/models/course_section.dart';
import 'package:mycourses/models/course_video.dart';
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
    required ScrollController? scrollController,
    required CourseVideo? selectedVideo,
    required Function(String) onToggleSection,
    required Function(CourseVideo,
            {bool resetPosition, bool preserveFullscreen})
        onPlayVideoInline,
    required VoidCallback onAddNewVideo,
    required Function(CourseVideo) onPlayVideo,
    required Map<String, Duration> videoPositions,
    required Function(CourseVideo, int, String?) onReorderVideo,
    required Function(CourseSection, int) onReorderSection,
    required Future<void> Function(CourseVideo) onReorderRequested,
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

    final sortedSections = List<CourseSection>.from(sections);
    sortedSections.sort((a, b) => a.orderNumber.compareTo(b.orderNumber));

    final bool hasValidSections = sortedSections.isNotEmpty &&
        sortedSections
            .any((section) => videosBySection[section.id]?.isNotEmpty == true);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Main content - either sections or flat list
        if (hasValidSections)
          _buildSectionsList(
            sections: sortedSections,
            videosBySection: videosBySection,
            expandedSections: expandedSections,
            selectedVideo: selectedVideo,
            onToggleSection: onToggleSection,
            onPlayVideoInline: onPlayVideoInline,
            onPlayVideo: onPlayVideo,
            videoPositions: videoPositions,
            onReorderVideo: onReorderVideo,
            onReorderSection: onReorderSection,
            onReorderRequested: onReorderRequested,
          )
        else if (uncategorizedVideos.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: buildUncategorizedVideosSection(
              videos: uncategorizedVideos,
              isExpanded: expandedSections.contains('uncategorized'),
              selectedVideo: selectedVideo,
              onToggleSection: () => onToggleSection('uncategorized'),
              onPlayVideoInline: onPlayVideoInline,
              onPlayVideo: onPlayVideo,
              videoPositions: videoPositions,
              onReorderVideo: onReorderVideo,
              videoIndexMap: {},
              onReorderRequested: onReorderRequested,
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(vertical: 6),
            itemCount: videos.length,
            itemBuilder: (context, index) {
              final video = videos[index];
              return buildCompactVideoItem(
                video: video,
                index: index,
                isSelected: selectedVideo?.id == video.id,
                onTap: () => onPlayVideoInline(video),
                onPlayPressed: () => onPlayVideo(video),
                videoPositions: videoPositions,
              );
            },
          ),

        // Bottom spacing - reduced to be minimal
        const SizedBox(height: 10),
      ],
    );
  }

  static Widget _buildSectionsList({
    required List<CourseSection> sections,
    required Map<String, List<CourseVideo>> videosBySection,
    required Set<String> expandedSections,
    required CourseVideo? selectedVideo,
    required Function(String) onToggleSection,
    required Function(CourseVideo,
            {bool resetPosition, bool preserveFullscreen})
        onPlayVideoInline,
    required Function(CourseVideo) onPlayVideo,
    required Map<String, Duration> videoPositions,
    required Function(CourseVideo, int, String?) onReorderVideo,
    required Function(CourseSection, int) onReorderSection,
    required Future<void> Function(CourseVideo) onReorderRequested,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 6),
        Row(
          children: [
            const SizedBox(width: 2),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.buttonPrimary,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(
                Icons.folder_copy_outlined,
                size: 12,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              'أقسام الكورس (${sections.length})',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppColors.buttonPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ReorderableListView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          onReorder: (oldIndex, newIndex) {
            if (newIndex > oldIndex) {
              newIndex--;
            }
            if (oldIndex != newIndex &&
                oldIndex < sections.length &&
                newIndex < sections.length) {
              onReorderSection(sections[oldIndex], newIndex);
            }
          },
          proxyDecorator: (widget, index, animation) {
            return AnimatedBuilder(
              animation: animation,
              builder: (context, child) {
                final double scale = Tween<double>(begin: 1.0, end: 1.03)
                    .animate(
                      CurvedAnimation(
                        parent: animation,
                        curve: Interval(0.0, 0.5, curve: Curves.easeOut),
                        reverseCurve: Interval(0.5, 1.0, curve: Curves.easeIn),
                      ),
                    )
                    .value;

                return Material(
                  elevation:
                      Tween<double>(begin: 0, end: 4).animate(animation).value,
                  color: Colors.transparent,
                  shadowColor: AppColors.buttonPrimary.withOpacity(0.2),
                  child: Transform.scale(
                    scale: scale,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.buttonPrimary,
                          width: 1,
                        ),
                      ),
                      child: widget,
                    ),
                  ),
                );
              },
            );
          },
          children: sections
              .map((section) => KeyedSubtree(
                    key: Key('section_${section.id}'),
                    child: buildSectionWidget(
                      section: section,
                      videos: videosBySection[section.id] ?? [],
                      isExpanded: expandedSections.contains(section.id),
                      selectedVideo: selectedVideo,
                      onToggleSection: () => onToggleSection(section.id),
                      onPlayVideoInline: onPlayVideoInline,
                      onPlayVideo: onPlayVideo,
                      videoPositions: videoPositions,
                      onReorderVideo: onReorderVideo,
                      videoIndexMap: {},
                      onReorderRequested: onReorderRequested,
                    ),
                  ))
              .toList(),
        ),
      ],
    );
  }

  static Widget buildSectionWidget({
    required CourseSection section,
    required List<CourseVideo> videos,
    required bool isExpanded,
    required CourseVideo? selectedVideo,
    required VoidCallback onToggleSection,
    required Function(CourseVideo,
            {bool resetPosition, bool preserveFullscreen})
        onPlayVideoInline,
    required Function(CourseVideo) onPlayVideo,
    required Map<String, Duration> videoPositions,
    required Function(CourseVideo, int, String?) onReorderVideo,
    required Map<String, int> videoIndexMap,
    required Function(CourseVideo) onReorderRequested,
  }) {
    return RepaintBoundary(
      child: StatefulBuilder(
        builder: (context, setSectionState) {
          bool localIsExpanded = isExpanded;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: () {
                  setSectionState(() {
                    localIsExpanded = !localIsExpanded;
                  });
                  onToggleSection();
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 2),
                  padding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.buttonPrimary,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(
                          Icons.folder,
                          color: Colors.white,
                          size: 14,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              section.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: AppColors.buttonPrimary,
                              ),
                            ),
                            if (section.description != null &&
                                section.description!.isNotEmpty)
                              Text(
                                section.description!,
                                style: TextStyle(
                                  fontSize: 10,
                                  color:
                                      AppColors.buttonPrimary.withOpacity(0.7),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.buttonSecondary.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppColors.buttonSecondary.withOpacity(0.1),
                            width: 0.5,
                          ),
                        ),
                        child: Text(
                          '${videos.length} فيديو',
                          style: const TextStyle(
                            fontSize: 8,
                            color: AppColors.buttonSecondary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          color: AppColors.buttonSecondary.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Icon(
                            localIsExpanded
                                ? Icons.keyboard_arrow_up
                                : Icons.keyboard_arrow_down,
                            color: AppColors.buttonSecondary,
                            size: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              AnimatedCrossFade(
                firstChild: const SizedBox.shrink(),
                secondChild: videos.isEmpty
                    ? Padding(
                        padding:
                            const EdgeInsets.only(bottom: 8, right: 8, left: 8),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: AppColors.buttonSecondary,
                              size: 12,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'لا توجد فيديوهات في هذا القسم',
                              style: TextStyle(
                                fontSize: 9,
                                color: AppColors.buttonSecondary,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      )
                    : _buildReorderableVideoList(
                        videos: videos,
                        selectedVideo: selectedVideo,
                        onItemTap: onPlayVideoInline,
                        onPlayVideo: onPlayVideo,
                        videoPositions: videoPositions,
                        sectionId: section.id,
                        onReorderVideo: onReorderVideo,
                        videoIndexMap: videoIndexMap,
                        onReorderRequested: onReorderRequested,
                      ),
                crossFadeState: localIsExpanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 300),
              ),
              const SizedBox(height: 4),
            ],
          );
        },
      ),
    );
  }

  static Widget buildUncategorizedVideosSection({
    required List<CourseVideo> videos,
    required bool isExpanded,
    required CourseVideo? selectedVideo,
    required VoidCallback onToggleSection,
    required Function(CourseVideo,
            {bool resetPosition, bool preserveFullscreen})
        onPlayVideoInline,
    required Function(CourseVideo) onPlayVideo,
    required Map<String, Duration> videoPositions,
    required Function(CourseVideo, int, String?) onReorderVideo,
    required Map<String, int> videoIndexMap,
    required Function(CourseVideo) onReorderRequested,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: onToggleSection,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: AppColors.buttonThird,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(
                    Icons.folder,
                    color: Colors.white,
                    size: 14,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'فيديوهات غير مصنفة',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      color: AppColors.buttonThird,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.buttonThird.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.buttonThird.withOpacity(0.2),
                      width: 0.5,
                    ),
                  ),
                  child: Text(
                    '${videos.length} فيديو',
                    style: TextStyle(
                      fontSize: 9,
                      color: AppColors.buttonThird,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: AppColors.buttonThird.withOpacity(0.1),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.buttonThird.withOpacity(0.2),
                      width: 0.5,
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      isExpanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      color: AppColors.buttonThird,
                      size: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: _buildReorderableVideoList(
            videos: videos,
            selectedVideo: selectedVideo,
            onItemTap: onPlayVideoInline,
            onPlayVideo: onPlayVideo,
            videoPositions: videoPositions,
            sectionId: null,
            onReorderVideo: onReorderVideo,
            videoIndexMap: videoIndexMap,
            onReorderRequested: onReorderRequested,
          ),
          crossFadeState:
              isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 300),
        ),
        const SizedBox(height: 6),
      ],
    );
  }

  static Widget _buildReorderableVideoList({
    required List<CourseVideo> videos,
    required CourseVideo? selectedVideo,
    required Function(CourseVideo,
            {bool resetPosition, bool preserveFullscreen})
        onItemTap,
    required Function(CourseVideo) onPlayVideo,
    required Map<String, Duration> videoPositions,
    required String? sectionId,
    required Function(CourseVideo, int, String?) onReorderVideo,
    required Map<String, int> videoIndexMap,
    required Function(CourseVideo) onReorderRequested,
  }) {
    return Container(
      padding: const EdgeInsets.only(left: 0, right: 0),
      child: ListView.builder(
        key: PageStorageKey('video_list_${sectionId ?? 'uncategorized'}'),
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        itemCount: videos.length,
        itemBuilder: (context, index) {
          final video = videos[index];
          final isSelected = selectedVideo?.id == video.id;
          final globalIndex = video.orderNumber;

          return RepaintBoundary(
            key: GlobalObjectKey('video_item_${video.id}'),
            child: _buildSimpleVideoItem(
              key: Key('video_${video.id}'),
              video: video,
              isSelected: isSelected,
              onTap: () {
                onItemTap(video);
              },
              onPlayPressed: () => onPlayVideo(video),
              progress: videoPositions[video.id]?.inSeconds ?? 0,
              maxDuration: video.duration,
              index: globalIndex,
              onReorderRequested: onReorderRequested,
            ),
          );
        },
      ),
    );
  }

  static Widget _buildSimpleVideoItem({
    required Key key,
    required CourseVideo video,
    required bool isSelected,
    required VoidCallback onTap,
    required VoidCallback onPlayPressed,
    required int progress,
    required int maxDuration,
    required int index,
    required Function(CourseVideo) onReorderRequested,
  }) {
    final sequentialNumber = video.orderNumber;
    final double progressPercent =
        maxDuration > 0 ? (progress / maxDuration).clamp(0.0, 1.0) : 0.0;
    final bool hasProgress = progress > 0 && progressPercent > 0;

    return RepaintBoundary(
      child: Material(
        borderRadius: BorderRadius.circular(13),
        color: Colors.transparent,
        key: GlobalObjectKey('video_item_${video.id}'),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(13),
          child: Container(
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.buttonPrimary.withOpacity(0.08)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(13),
              border: isSelected
                  ? Border.all(
                      color: AppColors.buttonPrimary.withOpacity(0.3),
                      width: 0.8,
                    )
                  : null,
            ),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
            margin: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.buttonPrimary : Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: AppColors.buttonPrimary.withOpacity(0.3),
                              blurRadius: 3,
                              spreadRadius: 0,
                              offset: const Offset(0, 1),
                            ),
                          ]
                        : null,
                    border: Border.all(
                      color: isSelected
                          ? Colors.transparent
                          : AppColors.buttonPrimary.withOpacity(0.5),
                      width: 0.5,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      sequentialNumber.toString(),
                      style: TextStyle(
                        color:
                            isSelected ? Colors.white : AppColors.buttonPrimary,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        video.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.w500,
                          color: AppColors.buttonPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      if (isSelected)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: progressPercent,
                            minHeight: 2.5,
                            backgroundColor:
                                AppColors.buttonPrimary.withOpacity(0.1),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.buttonPrimary,
                            ),
                          ),
                        )
                      else
                        Row(
                          children: [
                            Icon(
                              Icons.access_time,
                              size: 10,
                              color: AppColors.buttonPrimary.withOpacity(0.7),
                            ),
                            const SizedBox(width: 2),
                            Text(
                              _formatDuration(video.duration),
                              style: TextStyle(
                                fontSize: 9,
                                color: AppColors.buttonPrimary.withOpacity(0.7),
                              ),
                            ),
                            if (hasProgress) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 5, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.buttonThird.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.play_arrow,
                                      size: 7,
                                      color: AppColors.buttonThird,
                                    ),
                                    const SizedBox(width: 2),
                                    Text(
                                      '${(progressPercent * 100).toInt()}%',
                                      style: TextStyle(
                                        fontSize: 7,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.buttonThird,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                    ],
                  ),
                ),
                Container(
                  width: 28,
                  height: 28,
                  margin: const EdgeInsets.only(left: 4),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.buttonPrimary
                        : AppColors.buttonPrimary.withOpacity(0.08),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected
                          ? Colors.transparent
                          : AppColors.buttonPrimary.withOpacity(0.2),
                      width: 0.5,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: AppColors.buttonPrimary.withOpacity(0.2),
                              blurRadius: 3,
                              offset: const Offset(0, 1),
                            ),
                          ]
                        : null,
                  ),
                  child: Material(
                    color: Colors.transparent,
                    shape: const CircleBorder(),
                    clipBehavior: Clip.hardEdge,
                    child: InkWell(
                      onTap: onPlayPressed,
                      child: Icon(
                        Icons.play_arrow_rounded,
                        color:
                            isSelected ? Colors.white : AppColors.buttonPrimary,
                        size: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _formatDuration(int seconds) {
    final duration = Duration(seconds: seconds);
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return duration.inHours > 0
        ? '${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds'
        : '$twoDigitMinutes:$twoDigitSeconds';
  }

  static Widget buildCompactVideoItem({
    required CourseVideo video,
    required int index,
    required bool isSelected,
    required VoidCallback onTap,
    required VoidCallback onPlayPressed,
    required Map<String, Duration> videoPositions,
  }) {
    final double progressPercent = videoPositions.containsKey(video.id) &&
            video.duration > 0
        ? (videoPositions[video.id]!.inSeconds / video.duration).clamp(0.0, 1.0)
        : 0.0;
    final bool hasProgress = progressPercent > 0;

    return Material(
      borderRadius: BorderRadius.circular(13),
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Row(
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.buttonPrimary : Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected
                        ? AppColors.buttonPrimary
                        : AppColors.buttonPrimary.withOpacity(0.5),
                    width: isSelected ? 0.8 : 0.5,
                  ),
                ),
                child: Center(
                  child: Text(
                    (index + 1).toString(),
                    style: TextStyle(
                      color:
                          isSelected ? Colors.white : AppColors.buttonPrimary,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      video.title,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.w500,
                        color: AppColors.buttonPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (hasProgress) ...[
                      const SizedBox(height: 2),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(1),
                        child: LinearProgressIndicator(
                          value: progressPercent,
                          minHeight: 1.5,
                          backgroundColor:
                              AppColors.buttonPrimary.withOpacity(0.1),
                          valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.buttonPrimary),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.only(right: 4, left: 4),
                child: Text(
                  _formatDuration(video.duration),
                  style: TextStyle(
                    fontSize: 7,
                    color: AppColors.buttonPrimary.withOpacity(0.7),
                  ),
                ),
              ),
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.buttonPrimary
                      : AppColors.buttonPrimary.withOpacity(0.08),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected
                        ? Colors.transparent
                        : AppColors.buttonPrimary.withOpacity(0.2),
                    width: 0.5,
                  ),
                ),
                child: IconButton(
                  icon: Icon(
                    Icons.play_arrow,
                    color: isSelected ? Colors.white : AppColors.buttonPrimary,
                    size: 10,
                  ),
                  onPressed: onPlayPressed,
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 18, minHeight: 18),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
