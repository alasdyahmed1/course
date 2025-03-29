import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart'; // إضافة استيراد حزمة اقتصاص الصور
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/services/admin_service.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../models/course.dart';

class AddCourseScreen extends StatefulWidget {
  const AddCourseScreen({super.key});

  @override
  State<AddCourseScreen> createState() => _AddCourseScreenState();
}

class _AddCourseScreenState extends State<AddCourseScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _discountController = TextEditingController(); // إضافة controller جديد للخصم

  // Selected values
  String? selectedDepartmentId; // تعديل
  String? selectedStageId; // تعديل
  String? selectedSemesterId; // تعديل
  bool isLoading = false;
  String? thumbnailUrl;

  // Lists for dropdowns
  List<Map<String, dynamic>> departments = [];
  List<Map<String, dynamic>> stages = [];
  List<Map<String, dynamic>> semesters = [];

  // ImagePicker instance
  final ImagePicker _imagePicker = ImagePicker();

  // إضافة متغيرات جديدة
  final List<String> selectedDepartments = [];
  File? thumbnailImage;
  double uploadProgress = 0;
  bool isUploading = false;

  // نضيف متغيرات جديدة لتتبع الاختيارات المتعددة
  final List<Map<String, dynamic>> selectedDepartmentDetails = [];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      setState(() => isLoading = true);

      // تحميل الأقسام والمراحل والفصول من قاعدة البيانات
      final departmentsResponse = await AdminService.getDepartments();
      final stagesResponse = await AdminService.getStages();

      setState(() {
        departments = departmentsResponse
            .map((d) => {
                  'id': d.id,
                  'name': d.name,
                  'code': d.code,
                })
            .toList();

        stages = stagesResponse
            .map((s) => {
                  'id': s.id,
                  'name': s.name,
                  'level': s.level,
                })
            .toList();

        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحميل البيانات: $e')),
        );
      }
    }
  }

  // تحميل الفصول عند اختيار القسم والمرحلة
  Future<void> _loadSemesters(String departmentId, String stageId) async {
    try {
      final response = await SupabaseService.supabase
          .from('semesters')
          .select()
          .eq('department_id', departmentId)
          .eq('stage_id', stageId);

      setState(() {
        semesters = (response as List)
            .map((s) => {
                  'id': s['id'],
                  'name': s['name'],
                  'semester_number': s['semester_number'],
                })
            .toList();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحميل الفصول: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('إضافة كورس',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.white,
              fontFamily: 'Cairo',
            )),
        centerTitle: true,
        backgroundColor: AppColors.buttonPrimary,
        elevation: 0,
      ),
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
              if (isUploading) _buildUploadProgressNew(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        const SizedBox(height: 16),
                        _buildImagePickerNew(),
                        const SizedBox(height: 24),
                        _buildBasicInfoNew(),
                        const SizedBox(height: 20),
                        _buildDepartmentsSectionNew(),
                        const SizedBox(height: 20),
                        _buildPricingNew(),
                        const SizedBox(height: 32),
                        _buildSubmitButtonNew(),
                        const SizedBox(height: 24),
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

  Widget _buildImagePickerNew() {
    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        height: 180,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withOpacity(0.3),
            width: 1,
          ),
          image: thumbnailImage != null
              ? DecorationImage(
                  image: FileImage(thumbnailImage!),
                  fit: BoxFit.cover,
                )
              : null,
        ),
        child: thumbnailImage == null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_photo_alternate_outlined,
                    size: 40,
                    color: Colors.white.withOpacity(0.8),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'إضافة صورة الكورس',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 14,
                    ),
                  ),
                ],
              )
            : null,
      ),
    );
  }

  Widget _buildBasicInfoNew() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitleNew('معلومات الكورس'),
        const SizedBox(height: 12),
        _buildTextFieldNew(
          controller: _titleController,
          label: 'عنوان الكورس',
          hint: 'مثال: مقدمة في البرمجة',
          validator: (value) {
            if (value?.isEmpty ?? true) {
              return 'يرجى إدخال عنوان الكورس';
            }
            return null;
          },
        ),
        const SizedBox(height: 12),
        _buildTextFieldNew(
          controller: _descriptionController,
          label: 'وصف الكورس',
          hint: 'اكتب وصفاً مختصراً للكورس',
          maxLines: 3,
        ),
      ],
    );
  }

  Widget _buildTextFieldNew({
    required TextEditingController controller,
    required String label,
    required String hint,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    String? prefix,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
            fontFamily: 'Cairo',
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 13,
            fontFamily: 'Cairo',
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              fontSize: 13,
              color: AppColors.hintColor.withOpacity(0.5),
              fontFamily: 'Cairo',
            ),
            prefix: prefix != null
                ? Text(prefix,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textPrimary,
                      fontFamily: 'Cairo',
                    ))
                : null,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            filled: true,
            fillColor: Colors.white.withOpacity(0.65),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(13),
              borderSide: BorderSide(
                color: AppColors.buttonPrimary.withOpacity(0.1),
                width: 1.5,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(13),
              borderSide: BorderSide(
                color: AppColors.buttonPrimary.withOpacity(0.1),
                width: 1.5,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(13),
              borderSide: const BorderSide(
                color: AppColors.buttonPrimary,
                width: 1.5,
              ),
            ),
          ),
          maxLines: maxLines,
          keyboardType: keyboardType,
          validator: validator,
        ),
      ],
    );
  }

  Widget _buildDepartmentsSectionNew() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSectionTitleNew('الأقسام والمراحل'),
            TextButton.icon(
              onPressed: _showDepartmentSelectionDialog,
              icon: Icon(Icons.add_circle_outline,
                  size: 18, color: AppColors.buttonPrimary),
              label: Text(
                'إضافة',
                style: TextStyle(
                  color: AppColors.buttonPrimary,
                  fontSize: 13,
                ),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: selectedDepartmentDetails.length,
          separatorBuilder: (context, index) => const SizedBox(height: 8),
          itemBuilder: (context, index) => _buildDepartmentCardNew(index),
        ),
      ],
    );
  }

  Widget _buildDepartmentCardNew(int index) {
    final deptDetail = selectedDepartmentDetails[index];
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.buttonPrimary.withOpacity(0.9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'القسم: ${deptDetail['departmentName']}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.delete,
                      size: 20, color: Colors.white.withOpacity(0.7)),
                  onPressed: () => _removeDepartment(index),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildDropdownNew(
                    value: deptDetail['stageId'],
                    items: stages
                        .map((s) =>
                            MapEntry(s['id'].toString(), s['name'].toString()))
                        .toList(),
                    hint: 'المرحلة الدراسية',
                    onChanged: (value) => _updateStage(index, value),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildDropdownNew(
                    value: deptDetail['semesterId'],
                    items: deptDetail['semesters'] != null
                            ? (deptDetail['semesters'] as List)
                                .map<MapEntry<String, String>>((s) => MapEntry(
                                    s['id'].toString(), s['name'].toString()))
                                .toList()
                            : [],
                    hint: 'الفصل الدراسي',
                    onChanged: (value) => _updateSemester(index, value),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdownNew({
    required String? value,
    required List<MapEntry<String, String>> items,
    required String hint,
    required void Function(String?) onChanged,
  }) {
    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: AppColors.buttonPrimary.withOpacity(0.1),
          width: 1.5,
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          textTheme: Theme.of(context).textTheme.apply(fontFamily: 'Cairo'),
        ),
        child: DropdownButtonFormField<String>(
          value: value,
          items: items.map((item) {
            return DropdownMenuItem(
              value: item.key,
              child: Text(
                item.value,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textPrimary,
                  fontFamily: 'Cairo',
                ),
              ),
            );
          }).toList(),
          onChanged: onChanged,
          dropdownColor: Colors.white,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textPrimary,
            fontFamily: 'Cairo',
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              fontSize: 12,
              color: AppColors.textPrimary,
              fontFamily: 'Cairo',
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 6),
            border: InputBorder.none,
          ),
        ),
      ),
    );
  }

  Widget _buildPricingNew() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitleNew('السعر والتكلفة'),
        _buildTextFieldNew(
          controller: _priceController,
          label: 'سعر الكورس',
          hint: 'مثال: 10',
          keyboardType: TextInputType.number,
          prefix: 'د.ع',
          validator: (value) {
            if (value?.isEmpty ?? true) return 'يرجى إدخال السعر';
            final price = double.tryParse(value!);
            if (price == null || price < 0) return 'يرجى إدخال سعر صحيح';
            return null;
          },
        ),
        const SizedBox(height: 12),
        // إضافة حقل الخصم
        _buildTextFieldNew(
          controller: _discountController,
          label: 'سعر الخصم (اختياري)',
          hint: 'مثال: 8',
          keyboardType: TextInputType.number,
          prefix: 'د.ع',
          validator: (value) {
            if (value?.isEmpty ?? true) return null;
            final discount = double.tryParse(value!);
            if (discount == null || discount < 0) return 'يرجى إدخال سعر صحيح';
            final price = double.tryParse(_priceController.text) ?? 0;
            if (discount >= price) {
              return 'يجب أن يكون الخصم أقل من السعر الأصلي';
            }
            return null;
          },
        ),
        const SizedBox(height: 8),
        Text(
          '* السعر بالدينار العراقي',
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButtonNew() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _submitForm,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.buttonPrimary,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: const Text(
          'إضافة الكورس',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.white,
            fontFamily: 'Cairo',
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitleNew(String title) {
    return Text(
      title,
      style: TextStyle(
        color: AppColors.buttonPrimary,
        fontSize: 15,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildUploadProgressNew() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'جاري رفع الكورس... ${(uploadProgress * 100).toInt()}%',
            style: const TextStyle(color: Colors.white),
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: uploadProgress,
            backgroundColor: Colors.white.withOpacity(0.2),
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ],
      ),
    );
  }

  // إضافة دالة لاقتصاص الصورة
  Future<File?> _cropImage(File imageFile) async {
    try {
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: imageFile.path,
        aspectRatio: const CropAspectRatio(ratioX: 16, ratioY: 9), // نسبة 16:9 مناسبة للكورسات
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'اقتصاص صورة الكورس',
            toolbarColor: AppColors.buttonPrimary,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.ratio16x9,
            lockAspectRatio: true,
            activeControlsWidgetColor: AppColors.buttonPrimary,
          ),
          IOSUiSettings(
            title: 'اقتصاص صورة الكورس',
            aspectRatioLockEnabled: true,
            resetAspectRatioEnabled: false,
          ),
        ],
      );
      
      if (croppedFile != null) {
        return File(croppedFile.path);
      }
      return null;
    } catch (e) {
      debugPrint('خطأ في اقتصاص الصورة: $e');
      return null;
    }
  }

  Future<void> _pickImage() async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );
      
      if (pickedFile != null) {
        // Primero, verificar si la imagen existe
        final imageFile = File(pickedFile.path);
        if (!await imageFile.exists()) {
          throw Exception('الصورة المختارة غير موجودة');
        }
        
        // En algunos casos, puede ser mejor saltar el proceso de recorte si hay problemas
        try {
          final croppedFile = await _cropImage(imageFile);
          if (croppedFile != null) {
            setState(() {
              thumbnailImage = croppedFile;
            });
          } else {
            // Si el recorte falla, usar la imagen original
            setState(() {
              thumbnailImage = imageFile;
            });
          }
        } catch (cropError) {
          debugPrint('خطأ في اقتصاص الصورة: $cropError');
          // Si hay un error al recortar, usar la imagen original
          setState(() {
            thumbnailImage = imageFile;
          });
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('تعذر اقتصاص الصورة، تم استخدام الصورة الأصلية')),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('خطأ في اختيار الصورة: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل في اختيار الصورة: $e')),
        );
      }
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    // التحقق من وجود صورة
    if (thumbnailImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إضافة صورة للكورس')),
      );
      return;
    }

    // التحقق من اختيار قسم واحد على الأقل
    if (selectedDepartmentDetails.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى اختيار قسم واحد على الأقل')),
      );
      return;
    }

    // التحقق من اكتمال اختيار المراحل والفصول لكل الأقسام
    for (final dept in selectedDepartmentDetails) {
      if (dept['stageId'] == null || dept['semesterId'] == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('يرجى إكمال اختيار المرحلة والفصل لكل الأقسام')),
        );
        return;
      }
    }

    try {
      setState(() {
        isLoading = false;
        isUploading = true;
        uploadProgress = 0.1; // بدء التقدم
      });

      // 1. رفع الصورة إلى Bunny.net بدلاً من Supabase
      final String? uploadedImageUrl =
          await AdminService.uploadCourseImage(thumbnailImage!, useBunny: true);
      if (uploadedImageUrl == null) throw Exception('فشل في رفع الصورة');

      setState(() {
        uploadProgress = 0.4; // بعد رفع الصورة
      });

      // 2. إنشاء الكورس
      final courseData = Course(
        id: '',
        title: _titleController.text,
        description: _descriptionController.text,
        thumbnailUrl: uploadedImageUrl,
        semesterId: selectedDepartmentDetails[0]['semesterId'],
        createdAt: DateTime.now(),
      );

      setState(() {
        uploadProgress = 0.6; // عند إنشاء الكورس
      });

      // 3. إضافة الكورس وانتظار الاستجابة
      final courseResponse =
          await AdminService.addCourse(courseData, uploadedImageUrl);
      final String courseId = courseResponse['id'];

      setState(() {
        uploadProgress = 0.8; // عند إضافة الكورس
      });

      // 4. إضافة العلاقات مع الأقسام والمراحل والفصول
      for (final dept in selectedDepartmentDetails) {
        await SupabaseService.supabase
            .from('course_department_semesters')
            .insert({
          'course_id': courseId,
          'department_id': dept['departmentId'],
          'stage_id': dept['stageId'],
          'semester_id': dept['semesterId'],
        });
      }

      // 5. إضافة السعر والخصم
      if (_priceController.text.isNotEmpty) {
        final price = double.parse(_priceController.text);
        final discount = _discountController.text.isNotEmpty
            ? double.parse(_discountController.text)
            : null;

        await SupabaseService.supabase.from('course_pricing').insert({
          'course_id': courseId,
          'price': price,
          'discount_price': discount,
          'is_active': true,
        });
      }

      setState(() {
        uploadProgress = 1.0; // اكتمال العملية
        isLoading = false;
        isUploading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إضافة الكورس بنجاح'),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
          isUploading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showDepartmentSelectionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('اختر القسم'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: departments
                .where((dept) => !selectedDepartments.contains(dept['id']))
                .map((dept) => ListTile(
                      title: Text(dept['name']),
                      onTap: () {
                        Navigator.pop(context);
                        _addDepartment(dept);
                      },
                    ))
                .toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
        ],
      ),
    );
  }

  void _addDepartment(Map<String, dynamic> dept) {
    setState(() {
      selectedDepartments.add(dept['id']);
      selectedDepartmentDetails.add({
        'departmentId': dept['id'],
        'departmentName': dept['name'],
        'stageId': null,
        'stageName': null,
        'semesterId': null,
        'semesterName': null,
        'semesters': [],
      });
    });
  }

  void _removeDepartment(int index) {
    setState(() {
      selectedDepartments.removeAt(index);
      selectedDepartmentDetails.removeAt(index);
    });
  }

  void _updateStage(int index, String? stageId) async {
    if (stageId == null) return;

    try {
      final response = await SupabaseService.supabase
          .from('semesters')
          .select()
          .eq('department_id', selectedDepartmentDetails[index]['departmentId'])
          .eq('stage_id', stageId);

      setState(() {
        selectedDepartmentDetails[index]['stageId'] = stageId;
        selectedDepartmentDetails[index]['semesterId'] = null;
        selectedDepartmentDetails[index]['semesters'] = response as List;
      });
    } catch (e) {
      // Handle error
    }
  }

  void _updateSemester(int index, String? semesterId) {
    setState(() {
      selectedDepartmentDetails[index]['semesterId'] = semesterId;
    });
  }

  @override
  void dispose() {
    _discountController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    super.dispose();
  }
}