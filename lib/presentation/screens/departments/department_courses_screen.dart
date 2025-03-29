import 'package:flutter/material.dart';
import 'package:mycourses/presentation/screens/home/guest_home_screen.dart';
import 'package:mycourses/presentation/widgets/auth_required_dialog.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/app_transitions.dart';
import '../../widgets/course_view_builder.dart';

class DepartmentCoursesScreen extends StatefulWidget {
  final String departmentName;
  final IconData departmentIcon;

  const DepartmentCoursesScreen({
    super.key,
    required this.departmentName,
    required this.departmentIcon,
  });

  @override
  State<DepartmentCoursesScreen> createState() =>
      _DepartmentCoursesScreenState();
}

class _DepartmentCoursesScreenState extends State<DepartmentCoursesScreen>
    with SingleTickerProviderStateMixin {
  String? selectedStage;
  String? selectedSemester;
  String? selectedDepartment;
  late AnimationController _drawerController;
  final int _currentIndex = 1;
  // ignore: non_constant_identifier_names
  final int _currentIndex_filter = 1;

  // قائمة المراحل
  final List<String> stages = [
    'الكل', // إضافة خيار الكل
    'المرحلة الأولى',
    'المرحلة الثانية',
    'المرحلة الثالثة',
    'المرحلة الرابعة',
  ];

  // قائمة الكورسات
  final List<String> semesters = [
    'الكل', // إضافة خيار الكل
    'الكورس الأول',
    'الكورس الثاني',
  ];

  // قائمة الأقسام
  final List<Map<String, dynamic>> departments = [
    {'name': 'الكل', 'icon': Icons.apps}, // إضافة خيار الكل
    {'name': 'علوم الحاسوب', 'icon': Icons.computer},
    {'name': 'نظم المعلومات', 'icon': Icons.data_usage},
    {'name': 'الأنظمة الطبية', 'icon': Icons.medical_services},
    {'name': 'الأمن السيبراني', 'icon': Icons.security},
  ];

  // إضافة متغير للفرز
  String _currentSort = 'الأحدث';
  bool _isShowingFeatured = false; // إضافة متغير للكورسات المميزة
  bool _isGridView = true;

  @override
  void initState() {
    super.initState();
    selectedDepartment = 'الكل';
    selectedStage = 'الكل';
    selectedSemester = 'الكل';
    _drawerController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _drawerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // عند الضغط على زر الرجوع، انتقل لصفحة التصفح
        Navigator.pushAndRemoveUntil(
          context,
          AppTransitions.smart(page: const GuestHomeScreen()),
          (route) => false,
        );
        return false; // منع السلوك الافتراضي للرجوع
      },
      child: Scaffold(
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
                _buildHeader(),
                _buildFilters(),
                Expanded(
                  child: _buildCoursesGrid(),
                ),
              ],
            ),
          ),
        ),
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
      ),
    );
  }

  // تحديث دالة بناء الهيدر لتكون أبسط وأوضح
  Widget _buildHeader() {
    return Column(
      children: [
        // Search field with new design
        _buildSearchField(),
        // Options row
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 0, 12, 0),
          child: Row(
            children: [
              // View mode toggle
              _buildOptionButton(
                icon: _isGridView ? Icons.view_list : Icons.grid_view,
                tooltip: _isGridView ? 'عرض قائمة' : 'عرض شبكي',
                isSelected: false,
                onPressed: () => setState(() => _isGridView = !_isGridView),
              ),
              const SizedBox(width: 8),

              // Sort options
              _buildOptionButton(
                icon: Icons.sort,
                tooltip: 'فرز حسب: $_currentSort',
                isSelected: _currentSort != 'الأحدث',
                onPressed: _showSortDialog,
              ),
              const SizedBox(width: 8),

              // Featured filter
              _buildOptionButton(
                icon: Icons.star_rounded,
                tooltip: 'الكورسات المميزة',
                isSelected: _isShowingFeatured,
                onPressed: () => setState(() {
                  _isShowingFeatured = !_isShowingFeatured;
                  _applyFilters();
                }),
              ),

              const Spacer(),

              // Active filters count
              if (_hasActiveFilters())
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.buttonSecondary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'عوامل التصفية: ${_getActiveFiltersCount()}',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.buttonSecondary,
                      fontSize: 11,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSearchField() {
    return Container(
      height: 45,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            AppColors.buttonSecondary.withOpacity(0.7),
            AppColors.buttonSecondary.withOpacity(0.8),
            AppColors.buttonSecondary.withOpacity(0.9),
          ],
          stops: [0.3, 0.7, 1.0],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: TextField(
          style: AppTextStyles.bodyMedium.copyWith(
            fontSize: 13,
            color: Colors.white, // تغيير لون النص للأبيض
            // color: AppColors.primaryBg,
            // color: AppColors.buttonPrimary,
          ),
          textAlignVertical: TextAlignVertical.center,
          decoration: InputDecoration(
            prefixIcon: Container(
              width: 40,
              margin: const EdgeInsets.symmetric(horizontal: 6),
              child: Row(
                children: [
                  Icon(
                    Icons.search_rounded,
                    color: Colors.white
                        .withOpacity(0.9), // تغيير لون الأيقونة للأبيض
                    size: 20,
                    // color: AppColors.buttonPrimary.withOpacity(0.7),
                  ),
                  Container(
                    height: 20,
                    width: 1,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    color:
                        Colors.white.withOpacity(0.2), // تغيير لون الخط الفاصل
                  ),
                ],
              ),
            ),
            suffixIcon: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white
                    .withOpacity(0.2), // تغيير لون خلفية أيقونة الفلتر
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.tune_rounded,
                color: Colors.white,
                // color: AppColors.buttonPrimary.withOpacity(0.7),

                size: 18,
              ),
            ),
            hintText: 'ابحث عن كورس...',
            hintStyle: AppTextStyles.bodyMedium.copyWith(
              fontSize: 13,
              color: Colors.white.withOpacity(0.7), // تغيير لون النص الإرشادي
              // color: AppColors.buttonPrimary.withOpacity(0.7),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            border: InputBorder.none,
          ),
          onChanged: (value) {
            // تطبيق البحث
          },
        ),
      ),
    );
  }

  Widget _buildOptionButton({
    required IconData icon,
    required String tooltip,
    required bool isSelected,
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.buttonSecondary.withOpacity(0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 20,
              color: isSelected
                  ? AppColors.buttonSecondary
                  : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  bool _hasActiveFilters() {
    return selectedDepartment != 'الكل' ||
        selectedStage != 'الكل' ||
        selectedSemester != 'الكل' ||
        _isShowingFeatured ||
        _currentSort != 'الأحدث';
  }

  int _getActiveFiltersCount() {
    int count = 0;
    if (selectedDepartment != 'الكل') count++;
    if (selectedStage != 'الكل') count++;
    if (selectedSemester != 'الكل') count++;
    if (_isShowingFeatured) count++;
    if (_currentSort != 'الأحدث') count++;
    return count;
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.all(12), // تصغير ال padding
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Department dropdown
          _buildFilterDropdown(
            items: departments.map((dept) => dept['name'] as String).toList(),
            value: selectedDepartment,
            hint: 'اختر القسم',
            onChanged: (value) => _onFilterChanged(value, 'department'),
            icon: Icon(
              departments.firstWhere(
                (dept) => dept['name'] == selectedDepartment,
                orElse: () => departments.first,
              )['icon'] as IconData,
              size: 18, // تصغير أيقونة القوائم المنسدلة
            ),
          ),
          const SizedBox(height: 8), // تقليل المسافة

          // Stage and Semester filters
          Row(
            children: [
              // Stage dropdown
              Expanded(
                child: _buildFilterDropdown(
                  items: stages,
                  value: selectedStage,
                  hint: 'المرحلة',
                  onChanged: (value) => _onFilterChanged(value, 'stage'),
                  icon: const Icon(Icons.school_outlined, size: 16),
                ),
              ),
              const SizedBox(width: 8), // تقليل المسافة
              // Semester dropdown
              Expanded(
                child: _buildFilterDropdown(
                  items: semesters,
                  value: selectedSemester,
                  hint: 'الكورس',
                  onChanged: (value) => _onFilterChanged(value, 'semester'),
                  icon: const Icon(Icons.calendar_today_outlined, size: 14),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // تحسين القوائم المنسدلة
  Widget _buildFilterDropdown({
    required List<String> items,
    required String? value,
    required String hint,
    required Function(String?) onChanged,
    required Widget icon,
  }) {
    bool isOpen = false;

    // حساب العرض الأقصى للنص في القائمة
    double getMaxTextWidth(BuildContext context) {
      final textPainter = TextPainter(
        textDirection: TextDirection.rtl,
        // Replace deprecated textScaleFactor with textScaler
        textScaler: MediaQuery.of(context).textScaler,
      );

      double maxWidth = 0;
      for (var item in items) {
        textPainter
          ..text = TextSpan(
            text: item,
            style: AppTextStyles.titleMedium.copyWith(
              fontSize: 13,
              color: Colors.white,
            ),
          )
          ..layout();
        maxWidth = maxWidth < textPainter.width ? textPainter.width : maxWidth;
      }

      // إضافة مساحة للأيقونة والهوامش
      return maxWidth + 50; // 50 = أيقونة (24) + هوامش (26)
    }

    return StatefulBuilder(
      builder: (context, setState) {
        final calculatedWidth = getMaxTextWidth(context);

        return Theme(
          data: Theme.of(context).copyWith(
            popupMenuTheme: PopupMenuThemeData(
              color: AppColors.buttonPrimary,
              elevation: 3,
              // التحكم بشكل القائمة المنسدلة
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          child: PopupMenuButton<String>(
            offset: const Offset(0, 8),
            position: PopupMenuPosition.under,
            // التحكم بأبعاد القائمة المنسدلة
            constraints: BoxConstraints(
              minWidth: calculatedWidth,
              maxWidth: calculatedWidth,
              // يمكنك إضافة minHeight و maxHeight إذا أردت التحكم بالارتفاع
            ),
            onSelected: (newValue) {
              onChanged(newValue);
              setState(() => isOpen = false);
            },
            onOpened: () => setState(() => isOpen = true),
            onCanceled: () => setState(() => isOpen = false),
            itemBuilder: (context) {
              final availableItems =
                  items.where((item) => item != value).toList();

              return availableItems.map((item) {
                // تحديد الأيقونة حسب نوع القائمة
                Widget itemIcon;
                if (hint == 'اختر القسم') {
                  final dept = departments.firstWhere(
                    (d) => d['name'] == item,
                    orElse: () => departments.first,
                  );
                  itemIcon = Icon(
                    dept['icon'] as IconData,
                    size: 16,
                    color: Colors.white,
                  );
                } else {
                  // للمراحل والكورسات - تغيير لون الأيقونة للأبيض
                  itemIcon = Icon(
                    (icon).icon,
                    size: 16,
                    color: Colors.white, // تعيين اللون للأبيض
                  );
                }

                return PopupMenuItem<String>(
                  height: 35,
                  value: item,
                  child: Row(
                    children: [
                      itemIcon, // استخدام الأيقونة المحددة
                      const SizedBox(width: 8),
                      Text(
                        item,
                        style: AppTextStyles.titleMedium.copyWith(
                          fontSize: 13,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 6), // تقليل الpadding
              decoration: BoxDecoration(
                color: isOpen
                    ? AppColors.buttonPrimary
                    : AppColors.buttonSecondary,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isOpen
                      ? Colors.white
                      : AppColors.buttonSecondary.withOpacity(0.1),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withOpacity(0.05),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(
                    (icon as Icon).icon,
                    size: 16, // تصغير حجم الأيقونة
                    color: isOpen ? Colors.white : Colors.white,
                  ),
                  const SizedBox(width: 6), // تقليل المسافة
                  Text(
                    value ?? hint,
                    style: AppTextStyles.titleMedium.copyWith(
                      fontSize: 13,
                      color: isOpen ? Colors.white : Colors.white,
                    ),
                  ),
                  const Spacer(),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: isOpen ? 1 : 0),
                    duration: const Duration(milliseconds: 200),
                    builder: (context, value, child) {
                      return Transform.rotate(
                        angle: value * 3.14159,
                        child: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: isOpen ? Colors.white : Colors.white,
                          size: 18, // تصغير حجم السهم
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCoursesGrid() {
    // Simulated courses data
    final List<Map<String, dynamic>> courses = List.generate(
      8,
      (index) => {
        'title': 'عنوان الكورس ${index + 1}',
        'rating': 4.5,
        'duration': '12 ساعة',
        'videos': '24 فيديو',
        'views': '1.2K',
        'progress': 75.0,
      },
    );

    if (courses.isEmpty) {
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

    return CourseViewBuilder(
      courses: courses,
      isGridView: _isGridView,
      onTapCourse: _showLoginDialog,
    );
  }

  Widget _buildCourseCard(Map<String, dynamic> course) {
    // Add type conversion for progress
    final progress = (course['progress'] as num).toDouble();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8), // تقليل التقويس
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
          onTap: () => _showLoginDialog(),
          borderRadius: BorderRadius.circular(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Course thumbnail with rating and price
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(8)), // تقليل تقويس الصورة
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
                  // Rating and price
                  Positioned(
                    left: 6,
                    right: 6,
                    top: 6,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Rating
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
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
                                size: 15,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                course['rating'].toString(),
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11, // تصغير حجم التقييم
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Price
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
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
                              fontSize: 11, // تصغير حجم السعر
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              // Course info
              Padding(
                padding: const EdgeInsets.all(8), // تقليل padding المحتوى
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      course['title'],
                      style: AppTextStyles.titleMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 13, // تصغير حجم العنوان
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    // Duration and videos count
                    Row(
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
                    ),
                    const SizedBox(height: 6),
                    // Views and progress
                    Row(
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
                    ),
                    const SizedBox(height: 4),
                    // Progress bar
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
                                width: constraints.maxWidth *
                                    (progress /
                                        100), // استخدام العرض الكامل للحاوية
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

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 0, vertical: 2), // تصغير padding
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
            size: 13, // تصغير حجم الأيقونة
          ),
          const SizedBox(width: 3),
          Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.buttonPrimary,
              fontSize: 11, // تصغير حجم النص
            ),
          ),
        ],
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

  // دوال إضافية للتصفية والفرز
  void _showSortDialog() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.sort),
              title: const Text('الأحدث'),
              selected: _currentSort == 'الأحدث',
              onTap: () => _selectSortOption('الأحدث'),
            ),
            ListTile(
              leading: const Icon(Icons.star_rate_rounded),
              title: const Text('المميز'),
              selected: _currentSort == 'المميز',
              onTap: () => _selectSortOption('المميز'),
            ),
            ListTile(
              leading: const Icon(Icons.trending_up),
              title: const Text('الأكثر مشاهدة'),
              selected: _currentSort == 'الأكثر مشاهدة',
              onTap: () {
                setState(() => _currentSort = 'الأكثر مشاهدة');
                Navigator.pop(context);
                _applySorting();
              },
            ),
            ListTile(
              leading: const Icon(Icons.star_outline),
              title: const Text('الأعلى تقييماً'),
              selected: _currentSort == 'الأعلى تقييماً',
              onTap: () {
                setState(() => _currentSort = 'الأعلى تقييماً');
                Navigator.pop(context);
                _applySorting();
              },
            ),
            ListTile(
              leading: const Icon(Icons.sort_by_alpha),
              title: const Text('أبجدياً'),
              selected: _currentSort == 'أبجدياً',
              onTap: () {
                setState(() => _currentSort = 'أبجدياً');
                Navigator.pop(context);
                _applySorting();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _applySorting() {
    // تطبيق الفرز على القائمة حسب الاختيار
    setState(() {
      switch (_currentSort) {
        case 'الأحدث':
          // ترتيب حسب تاريخ الإضافة
          break;
        case 'الأكثر مشاهدة':
          // ترتيب حسب عدد المشاهدات
          break;
        case 'الأعلى تقييماً':
          // ترتيب حسب التقييم
          break;
        case 'أبجدياً':
          // ترتيب أبجدي
          break;
        case 'المميز':
          // عرض الكورسات المميزة أولاً
          break;
      }
    });
  }

  void _showFilterDialog() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // إضافة خيار الكورسات المميزة
            SwitchListTile(
              title: const Text('الكورسات المميزة فقط'),
              value: _isShowingFeatured,
              onChanged: (value) {
                setState(() {
                  _isShowingFeatured = value;
                  Navigator.pop(context);
                  _applyFilters(); // دالة جديدة لتطبيق الفلترة
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  // دالة جديدة لتطبيق الفلترة
  void _applyFilters() {
    setState(() {
      // تطبيق الفلترة حسب القيم المختارة
      if (_isShowingFeatured) {
        // عرض الكورسات المميزة فقط
      }
      if (selectedDepartment != 'الكل') {
        // فلترة حسب القسم
      }
      if (selectedStage != 'الكل') {
        // فلترة حسب المرحلة
      }
      if (selectedSemester != 'الكل') {
        // فلترة حسب الكورس
      }
    });
  }

  void _selectSortOption(String option) {
    setState(() {
      _currentSort = option;
      Navigator.pop(context);
      _applySorting();
    });
  }

  // تحديث دالة تطبيق التغييرات على القوائم المنسدلة
  void _onFilterChanged(String? value, String filterType) {
    setState(() {
      switch (filterType) {
        case 'department':
          selectedDepartment = value ?? 'الكل';
          break;
        case 'stage':
          selectedStage = value ?? 'الكل';
          break;
        case 'semester':
          selectedSemester = value ?? 'الكل';
          break;
      }
      _applyFilters(); // تطبيق الفلترة عند تغيير أي قائمة
    });
  }

  // إضافة دالة _buildNavItem
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
            // تعديل طريقة العودة لصفحة التصفح
            Navigator.pushAndRemoveUntil(
              context,
              AppTransitions.smart(
                page: const GuestHomeScreen(),
              ),
              (route) => false,
            );
          } else if (index == 1) {
            // نحن بالفعل في صفحة البحث
            return;
          } else {
            _showLoginDialog();
          }
        },
        borderRadius: BorderRadius.circular(24),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutCubic,
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
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOut,
                child: Icon(
                  isSelected ? activeIcon : icon,
                  color: isSelected ? Colors.white : AppColors.hintColor,
                  size: isSelected ? 22 : 20,
                ),
              ),
              AnimatedSize(
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
