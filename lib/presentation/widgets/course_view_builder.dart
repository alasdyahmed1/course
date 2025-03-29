import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';

class CourseViewBuilder extends StatelessWidget {
  final List<Map<String, dynamic>> courses;
  final bool isGridView;
  final Function() onTapCourse;

  const CourseViewBuilder({
    super.key,
    required this.courses,
    required this.isGridView,
    required this.onTapCourse,
  });

  @override
  Widget build(BuildContext context) {
    if (courses.isEmpty) {
      return _buildEmptyState();
    }

    return isGridView ? _buildGridView() : _buildListView();
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.school_outlined,
            size: 64,
            color: AppColors.hintColor.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'لا توجد كورسات متوفرة',
            style: AppTextStyles.titleMedium.copyWith(
              color: AppColors.hintColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGridView() {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.8,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: courses.length,
      itemBuilder: (context, index) => _buildCourseCard(courses[index], true),
    );
  }

  Widget _buildListView() {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: courses.length,
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _buildCourseCard(courses[index], false),
      ),
    );
  }

  Widget _buildCourseCard(Map<String, dynamic> course, bool isGrid) {
    final progress = (course['progress'] as num).toDouble();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTapCourse,
          borderRadius: BorderRadius.circular(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: isGrid ? MainAxisSize.max : MainAxisSize.min,
            children: [
              _buildThumbnail(course),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTitle(course['title']),
                    const SizedBox(height: 6),
                    _buildCourseInfo(course),
                    const SizedBox(height: 6),
                    _buildViewsAndProgress(course, progress),
                    const SizedBox(height: 4),
                    _buildProgressBar(progress),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail(Map<String, dynamic> course) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
          child: AspectRatio(
            // تغيير النسبة إلى 2:1 لتكون أقل ارتفاعاً
            aspectRatio: 2 / 1,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.primaryLight.withOpacity(0.1),
                    AppColors.accent.withOpacity(0.2),
                  ],
                ),
              ),
              child: const Icon(
                Icons.play_circle_outlined,
                size: 32,
                color: AppColors.accent,
              ),
            ),
          ),
        ),
        _buildOverlayInfo(course),
      ],
    );
  }

  Widget _buildOverlayInfo(Map<String, dynamic> course) {
    return Positioned(
      left: 6,
      right: 6,
      top: 6,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildRatingBadge(course['rating']),
          _buildPriceBadge(),
        ],
      ),
    );
  }

  Widget _buildRatingBadge(dynamic rating) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.buttonSecondary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, color: Colors.white, size: 15),
          const SizedBox(width: 4),
          Text(
            rating.toString(),
            style: AppTextStyles.bodySmall.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        '10 د.ع',
        style: AppTextStyles.bodySmall.copyWith(
          color: AppColors.buttonPrimary,
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _buildTitle(String title) {
    return Text(
      title,
      style: AppTextStyles.titleMedium.copyWith(
        fontWeight: FontWeight.bold,
        fontSize: 13,
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildCourseInfo(Map<String, dynamic> course) {
    return Row(
      children: [
        _buildInfoChip(
          icon: Icons.access_time_rounded,
          label: course['duration'],
        ),
        const SizedBox(width: 6),
        _buildInfoChip(
          icon: Icons.videocam_rounded,
          label: course['videos'],
        ),
      ],
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.primaryLight.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: AppColors.buttonPrimary,
            size: 13,
          ),
          const SizedBox(width: 3),
          Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.buttonPrimary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewsAndProgress(Map<String, dynamic> course, double progress) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            const Icon(
              Icons.visibility_outlined,
              size: 15,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: 4),
            Text(
              course['views'],
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
                fontSize: 10,
              ),
            ),
          ],
        ),
        Text(
          'إكمال ${course['progress']}%',
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildProgressBar(double progress) {
    return Container(
      width: double.infinity,
      height: 4,
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(2),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Row(
            children: [
              Container(
                width: constraints.maxWidth * (progress / 100),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.buttonSecondary,
                      AppColors.buttonSecondary.withOpacity(0.7),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
