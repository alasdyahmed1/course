import 'package:flutter/material.dart';
import 'package:mycourses/presentation/screens/departments/department_courses_screen.dart';
import 'package:mycourses/presentation/widgets/auth_required_dialog.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/app_transitions.dart';
import '../auth/login_screen.dart';
import '../auth/register_screen.dart';

class GuestHomeScreen extends StatefulWidget {
  const GuestHomeScreen({super.key});

  @override
  State<GuestHomeScreen> createState() => _GuestHomeScreenState();
}

class _GuestHomeScreenState extends State<GuestHomeScreen> {
  final int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.primaryLight,
              AppColors.primaryMedium,
              AppColors.primaryBg,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // هيدر جديد بتصميم متناسق
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // زر تسجيل الدخول (يمين)
                    Container(
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.buttonPrimary,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.buttonPrimary.withOpacity(0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              AppTransitions.authTransition(
                                page: const LoginScreen(),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.login_rounded,
                                  color: Colors.white,
                                  size: 16,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'تسجيل الدخول',
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    // زر إنشاء حساب (يسار)
                    Container(
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.buttonPrimary.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              AppTransitions.authTransition(
                                page: const RegisterScreen(),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.person_add_rounded,
                                  color: AppColors.buttonPrimary,
                                  size: 16,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'إنشاء حساب',
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    color: AppColors.buttonPrimary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // باقي محتوى الصفحة
              Expanded(
                child: _buildCurrentPage(),
              ),
            ],
          ),
        ),
      ),

      // Bottom Navigation Bar
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
        child: SafeArea(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                index: 0,
                icon: Icons.explore_outlined,
                activeIcon: Icons.explore_rounded,
                label: 'تصفح',
                isSelected: _currentIndex == 0,
              ),
              _buildNavItem(
                index: 1,
                icon: Icons.search_rounded,
                activeIcon: Icons.search,
                label: 'بحث',
                isSelected: _currentIndex == 1,
              ),
              _buildNavItem(
                index: 2,
                icon: Icons.play_lesson_outlined,
                activeIcon: Icons.play_lesson_rounded,
                label: 'مشاهداتي',
                isSelected: _currentIndex == 2,
              ),
              _buildNavItem(
                index: 3,
                icon: Icons.interests_outlined,
                activeIcon: Icons.interests_rounded,
                label: 'كورساتي',
                isSelected: _currentIndex == 3,
              ),
              _buildNavItem(
                index: 4,
                icon: Icons.download_outlined,
                activeIcon: Icons.download_rounded,
                label: 'تنزيلات',
                isSelected: _currentIndex == 4,
              ),
              _buildNavItem(
                index: 5,
                icon: Icons.person_outline_rounded,
                activeIcon: Icons.person_rounded,
                label: 'حسابي',
                isSelected: _currentIndex == 5,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('الأقسام المتوفرة'),
          _buildDepartmentsList(),

          _buildSectionTitle('كورسات مميزة'),
          _buildFeaturedCourses(),

          // قسم أحدث الكورسات
          _buildSectionTitle('أحدث الكورسات'),
          _buildLatestCourses(),

          // إضافة أقسام الكورسات
          _buildDepartmentSections(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: AppTextStyles.titleMedium.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          if (title == 'الأقسام المتوفرة') // إضافة شرط للأقسام فقط
            TextButton(
              onPressed: () {
                // تعديل طريقة الانتقال لصفحة البحث
                Navigator.pushAndRemoveUntil(
                  context,
                  AppTransitions.smart(
                    page: DepartmentCoursesScreen(
                      departmentName: 'علوم الحاسوب', // القسم الافتراضي
                      departmentIcon: Icons.computer,
                    ),
                  ),
                  (route) => false, // إزالة كل الصفحات السابقة
                );
              },
              child: Text(
                'عرض الكل',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.buttonPrimary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDepartmentsList() {
    // تحديد نوع البيانات بشكل صريح
    final List<Map<String, dynamic>> departments = [
      {'name': 'علوم الحاسوب', 'icon': Icons.computer},
      {'name': 'نظم المعلومات', 'icon': Icons.data_usage},
      {'name': 'الأنظمة الطبية', 'icon': Icons.medical_services},
      {'name': 'الأمن السيبراني', 'icon': Icons.security},
    ];

    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: departments.length,
        itemBuilder: (context, index) {
          return Container(
            width: 120,
            margin: const EdgeInsets.only(left: 12),
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: () => _showLoginDialog(),
                borderRadius: BorderRadius.circular(12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      departments[index]['icon'] as IconData,
                      color: AppColors.buttonPrimary,
                      size: 32,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      departments[index]['name']
                          as String, // تحويل صريح إلى String
                      style: AppTextStyles.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFeaturedCourses() {
    return SizedBox(
      height: 300, // تقليل الارتفاع
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: 5,
        itemBuilder: (context, index) => _buildFeaturedCourseCard(),
      ),
    );
  }

  Widget _buildFeaturedCourseCard() {
    return Container(
      width: 200,
      margin: const EdgeInsets.only(left: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showLoginDialog(),
          borderRadius: BorderRadius.circular(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  // صورة الكورس
                  ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(12)),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
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
                  // التقييم والسعر في الأعلى
                  Positioned(
                    left: 8,
                    right: 8,
                    top: 8,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // التقييم
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.buttonSecondary,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.star_rounded,
                                color: Colors.white,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '4.8',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // السعر
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
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
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // عنوان الكورس
                    Text(
                      'برمجة الهواتف الذكية',
                      style: AppTextStyles.titleMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    // الأقسام
                    SizedBox(
                      width: double.infinity, // لضمان عرض كامل
                      child: Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: [
                          _buildDepartmentChip('علوم الحاسوب'),
                          _buildDepartmentChip('نظم المعلومات'),
                          _buildDepartmentChip('الأنظمة الطبية'),
                          _buildDepartmentChip('الأمن السيبراني'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    // معلومات الكورس
                    Padding(
                      padding: const EdgeInsets.only(right: 0), // إزالة المسافة
                      child: Row(
                        children: [
                          _buildInfoChip(
                            icon: Icons.access_time_rounded,
                            label: '12 ساعة',
                          ),
                          const SizedBox(width: 8),
                          _buildInfoChip(
                            icon: Icons.videocam_rounded,
                            label: '24 فيديو',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    // المشاهدات
                    Row(
                      children: [
                        const Icon(
                          Icons.visibility_outlined,
                          size: 16,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '1.2K مشاهدة',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // مسار التقدم
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              'إكمال 75%',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Container(
                          width: double.infinity,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(2),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 160 * 0.75,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      AppColors.buttonSecondary,
                                      AppColors.buttonSecondary
                                          .withOpacity(0.7),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDepartmentChip(String name) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.primaryLight.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        name,
        style: AppTextStyles.bodySmall.copyWith(
          color: AppColors.buttonPrimary,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
      decoration: BoxDecoration(
        color: AppColors.primaryLight.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: AppColors.buttonPrimary,
            size: 14,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.buttonPrimary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLatestCourses() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.6, // تعديل النسبة لتناسب المحتوى الجديد
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: 4,
      itemBuilder: (context, index) => _buildCourseCard(),
    );
  }

  Widget _buildCourseCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showLoginDialog(),
          borderRadius: BorderRadius.circular(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  // صورة الكورس
                  ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(12)),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
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
                  // السعر والتقييم
                  Positioned(
                    left: 8,
                    right: 8,
                    top: 8,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // التقييم
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.buttonSecondary,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.star_rounded,
                                color: Colors.white,
                                size: 14,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                '4.8',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // السعر
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 3),
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
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // عنوان الكورس
                    Text(
                      'برمجة تطبيقات الهاتف',
                      style: AppTextStyles.titleMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    // الأقسام
                    Wrap(
                      spacing: 2,
                      runSpacing: 2,
                      children: [
                        _buildDepartmentChip('علوم الحاسوب'),
                        _buildDepartmentChip('نظم المعلومات'),
                        _buildDepartmentChip('الأنظمة الطبية'),
                        _buildDepartmentChip('الأمن السيبراني'),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // معلومات الكورس
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.access_time_rounded,
                              size: 14,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '12 ساعة',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            const Icon(
                              Icons.visibility_outlined,
                              size: 14,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '1.2K',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDepartmentSections() {
    final departments = [
      {'name': 'علوم الحاسوب', 'icon': Icons.computer},
      {'name': 'نظم المعلومات', 'icon': Icons.data_usage},
      {'name': 'الأنظمة الطبية', 'icon': Icons.medical_services},
      {'name': 'الأمن السيبراني', 'icon': Icons.security},
    ];

    // قائمة تجريبية للمراحل والكورسات
    final List<Map<String, dynamic>> coursesData = [
      {
        'title': 'مقدمة في البرمجة',
        'stage': 'المرحلة الأولى',
        'semester': 'الكورس الأول',
        'progress': 10,
        'rating': 4.8,
        'views': '1.2K',
        'duration': '12',
        'videos': '24',
      },
      {
        'title': 'البرمجة المتقدمة',
        'stage': 'المرحلة الأولى',
        'semester': 'الكورس الثاني',
        'progress': 45,
        'rating': 4.5,
        'views': '950',
        'duration': '15',
        'videos': '30',
      },
      // ...يمكن إضافة المزيد من الكورسات التجريبية
    ];

    return Column(
      children: departments.map((dept) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        dept['icon'] as IconData,
                        color: AppColors.buttonPrimary,
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${dept['name']}',
                        style: AppTextStyles.titleMedium.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: () => _showLoginDialog(),
                    child: Text(
                      'عرض الكل',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.buttonPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 255,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: coursesData.length,
                itemBuilder: (context, index) => _buildDepartmentCourseCard(
                  courseData: coursesData[index],
                  departmentName: dept['name'] as String,
                ),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildDepartmentCourseCard({
    required Map<String, dynamic> courseData,
    required String departmentName,
  }) {
    // Add type conversion for numerical values
    final progress = (courseData['progress'] as num).toDouble();
    final rating = (courseData['rating'] as num).toDouble();

    return Container(
      width: 200,
      margin: const EdgeInsets.only(left: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showLoginDialog(),
          borderRadius: BorderRadius.circular(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(12)),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
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
                  // السعر والتقييم
                  Positioned(
                    left: 8,
                    right: 8,
                    top: 8,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.buttonSecondary,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.star_rounded,
                                color: Colors.white,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                rating.toString(),
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '10 د.ع',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.buttonPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // عنوان الكورس
                    Text(
                      courseData['title'],
                      style: AppTextStyles.titleMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    // المرحلة والكورس
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 0, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${courseData['stage']} - ${courseData['semester']}',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.buttonPrimary,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // معلومات الكورس
                    Row(
                      children: [
                        _buildInfoChip(
                          icon: Icons.access_time_rounded,
                          label: '${courseData['duration']} ساعة',
                        ),
                        const SizedBox(width: 8),
                        _buildInfoChip(
                          icon: Icons.videocam_rounded,
                          label: '${courseData['videos']} فيديو',
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // المشاهدات والتقدم
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.visibility_outlined,
                              size: 16,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              courseData['views'],
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          'إكمال ${courseData['progress']}%',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // شريط التقدم
                    Container(
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
                                      AppColors.buttonSecondary
                                          .withOpacity(0.7),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLoginDialog() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (context) => const AuthRequiredDialog(),
    );
  }

  // إضافة دالة جديدة لبناء عناصر القائمة السفلية
  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required bool isSelected,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (index == 0) {
            // نحن بالفعل في صفحة التصفح
            return;
          } else if (index == 1) {
            // تعديل طريقة الانتقال لصفحة البحث
            Navigator.pushAndRemoveUntil(
              context,
              AppTransitions.smart(
                page: const DepartmentCoursesScreen(
                  departmentName: 'الكل',
                  departmentIcon: Icons.apps,
                ),
              ),
              (route) => false,
            );
          } else {
            _showLoginDialog();
          }
        },
        borderRadius: BorderRadius.circular(24),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 500), // زيادة مدة الانتقال
          curve: Curves.easeOutCubic, // تغيير نوع الانتقال ليكون أكثر سلاسة
          padding: EdgeInsets.symmetric(
            horizontal: isSelected ? 10 : 10,
            vertical: 12,
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.buttonSecondary.withOpacity(0.9)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.buttonSecondary.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSize(
                // إضافة انتقال سلس لتغيير حجم الأيقونة
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOut,
                child: Icon(
                  isSelected ? activeIcon : icon,
                  color: isSelected ? Colors.white : AppColors.hintColor,
                  size: isSelected ? 22 : 20,
                ),
              ),
              AnimatedSize(
                // انتقال سلس للنص
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOut,
                child: SizedBox(
                  width: isSelected ? null : 0,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.easeOut,
                    opacity: isSelected ? 1.0 : 0.0,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(width: isSelected ? 4 : 0),
                        Text(
                          label,
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
