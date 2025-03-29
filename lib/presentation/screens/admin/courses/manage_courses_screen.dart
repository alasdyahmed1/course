import 'package:flutter/material.dart';
import 'package:mycourses/core/services/supabase_service.dart';
import 'package:mycourses/presentation/screens/admin/courses/course_videos_screen.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/services/admin_service.dart';
import '../../../../core/utils/number_formatter.dart';
import '../../../../core/utils/view_options.dart';
import '../../../../models/course.dart';
import 'add_course_screen.dart';
import 'edit_course_screen.dart'; // إضافة استيراد صفحة التعديل

class ManageCoursesScreen extends StatefulWidget {
  const ManageCoursesScreen({super.key});

  @override
  State<ManageCoursesScreen> createState() => _ManageCoursesScreenState();
}

class _ManageCoursesScreenState extends State<ManageCoursesScreen> {
  ViewType _currentViewType = ViewType.list;
  bool _isLoading = true;
  String _searchQuery = '';
  List<Course> _courses = [];
  String? _selectedDepartment;
  String? _selectedStage;
  String? _selectedSemester;

  // إضافة متغير للفرز
  String _currentSort = 'latest'; // القيمة الافتراضية: الأحدثالأحدث

  // إضافة المتغيرات المفقودة
  String? selectedDepartmentId;
  String? selectedStageId;
  String? selectedSemesterId;

  // إضافة قائمة للكورسات الأصلية
  List<Course> _originalCourses = [];

  // قوائم البيانات للفلترة
  List<Map<String, dynamic>> departments = [
    {'id': 'all', 'name': 'الكل'},
    {'id': '5a622568-39ef-4866-ab5e-1cb41684964e', 'name': 'علوم الحاسوب'},
    {'id': 'a5eecb99-b6d1-4bf1-acb3-8e19848318e7', 'name': 'نظم المعلومات'},
    {'id': '60449345-0d87-40f5-8176-0b4c699d5e84', 'name': 'الأنظمة الطبية'},
    {'id': '32ddfbb3-4e20-4b67-87f2-08d89ea916b4', 'name': 'الأمن السيبراني'},
  ];

  List<Map<String, dynamic>> stages = [
    {'id': 'all', 'name': 'الكل'},
    {'id': '52c795f4-18e9-4c01-aad0-b2243a8238ae', 'name': 'المرحلة الأولى'},
    {'id': 'ef997333-4393-49b0-b8db-f541c8064389', 'name': 'المرحلة الثانية'},
    {'id': '9e2f2bed-9285-454c-840e-bdc9eb6bb2b2', 'name': 'المرحلة الثالثة'},
    {'id': '682bc908-818e-4027-9a13-78e4941a6735', 'name': 'المرحلة الرابعة'},
  ];

  List<Map<String, dynamic>> semesters = [
    {'id': 'all', 'name': 'الكل'},
    {'id': '1', 'name': 'الكورس الأول'},
    {'id': '2', 'name': 'الكورس الثاني'},
  ];

  @override
  void initState() {
    super.initState();
    _loadCourses();
  }

  Future<void> _loadCourses() async {
    try {
      setState(() => _isLoading = true);
      final courses = await AdminService.getCourses();
      setState(() {
        _originalCourses = courses; // حفظ النسخة الأصلية
        _courses = courses;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحميل البيانات: $e')),
        );
      }
    }
  }

  Future<void> _loadSemesters(String departmentId, String stageId) async {
    try {
      // تجنب تحميل الفصول إذا كان أي من المعرفات 'all'
      if (departmentId == 'all' || stageId == 'all') {
        setState(() {
          semesters = [
            {'id': 'all', 'name': 'الكل'},
            {
              'id': '123e4567-e89b-12d3-a456-426614174020',
              'name': 'الكورس الأول'
            },
            {
              'id': '123e4567-e89b-12d3-a456-426614174021',
              'name': 'الكورس الثاني'
            },
          ];
        });
        return;
      }

      final response = await SupabaseService.supabase
          .from('semesters')
          .select()
          .eq('department_id', departmentId)
          .eq('stage_id', stageId)
          .order('semester_number');

      setState(() {
        semesters = [
          {'id': 'all', 'name': 'الكل'},
          ...(response as List).map((s) => {
                'id': s['id'],
                'name': s['name'],
              })
        ];
      });
    } catch (e) {
      print('Error loading semesters: $e');
      // إعادة تعيين قائمة الفصول للقيم الافتراضية في حالة الخطأ
      setState(() {
        semesters = [
          {'id': 'all', 'name': 'الكل'},
          {
            'id': '123e4567-e89b-12d3-a456-426614174020',
            'name': 'الكورس الأول'
          },
          {
            'id': '123e4567-e89b-12d3-a456-426614174021',
            'name': 'الكورس الثاني'
          },
        ];
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('حدث خطأ في تحميل الفصول')),
        );
      }
    }
  }

  // إضافة دالة مساعدة لتنسيق الأرقام
  String _formatNumber(num number) {
    if (number == 0) return '0';
    return number.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},');
  }

  Widget _buildSearchAndFilters() {
    final activeFiltersCount = _getActiveFiltersCount();

    return Container(
      padding: const EdgeInsets.all(8),
      margin: const EdgeInsets.only(top: 0), // تقليل المساحة الفارغة فوق البحث
      child: Column(
        children: [
          // شريط البحث
          TextField(
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
                _courses = _filterCourses();
                _applySorting();
              });
            },
            decoration: InputDecoration(
              hintText: 'ابحث عن كورس...',
              prefixIcon: const Icon(Icons.search, size: 20),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: const BorderSide(
                  color: AppColors.buttonPrimary, // تغيير لون الإطار
                  width: 1.0,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: const BorderSide(
                  color: AppColors
                      .buttonPrimary, // تغيير لون الإطار في الحالة العادية
                  width: 1.0,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: const BorderSide(
                  color:
                      AppColors.buttonPrimary, // تغيير لون الإطار عند التركيز
                  width: 1.5,
                ),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          const SizedBox(height: 8),

          // عداد الفلاتر النشطة
          if (activeFiltersCount > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 0),
              child: Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.buttonPrimary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'الفلاتر النشطة: $activeFiltersCount',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: _clearAllFilters,
                    child: Text(
                      'مسح الكل',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.buttonPrimary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // الفلاتر
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildQuickFilter(
                  icon: Icons.school,
                  label: _selectedDepartment ?? 'القسم',
                  isSelected: _selectedDepartment != null,
                  onTap: () => _showFilterOptions('department', departments),
                ),
                _buildQuickFilter(
                  icon: Icons.class_,
                  label: _selectedStage ?? 'المرحلة',
                  isSelected: _selectedStage != null,
                  onTap: () => _showFilterOptions('stage', stages),
                ),
                _buildQuickFilter(
                  icon: Icons.bookmark,
                  label: _selectedSemester ?? 'الكورس',
                  isSelected: _selectedSemester != null,
                  onTap: () => _showFilterOptions('semester', semesters),
                ),
                _buildQuickFilter(
                  icon: Icons.sort,
                  label: 'ترتيب: ${_getSortLabel()}',
                  isSelected: _currentSort != 'latest',
                  onTap: _showSortOptions,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Container(
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
          child: Column(
            children: [
              // شريط البحث المدمج مع الأزرار
              _buildCompactSearchBar(),

              // إضافة الفلاتر
              _buildFilters(),

              Expanded(
                child: Container(
                  margin:
                      const EdgeInsets.only(top: 8), // تقليل الهامش العلوي هنا
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                  ),
                  child: Stack(
                    children: [
                      _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : _buildCoursesList(),
                      // Positioned(
                      //   bottom: 16,
                      //   left: 16,
                      //   child: FloatingActionButton(
                      //     onPressed: () async {
                      //       final result = await Navigator.push(
                      //         context,
                      //         MaterialPageRoute(
                      //             builder: (_) => const AddCourseScreen()),
                      //       );
                      //       if (result == true) {
                      //         _loadCourses();
                      //       }
                      //     },
                      //     backgroundColor: AppColors.buttonPrimary,
                      //     child: const Icon(Icons.add, color: Colors.white),
                      //   ),
                      // ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // إضافة دالة جديدة لبناء شريط البحث المدمج مع أزرار الإجراءات
  Widget _buildCompactSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // زر إضافة كورس على اليمين
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddCourseScreen()),
              );
              if (result == true) {
                _loadCourses();
              }
            },
            color: AppColors.buttonPrimary,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 8),

          // حقل البحث في المنتصف (بحجم أصغر)
          Expanded(
            child: SizedBox(
              height: 40, // تقليل ارتفاع حقل البحث
              child: TextField(
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                    _courses = _filterCourses();
                    _applySorting();
                  });
                },
                decoration: InputDecoration(
                  hintText: 'ابحث عن كورس...',
                  hintStyle: const TextStyle(fontSize: 13),
                  prefixIcon: const Icon(Icons.search, size: 18),
                  contentPadding: EdgeInsets.zero,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: const BorderSide(
                      color: AppColors.buttonPrimary,
                      width: 1.0,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: const BorderSide(
                      color: AppColors.buttonPrimary,
                      width: 1.0,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: const BorderSide(
                      color: AppColors.buttonPrimary,
                      width: 1.5,
                    ),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ),

          // زر تغيير العرض على اليسار بجانب حقل البحث
          const SizedBox(width: 8),
          _buildViewToggleButton(),
        ],
      ),
    );
  }

  Widget _buildQuickFilter({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: Material(
        color: isSelected ? AppColors.buttonSecondary : Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  label == 'ترتيب' ? 'ترتيب: ${_getSortLabel()}' : label,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: isSelected ? Colors.white : AppColors.textSecondary,
                    fontWeight: isSelected ? FontWeight.bold : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCoursesList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_courses.isEmpty) {
      return _buildEmptyState();
    }

    final viewOption =
        viewOptions.firstWhere((o) => o.type == _currentViewType);

    switch (_currentViewType) {
      case ViewType.grid:
        return GridView.builder(
          padding: viewOption.padding,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: viewOption.crossAxisCount,
            childAspectRatio: viewOption.childAspectRatio,
            mainAxisSpacing: viewOption.spacing,
            crossAxisSpacing: viewOption.spacing,
          ),
          itemCount: _courses.length,
          itemBuilder: (context, index) => _buildCourseCard(_courses[index]),
        );

      case ViewType.horizontal:
        return ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: viewOption.padding,
          itemCount: _courses.length,
          itemBuilder: (context, index) => SizedBox(
            width: 280,
            child: Padding(
              padding: EdgeInsets.only(right: viewOption.spacing),
              child: _buildCourseCard(_courses[index]),
            ),
          ),
        );

      case ViewType.masonry:
        return GridView.builder(
          padding: viewOption.padding,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: viewOption.crossAxisCount,
            childAspectRatio: viewOption.childAspectRatio,
            mainAxisSpacing: viewOption.spacing,
            crossAxisSpacing: viewOption.spacing,
          ),
          itemCount: _courses.length,
          itemBuilder: (context, index) => _buildCourseCard(
            _courses[index],
            height: index.isEven ? 280 : 320,
          ),
        );

      case ViewType.cardStack:
        return ListView.builder(
          padding: viewOption.padding,
          itemCount: _courses.length,
          itemBuilder: (context, index) => Padding(
            padding: EdgeInsets.only(bottom: viewOption.spacing),
            child: _buildCourseCard(
              _courses[index],
              elevation: 4,
              margin: const EdgeInsets.symmetric(horizontal: 12),
            ),
          ),
        );

      case ViewType.list:
      default: // Agregar default case para manejar todos los casos posibles
        return ListView.separated(
          padding: viewOption.padding,
          itemCount: _courses.length,
          separatorBuilder: (context, index) =>
              SizedBox(height: viewOption.spacing),
          itemBuilder: (context, index) => _buildCourseCard(_courses[index]),
        );
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.school_outlined,
            size: 64,
            color: AppColors.textSecondary.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'لا توجد كورسات مضافة',
            style: AppTextStyles.titleMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddCourseScreen()),
            ),
            icon: const Icon(Icons.add),
            label: const Text(
              'إضافة كورس جديد',
            ),
          ),
        ],
      ),
    );
  }

  // تحسين دالة الحصول على رابط URL للصور مع تفضيل Bunny.net
  String _getOptimizedImageUrl(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return 'https://via.placeholder.com/150';
    }

    // تحقق من سلامة الرابط قبل تمريره للمحسّن
    if (imageUrl.contains('https:/') && !imageUrl.contains('https://')) {
      debugPrint('تصحيح رابط غير صالح: $imageUrl');
      // إصلاح روابط مثل https:/myzoneit32.b-cdn.net إلى https://myzoneit32.b-cdn.net
      imageUrl = imageUrl.replaceFirst('https:/', 'https://');
    }

    // طباعة تشخيصية أولية
    debugPrint('معالجة عنوان الصورة: $imageUrl');

    final optimizedUrl = AdminService.optimizeImageUrl(imageUrl);

    // معلومات تشخيصية إضافية
    debugPrint('النتيجة النهائية: $optimizedUrl');

    // التحقق من صحة الرابط النهائي
    if (!optimizedUrl.startsWith('http://') &&
        !optimizedUrl.startsWith('https://')) {
      debugPrint(
          '⚠️ تحذير: الرابط النهائي غير صالح - لا يبدأ ببروتوكول صحيح: $optimizedUrl');
    }

    if (imageUrl != optimizedUrl) {
      debugPrint('تم تحسين مسار الصورة من:');
      debugPrint('- الأصلي: $imageUrl');
      debugPrint('- إلى: $optimizedUrl');
    }

    return optimizedUrl;
  }

  Widget _buildCourseCard(
    Course course, {
    double? height,
    double elevation = 1,
    EdgeInsets? margin,
  }) {
    // Format duration in hours and minutes
    final hours = course.totalDuration ~/ 60;
    final minutes = course.totalDuration % 60;
    final durationText = hours > 0
        ? '$hours ساعة ${minutes > 0 ? 'و $minutes دقيقة' : ''}'
        : minutes > 0
            ? '$minutes دقيقة'
            : '0 دقيقة';

    // Calculate pricing details
    String priceDisplay;
    String? discountBadge;

    if (course.pricing == null || course.pricing!.price == 0) {
      priceDisplay = 'مجاني';
    } else {
      final originalPrice = course.pricing!.price.toInt();
      if (course.pricing!.discountPrice != null) {
        final discount = course.pricing!.discountPrice!.toInt();
        final finalPrice = originalPrice - discount;
        final discountPercentage = ((discount / originalPrice) * 100).round();

        priceDisplay = '${_formatNumber(finalPrice)} د.ع';
        discountBadge = 'خصم $discountPercentage%';
      } else {
        priceDisplay = '${_formatNumber(originalPrice)} د.ع';
      }
    }

    // تحسين عرض السعر والخصم
    Widget buildPriceWidget() {
      if (course.pricing == null || course.pricing!.price == 0) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.green.shade500,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            'مجاني',
            style: AppTextStyles.bodySmall.copyWith(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      }

      final originalPrice = course.pricing!.price.toInt();
      if (course.pricing!.discountPrice != null) {
        final discount = course.pricing!.discountPrice!.toInt();
        final finalPrice = originalPrice - discount;
        final discountPercentage = ((discount / originalPrice) * 100).round();

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.red.shade500,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    NumberFormatter.formatCurrency(originalPrice),
                    style: AppTextStyles.bodySmall.copyWith(
                      color: Colors.white70,
                      fontSize: 8,
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                  Text(
                    NumberFormatter.formatCurrency(finalPrice),
                    style: AppTextStyles.bodySmall.copyWith(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Container(
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$discountPercentage%-',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: Colors.red.shade500,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      }

      // السعر العادي بدون خصم
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.buttonPrimary,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          NumberFormatter.formatCurrency(originalPrice),
          style: AppTextStyles.bodySmall.copyWith(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    // تحسين عرض التقييم
    Widget buildRatingWidget() {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.amber.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.amber.shade200, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.star_rounded,
              size: 14,
              color: Colors.amber.shade700,
            ),
            const SizedBox(width: 2),
            Text(
              course.rating.toStringAsFixed(1),
              style: AppTextStyles.bodySmall.copyWith(
                color: Colors.amber.shade900,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    // احصل على URL محسن للصورة من Bunny.net أو Supabase مع التحقق من صحته
    String optimizedImageUrl = _getOptimizedImageUrl(course.thumbnailUrl);

    // تأكد من أن الرابط يحتوي على بروتوكول صحيح
    if (optimizedImageUrl.contains('https:/') &&
        !optimizedImageUrl.contains('https://')) {
      debugPrint('⚠️ إصلاح رابط غير صحيح قبل عرض الصورة: $optimizedImageUrl');
      optimizedImageUrl = optimizedImageUrl.replaceFirst('https:/', 'https://');
    }

    // طباعة إضافية لتصحيح المشكلة
    if (course.thumbnailUrl != null) {
      debugPrint('صورة الكورس "${course.title}":');
      debugPrint('- المخزنة في قاعدة البيانات: ${course.thumbnailUrl}');
      debugPrint('- بعد التحسين النهائي: $optimizedImageUrl');
    }

    debugPrint('عرض الصورة من: $optimizedImageUrl');

    return Container(
      width: 200,
      height: height,
      margin: margin ?? const EdgeInsets.only(left: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: elevation * 2,
            offset: Offset(0, elevation),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _editCourse(course),
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Thumbnail Section
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(12)),
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
                            child: course.thumbnailUrl != null
                                ? Image.network(
                                    optimizedImageUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      debugPrint(
                                          '❌ خطأ في تحميل الصورة: $error - المصدر: $optimizedImageUrl');
                                      return _buildPlaceholderThumbnail();
                                    },
                                  )
                                : _buildPlaceholderThumbnail(),
                          ),
                        ),
                      ),
                      // تعديل موضع وتصميم السعر والتقييم
                      Positioned(
                        left: 8,
                        right: 8,
                        top: 8,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            buildRatingWidget(),
                            buildPriceWidget(),
                          ],
                        ),
                      ),
                    ],
                  ),
                  // Course Details
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          course.title,
                          style: AppTextStyles.titleMedium.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        // Department Details
                        if (course.departmentDetails.isNotEmpty) ...[
                          Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            children: course.departmentDetails.map((dept) {
                              return _buildDepartmentChip(
                                  '${dept.departmentName} - ${dept.stageName} - ${dept.semesterName}');
                            }).toList(),
                          ),
                          const SizedBox(height: 8),
                        ],
                        // Course Stats
                        Row(
                          children: [
                            _buildInfoChip(
                              icon: Icons.access_time_rounded,
                              label: durationText,
                              iconColor: Colors.blue,
                              backgroundColor: Colors.blue.withOpacity(0.1),
                              borderColor: Colors.blue.withOpacity(0.2),
                            ),
                            const SizedBox(width: 8),
                            _buildInfoChip(
                              icon: Icons.videocam_rounded,
                              label:
                                  '${_formatNumber(course.totalVideos)} فيديو',
                              iconColor: Colors.green,
                              backgroundColor: Colors.green.withOpacity(0.1),
                              borderColor: Colors.green.withOpacity(0.2),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _buildInfoChip(
                              icon: Icons.remove_red_eye_outlined,
                              label:
                                  '${_formatNumber(course.ratingsCount)} مشاهدة',
                              iconColor: Colors.purple,
                              backgroundColor: Colors.purple.withOpacity(0.1),
                              borderColor: Colors.purple.withOpacity(0.2),
                            ),
                            const Spacer(),
                            if (course.ratingsCount > 0)
                              _buildInfoChip(
                                icon: Icons.star_rounded,
                                label: course.rating.toStringAsFixed(1),
                                iconColor: Colors.amber,
                                backgroundColor: Colors.amber.withOpacity(0.1),
                                borderColor: Colors.amber.withOpacity(0.2),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              // إضافة أزرار التعديل والحذف وإدارة الفيديوهات
              Positioned(
                bottom: 8,
                left: 8,
                child: Row(
                  children: [
                    _buildActionButton(
                      icon: Icons.edit,
                      color: Colors.blue,
                      onTap: () => _editCourse(course),
                    ),
                    const SizedBox(width: 8),
                    _buildActionButton(
                      icon: Icons.videocam,
                      color: Colors.green,
                      onTap: () => _manageCourseVideos(course),
                    ),
                    const SizedBox(width: 8),
                    _buildActionButton(
                      icon: Icons.delete,
                      color: Colors.red,
                      onTap: () => _deleteCourse(course),
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

  Widget _buildPlaceholderThumbnail() {
    return Container(
      color: AppColors.primaryLight.withOpacity(0.1),
      child: const Icon(
        Icons.play_circle_outlined,
        size: 32,
        color: AppColors.accent,
      ),
    );
  }

  Widget _buildDepartmentsList(List<String> items) {
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: items.map((item) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.buttonSecondary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            item,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.buttonSecondary,
              fontSize: 10,
            ),
          ),
        );
      }).toList(),
    );
  }

  void _applySorting() {
    // أولاً نقوم بتصفية الكورسات حسب المعايير المحددة
    var filteredCourses = _filterCourses();

    // ثم نقوم بالفرز
    setState(() {
      switch (_currentSort) {
        case 'latest':
          filteredCourses.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          break;
        case 'oldest':
          filteredCourses.sort((a, b) => a.createdAt.compareTo(b.createdAt));
          break;
        case 'name_asc':
          filteredCourses.sort((a, b) => a.title.compareTo(b.title));
          break;
        case 'name_desc':
          filteredCourses.sort((a, b) => b.title.compareTo(a.title));
          break;
        case 'rating':
          filteredCourses.sort((a, b) => b.rating.compareTo(a.rating));
          break;
        case 'views':
          filteredCourses
              .sort((a, b) => b.ratingsCount.compareTo(a.ratingsCount));
          break;
      }
      _courses = filteredCourses;
    });
  }

  // إضافة دالة تصفية الكورسات
  List<Course> _filterCourses() {
    // نبدأ بالنسخة الأصلية دائماً
    List<Course> filteredCourses = List.from(_originalCourses);

    // تصفية حسب البحث
    if (_searchQuery.isNotEmpty) {
      filteredCourses = filteredCourses.where((course) {
        return course.title.toLowerCase().contains(_searchQuery.toLowerCase());
      }).toList();
    }

    // تصفية حسب القسم
    if (selectedDepartmentId != null && selectedDepartmentId != 'all') {
      filteredCourses = filteredCourses.where((course) {
        return course.departmentDetails
            .any((dept) => dept.departmentId == selectedDepartmentId);
      }).toList();
    }

    // تصفية حسب المرحلة
    if (selectedStageId != null && selectedStageId != 'all') {
      filteredCourses = filteredCourses.where((course) {
        return course.departmentDetails
            .any((dept) => dept.stageId == selectedStageId);
      }).toList();
    }

    // تصفية حسب الفصل
    if (selectedSemesterId != null && selectedSemesterId != 'all') {
      filteredCourses = filteredCourses.where((course) {
        return course.departmentDetails
            .any((dept) => dept.semesterId == selectedSemesterId);
      }).toList();
    }

    return filteredCourses;
  }

  // إضافة دالة لحساب عدد الفلاتر النشطة
  int _getActiveFiltersCount() {
    int count = 0;
    if (_searchQuery.isNotEmpty) count++;
    if (selectedDepartmentId != null && selectedDepartmentId != 'all') count++;
    if (selectedStageId != null && selectedStageId != 'all') count++;
    if (selectedSemesterId != null && selectedSemesterId != 'all') count++;
    return count;
  }

  void _editCourse(Course course) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditCourseScreen(course: course),
      ),
    ).then((result) {
      // إذا عاد المستخدم من صفحة التعديل وكان هناك تحديث، قم بإعادة تحميل الكورسات
      if (result == true) {
        _loadCourses();
      }
    });
  }

  void _deleteCourse(Course course) {
    // عرض مربع حوار للتأكيد قبل الحذف
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: Text('هل أنت متأكد من حذف الكورس "${course.title}"؟'),
        actions: [
          // زر إلغاء
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          // زر تأكيد الحذف
          TextButton(
            onPressed: () async {
              Navigator.pop(context); // إغلاق مربع الحوار أولاً

              // عرض مؤشر التحميل
              setState(() => _isLoading = true);

              try {
                // استدعاء دالة حذف الكورس
                final result = await AdminService.deleteCourse(course.id);

                if (result) {
                  // إعادة تحميل الكورسات بعد النجاح
                  _loadCourses();

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content:
                              Text('تم حذف الكورس "${course.title}" بنجاح')),
                    );
                  }
                }
              } catch (e) {
                setState(() => _isLoading = false);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('فشل في حذف الكورس: $e')),
                  );
                }
              }
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }

  void _showFilterOptions(String filterType, List<Map<String, dynamic>> items) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                _getFilterTitle(filterType),
                style: AppTextStyles.titleMedium.copyWith(
                  color: AppColors.buttonPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  final isSelected = _isItemSelected(filterType, item['id']);

                  return ListTile(
                    leading: Icon(
                      _getFilterIcon(filterType),
                      color: isSelected ? AppColors.buttonPrimary : null,
                    ),
                    title: Text(item['name']),
                    selected: isSelected,
                    onTap: () {
                      _onFilterItemSelected(filterType, item['id']);
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getFilterTitle(String filterType) {
    switch (filterType) {
      case 'department':
        return 'اختر القسم';
      case 'stage':
        return 'اختر المرحلة';
      case 'semester':
        return 'اختر الفصل الدراسي';
      default:
        return '';
    }
  }

  IconData _getFilterIcon(String filterType) {
    switch (filterType) {
      case 'department':
        return Icons.category;
      case 'stage':
        return Icons.school;
      case 'semester':
        return Icons.calendar_today;
      default:
        return Icons.filter_list;
    }
  }

  bool _isItemSelected(String filterType, String itemId) {
    switch (filterType) {
      case 'department':
        return selectedDepartmentId == itemId;
      case 'stage':
        return selectedStageId == itemId;
      case 'semester':
        return selectedSemesterId == itemId;
      default:
        return false;
    }
  }

  Widget _buildDepartmentChip(String name) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.accent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.accent.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icon(
          //   Icons.school_outlined,
          //   size: 9,
          //   color: AppColors.accent,
          // ),
          // const SizedBox(width: 1),
          Text(
            name,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.accent,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    Color? iconColor,
    Color? backgroundColor,
    Color? borderColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.primaryLight.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: borderColor ?? AppColors.primaryLight.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: iconColor ?? AppColors.buttonPrimary,
            size: 14,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: iconColor ?? AppColors.buttonPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _getSortLabel() {
    switch (_currentSort) {
      case 'latest':
        return 'الأحدث';
      case 'oldest':
        return 'الأقدم';
      case 'name_asc':
        return 'الاسم: أ-ي';
      case 'name_desc':
        return 'الاسم: ي-أ';
      case 'rating':
        return 'الأعلى تقييماً';
      case 'views':
        return 'الأكثر مشاهدة';
      default:
        return 'ترتيب';
    }
  }

  void _showSortOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: Colors.grey.shade200,
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Text(
                    'ترتيب حسب',
                    style: AppTextStyles.titleMedium.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  // زر إغلاق
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildSortOption(
                      title: 'الأحدث',
                      subtitle: 'ترتيب حسب تاريخ الإضافة',
                      icon: Icons.access_time,
                      value: 'latest',
                    ),
                    _buildSortOption(
                      title: 'الأقدم',
                      subtitle: 'ترتيب من الأقدم للأحدث',
                      icon: Icons.history,
                      value: 'oldest',
                    ),
                    _buildSortOption(
                      title: 'الاسم: أ-ي',
                      subtitle: 'ترتيب أبجدي تصاعدي',
                      icon: Icons.sort_by_alpha,
                      value: 'name_asc',
                    ),
                    _buildSortOption(
                      title: 'الاسم: ي-أ',
                      subtitle: 'ترتيب أبجدي تنازلي',
                      icon: Icons.sort_by_alpha,
                      value: 'name_desc',
                    ),
                    _buildSortOption(
                      title: 'الأعلى تقييماً',
                      subtitle: 'ترتيب حسب تقييم الطلاب',
                      icon: Icons.star,
                      value: 'rating',
                    ),
                    _buildSortOption(
                      title: 'الأكثر مشاهدة',
                      subtitle: 'ترتيب حسب عدد المشاهدات',
                      icon: Icons.visibility,
                      value: 'views',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSortOption({
    required String title,
    required String subtitle,
    required IconData icon,
    required String value,
  }) {
    final isSelected = _currentSort == value;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() => _currentSort = value);
          _applySorting();
          Navigator.pop(context);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              // أيقونة الخيار
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.buttonPrimary
                      : AppColors.primaryLight.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: isSelected ? Colors.white : AppColors.buttonPrimary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              // نص الخيار
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: isSelected ? FontWeight.bold : null,
                        color: isSelected
                            ? AppColors.buttonPrimary
                            : AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              // علامة الاختيار
              if (isSelected)
                const Icon(
                  Icons.check_circle,
                  color: AppColors.buttonPrimary,
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showViewOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                children: [
                  Text(
                    'اختر طريقة العرض',
                    style: AppTextStyles.titleMedium.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: ListView.builder(
                itemCount: viewOptions.length,
                itemBuilder: (context, index) {
                  final option = viewOptions[index];
                  final isSelected = _currentViewType == option.type;

                  return ListTile(
                    leading: Icon(
                      option.icon,
                      color: isSelected ? AppColors.buttonPrimary : null,
                    ),
                    title: Text(option.title),
                    trailing: isSelected
                        ? const Icon(Icons.check,
                            color: AppColors.buttonPrimary)
                        : null,
                    selected: isSelected,
                    onTap: () {
                      setState(() => _currentViewType = option.type);
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildViewToggleButton() {
    final currentOption =
        viewOptions.firstWhere((o) => o.type == _currentViewType);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.buttonPrimary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: IconButton(
        icon: Icon(currentOption.icon, size: 18),
        onPressed: _showViewOptions,
        tooltip: 'تغيير طريقة العرض',
        color: AppColors.buttonPrimary,
        padding: const EdgeInsets.all(8),
        constraints: const BoxConstraints(),
      ),
    );
  }

  void _clearAllFilters() {
    setState(() {
      _searchQuery = '';
      selectedDepartmentId = null;
      selectedStageId = null;
      selectedSemesterId = null;
      _selectedDepartment = null;
      _selectedStage = null;
      _selectedSemester = null;
      _courses = List.from(_originalCourses);
      _applySorting();
    });
  }

  void _onFilterItemSelected(String filterType, String itemId) {
    setState(() {
      switch (filterType) {
        case 'department':
          selectedDepartmentId = itemId == 'all' ? null : itemId;
          _selectedDepartment = itemId == 'all'
              ? null
              : departments.firstWhere((d) => d['id'] == itemId)['name'];
          // إعادة تعيين المرحلة والفصل
          selectedStageId = null;
          selectedSemesterId = null;
          _selectedStage = null;
          _selectedSemester = null;
          break;

        case 'stage':
          selectedStageId = itemId == 'all' ? null : itemId;
          _selectedStage = itemId == 'all'
              ? null
              : stages.firstWhere((s) => s['id'] == itemId)['name'];
          // إعادة تعيين الفصل فقط
          selectedSemesterId = null;
          _selectedSemester = null;

          // تحديث الفصول إذا كان هناك قسم ومرحلة محددين
          if (selectedDepartmentId != null &&
              selectedDepartmentId != 'all' &&
              selectedStageId != null &&
              selectedStageId != 'all') {
            _loadSemesters(selectedDepartmentId!, selectedStageId!);
          }
          break;

        case 'semester':
          selectedSemesterId = itemId == 'all' ? null : itemId;
          _selectedSemester = itemId == 'all'
              ? null
              : semesters.firstWhere((s) => s['id'] == itemId)['name'];
          break;
      }

      // تطبيق التصفية والفرز
      _courses = _filterCourses();
      _applySorting();
    });
  }

  // دالة جديدة للفلاتر فقط (بدون حقل البحث)
  Widget _buildFilters() {
    final activeFiltersCount = _getActiveFiltersCount();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Column(
        children: [
          // عداد الفلاتر النشطة
          if (activeFiltersCount > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.buttonPrimary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'الفلاتر النشطة: $activeFiltersCount',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: _clearAllFilters,
                    child: Text(
                      'مسح الكل',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.buttonPrimary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // الفلاتر
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildQuickFilter(
                  icon: Icons.school,
                  label: _selectedDepartment ?? 'القسم',
                  isSelected: _selectedDepartment != null,
                  onTap: () => _showFilterOptions('department', departments),
                ),
                _buildQuickFilter(
                  icon: Icons.class_,
                  label: _selectedStage ?? 'المرحلة',
                  isSelected: _selectedStage != null,
                  onTap: () => _showFilterOptions('stage', stages),
                ),
                _buildQuickFilter(
                  icon: Icons.bookmark,
                  label: _selectedSemester ?? 'الكورس',
                  isSelected: _selectedSemester != null,
                  onTap: () => _showFilterOptions('semester', semesters),
                ),
                _buildQuickFilter(
                  icon: Icons.sort,
                  label: 'ترتيب: ${_getSortLabel()}',
                  isSelected: _currentSort != 'latest',
                  onTap: _showSortOptions,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Icon(
              icon,
              size: 16,
              color: color,
            ),
          ),
        ),
      ),
    );
  }

  void _manageCourseVideos(Course course) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CourseVideosScreen(course: course),
      ),
    ).then((result) {
      // Actualizar la lista de cursos si se modificaron los videos
      if (result == true) {
        _loadCourses();
      }
    });
  }
}
