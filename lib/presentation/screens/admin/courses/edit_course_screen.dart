import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:mycourses/core/constants/app_colors.dart';
import 'package:mycourses/core/constants/app_text_styles.dart';
import 'package:mycourses/core/services/admin_service.dart';
import 'package:mycourses/core/services/supabase_service.dart';
import 'package:mycourses/core/services/bunny_storage_service.dart'; // Importar BunnyStorageService
import 'package:mycourses/models/course.dart';

class EditCourseScreen extends StatefulWidget {
  final Course course;

  const EditCourseScreen({super.key, required this.course});

  @override
  State<EditCourseScreen> createState() => _EditCourseScreenState();
}

class _EditCourseScreenState extends State<EditCourseScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // متغيرات لحفظ بيانات الكورس
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _priceController;
  late TextEditingController _discountController;

  File? _imageFile;
  String? _imageUrl;
  bool _isPricingActive = true;
  bool isUploading = false;
  double uploadProgress = 0;

  // قوائم البيانات للفلترة
  List<Map<String, dynamic>> departments = [];
  List<Map<String, dynamic>> stages = [];

  // قائمة أقسام الكورس
  List<Map<String, Object?>> _selectedDepartmentDetails = [];

  // ImagePicker instance
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    // تعبئة البيانات من الكورس الممرر
    _titleController = TextEditingController(text: widget.course.title);
    _descriptionController =
        TextEditingController(text: widget.course.description);

    // تعبئة بيانات التسعير إذا كانت موجودة
    if (widget.course.pricing != null) {
      _priceController =
          TextEditingController(text: widget.course.pricing!.price.toString());
      _discountController = TextEditingController(
          text: widget.course.pricing!.discountPrice?.toString() ?? '');
      _isPricingActive = widget.course.pricing!.isActive;
    } else {
      _priceController = TextEditingController(text: '0');
      _discountController = TextEditingController();
      _isPricingActive = true;
    }

    _imageUrl = widget.course.thumbnailUrl;

    // تحويل أقسام الكورس إلى الشكل المطلوب
    _convertDepartmentsToDetailsList();

    // تحميل الأقسام والمراحل
    _loadInitialData();
  }

  void _convertDepartmentsToDetailsList() {
    _selectedDepartmentDetails = widget.course.departmentDetails.map((dept) {
      return <String, Object?>{
        'departmentId': dept.departmentId,
        'departmentName': dept.departmentName,
        'stageId': dept.stageId,
        'stageName': dept.stageName,
        'semesterId': dept.semesterId,
        'semesterName': dept.semesterName,
        'semesters': <Map<String, Object?>>[],
      };
    }).toList();
  }

  Future<void> _loadInitialData() async {
    try {
      setState(() => _isLoading = true);

      // تحميل الأقسام والمراحل من قاعدة البيانات
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

        // تحميل الفصول لكل قسم/مرحلة في القائمة الحالية
        for (var dept in _selectedDepartmentDetails) {
          _loadSemestersForDepartment(dept);
        }

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

  Future<void> _loadSemestersForDepartment(
      Map<String, Object?> deptDetail) async {
    try {
      // Make sure the departmentId and stageId are not null
      final departmentId = deptDetail['departmentId'];
      final stageId = deptDetail['stageId'];

      if (departmentId == null || stageId == null) {
        // Skip loading if either is null
        return;
      }

      final response = await SupabaseService.supabase
          .from('semesters')
          .select()
          .eq('department_id', departmentId.toString())
          .eq('stage_id', stageId.toString());

      setState(() {
        // Convert the response to List<Map<String, Object?>>
        final semestersList = (response as List).map((item) {
          return Map<String, Object?>.from(item as Map);
        }).toList();

        deptDetail['semesters'] = semestersList;
      });
    } catch (e) {
      print('Error loading semesters: $e');
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _discountController.dispose();
    super.dispose();
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
              _imageFile = croppedFile;
            });
          } else {
            // Si el recorte falla, usar la imagen original
            setState(() {
              _imageFile = imageFile;
            });
          }
        } catch (cropError) {
          debugPrint('خطأ في اقتصاص الصورة: $cropError');
          // Si hay un error al recortar, usar la imagen original
          setState(() {
            _imageFile = imageFile;
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

  // إضافة دالة جديدة لاقتصاص الصورة
  Future<File?> _cropImage(File imageFile) async {
    try {
      // Verificar el archivo antes de intentar recortarlo
      if (!await imageFile.exists()) {
        debugPrint('ملف الصورة غير موجود: ${imageFile.path}');
        return null;
      }
      
      // Intentar recortar la imagen con try-catch para evitar bloqueos
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
      return null; // Devolver null en caso de error
    }
  }

  Future<void> _saveCourse() async {
    if (!_formKey.currentState!.validate()) return;

    // التحقق من وجود قسم واحد على الأقل
    if (_selectedDepartmentDetails.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى اختيار قسم واحد على الأقل')),
      );
      return;
    }

    // التحقق من اكتمال اختيار المراحل والفصول لكل الأقسام
    for (final dept in _selectedDepartmentDetails) {
      if (dept['stageId'] == null || dept['semesterId'] == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('يرجى إكمال اختيار المرحلة والفصل لكل الأقسام')),
        );
        return;
      }
    }

    setState(() {
      _isLoading = true;
      isUploading = true;
      uploadProgress = 0.1; // بدء التقدم
    });

    try {
      // تحديث الصورة إذا تم اختيار صورة جديدة
      String? thumbnailUrl = _imageUrl;
      String? oldImageUrl; // حفظ رابط الصورة القديمة للحذف لاحقاً
      
      if (_imageFile != null) {
        // حفظ رابط الصورة القديمة لحذفها بعد النجاح
        oldImageUrl = _imageUrl;
        debugPrint('⚠️ الصورة القديمة التي سيتم حذفها: $oldImageUrl');
        
        // استخدام Bunny.net بدلاً من Supabase لرفع الصورة
        thumbnailUrl =
            await AdminService.uploadCourseImage(_imageFile!, useBunny: true);

        if (thumbnailUrl == null) {
          throw Exception('فشل في رفع الصورة');
        }

        setState(() {
          uploadProgress = 0.4; // بعد رفع الصورة
        });
      }

      // إنشاء نموذج التسعير
      final price = double.tryParse(_priceController.text) ?? 0.0;
      final discountText = _discountController.text.trim();
      final discount =
          discountText.isNotEmpty ? double.tryParse(discountText) : null;

      final coursePricing = price > 0
          ? PricingDetail(
              id: widget.course.pricing?.id,
              courseId: widget.course.id,
              price: price,
              discountPrice: discount,
              isActive: _isPricingActive,
            )
          : null;

      // تحويل قائمة الأقسام المختارة إلى قائمة DepartmentDetail بطريقة آمنة
      final departmentDetails = _selectedDepartmentDetails.map((dept) {
        // استخراج اسم المرحلة بطريقة آمنة
        String stageName = dept['stageName'] as String? ?? '';
        if (stageName.isEmpty && dept['stageId'] != null) {
          final stageId = dept['stageId'].toString();
          final matchingStage = stages.firstWhere(
            (s) => s['id'].toString() == stageId,
            orElse: () => {'name': 'غير معروف'},
          );
          stageName = matchingStage['name'].toString();
        }

        // استخراج اسم الفصل بطريقة آمنة
        String semesterName = dept['semesterName'] as String? ?? '';
        if (semesterName.isEmpty && dept['semesterId'] != null) {
          final semesterId = dept['semesterId'].toString();
          final semesters = dept['semesters'] as List? ?? [];

          String foundName = 'غير معروف';
          for (var semester in semesters) {
            if ((semester as Map)['id'].toString() == semesterId) {
              foundName = semester['name']?.toString() ?? 'غير معروف';
              break;
            }
          }
          semesterName = foundName;
        }

        return DepartmentDetail(
          departmentId: dept['departmentId'].toString(),
          stageId: dept['stageId'].toString(),
          semesterId: dept['semesterId'].toString(),
          departmentName: dept['departmentName'].toString(),
          stageName: stageName,
          semesterName: semesterName,
        );
      }).toList();

      setState(() {
        uploadProgress = 0.6; // عند إنشاء الكورس
      });

      // إنشاء نموذج الكورس المحدث
      final updatedCourse = Course(
        id: widget.course.id,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        thumbnailUrl: thumbnailUrl,
        semesterId:
            departmentDetails.first.semesterId, // نستخدم أول فصل كفصل افتراضي
        totalDuration: widget.course.totalDuration,
        totalVideos: widget.course.totalVideos,
        rating: widget.course.rating,
        ratingsCount: widget.course.ratingsCount,
        createdAt: widget.course.createdAt,
        pricing: coursePricing,
        departmentDetails: departmentDetails,
      );

      setState(() {
        uploadProgress = 0.8; // قبل الحفظ النهائي
      });

      // حفظ التعديلات
      final success = await AdminService.updateCourse(updatedCourse);

      // إذا تم تحديث الكورس بنجاح ويوجد صورة قديمة، قم بحذفها
      if (success && oldImageUrl != null) {
        try {
          // استخراج اسم الملف من الرابط
          final imagePathToDelete = _extractImagePathFromUrl(oldImageUrl);
          debugPrint('🔍 المسار المستخرج للصورة القديمة: $imagePathToDelete');
          
          if (imagePathToDelete != null) {
            // حذف الصورة القديمة
            final deleteResult = await BunnyStorageService.deleteFile(imagePathToDelete);
            debugPrint(deleteResult 
                ? '✅ تم حذف الصورة القديمة بنجاح: $imagePathToDelete' 
                : '❌ فشل في حذف الصورة القديمة: $imagePathToDelete');
          } else {
            debugPrint('⚠️ لم يتم العثور على مسار صالح للحذف من: $oldImageUrl');
          }
        } catch (deleteError) {
          // عدم عرض الخطأ للمستخدم، ولكن تسجيله في السجل فقط
          debugPrint('❌ خطأ في حذف الصورة القديمة: $deleteError');
        }
      }

      setState(() {
        uploadProgress = 1.0; // اكتمال العملية
        _isLoading = false;
        isUploading = false;
      });

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم تحديث الكورس بنجاح'),
              backgroundColor: Colors.green,
            ),
          );
          // إرجاع true للإشارة إلى أن التعديل تم بنجاح
          Navigator.pop(context, true);
        } else {
          throw Exception('فشل في تحديث الكورس');
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        isUploading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل في تعديل الكورس: $e')),
        );
      }
    }
  }

  // دالة مساعدة لاستخراج مسار الصورة من رابط URL
  String? _extractImagePathFromUrl(String? url) {
    if (url == null || url.isEmpty) {
      debugPrint('❌ استخراج المسار: الرابط فارغ أو غير موجود');
      return null;
    }
    
    // طباعة الرابط الأصلي للتشخيص
    debugPrint('🔍 استخراج المسار من الرابط: $url');
    
    try {
      // التعامل مع رابط CDN (b-cdn.net)
      if (url.contains('b-cdn.net')) {
        // البحث عن مسار يحتوي على 'courses_photo/course_'
        final regex = RegExp(r'courses_photo/course_[^/\s]+\.\w+');
        final match = regex.firstMatch(url);
        if (match != null) {
          final extractedPath = match.group(0);
          debugPrint('✅ تم استخراج المسار من رابط CDN: $extractedPath');
          return extractedPath;
        }
        
        // إذا لم ينجح النمط المعتاد، نحاول استخراج المسار من URI
        final uri = Uri.parse(url);
        final path = uri.path;
        if (path.startsWith('/')) {
          final cleanPath = path.substring(1);
          debugPrint('✅ تم استخراج المسار من URI: $cleanPath');
          return cleanPath;
        }
        
        debugPrint('❌ فشل في استخراج المسار من رابط CDN');
      }
      
      // التعامل مع رابط مباشر لمجلد 'courses_photo'
      if (url.contains('courses_photo/')) {
        final regex = RegExp(r'courses_photo/course_[^/\s]+\.\w+');
        final match = regex.firstMatch(url);
        if (match != null) {
          final extractedPath = match.group(0);
          debugPrint('✅ تم استخراج المسار من رابط المجلد: $extractedPath');
          return extractedPath;
        }
        debugPrint('❌ فشل في استخراج المسار من رابط المجلد');
      }
      
      // التعامل مع رابط تخزين Bunny مباشرة
      if (url.contains('storage.bunnycdn.com')) {
        final uri = Uri.parse(url);
        final segments = uri.pathSegments;
        if (segments.length > 1) {
          final path = segments.sublist(1).join('/');
          debugPrint('✅ تم استخراج المسار من رابط التخزين: $path');
          return path;
        }
        debugPrint('❌ فشل في استخراج المسار من رابط التخزين');
      }
      
      // حالة أخيرة: إذا كان الرابط يتضمن 'course_' ومتبوعًا بتاريخ ونوع ملف
      final lastRegex = RegExp(r'course_\d+\.\w+');
      final lastMatch = lastRegex.firstMatch(url);
      if (lastMatch != null) {
        final fileName = lastMatch.group(0);
        debugPrint('✅ تم استخراج اسم الملف: $fileName');
        return 'courses_photo/$fileName';
      }
      
      debugPrint('❌ لم يتم العثور على نمط يتطابق مع الرابط');
      return null;
    } catch (e) {
      debugPrint('❌ خطأ أثناء استخراج المسار: $e');
      return null;
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      setState(() {
        _isLoading = true;
      });

      String thumbnailUrl = widget.course.thumbnailUrl ?? '';

      // Upload new image if selected
      if (_imageFile != null) {
        // استخدام Bunny.net بدلاً من Supabase لرفع الصورة الجديدة
        final uploadedImage =
            await AdminService.uploadCourseImage(_imageFile!, useBunny: true);
        if (uploadedImage != null) {
          thumbnailUrl = uploadedImage;
        } else {
          throw Exception('فشل في رفع الصورة');
        }
      }

      // Update course data
      final updatedCourse = Course(
        id: widget.course.id,
        title: _titleController.text,
        description: _descriptionController.text.isEmpty
            ? null
            : _descriptionController.text,
        thumbnailUrl: thumbnailUrl,
        semesterId: widget.course.semesterId, // استخدام نفس semesterId الموجود
        createdAt: widget.course.createdAt,
        // ...أضف أي حقول أخرى ضرورية موجودة في النموذج
      );

      // Update course in database using existing method
      await AdminService.updateCourse(updatedCourse);

      // Navigate back on success
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تحديث الكورس بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل في تحديث الكورس: $e'),
            backgroundColor: Colors.red,
          ),
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
        title: const Text('تعديل الكورس',
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
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : SingleChildScrollView(
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
    final optimizedImageUrl =
        _imageUrl != null ? AdminService.optimizeImageUrl(_imageUrl) : null;

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
          image: _imageFile != null
              ? DecorationImage(
                  image: FileImage(_imageFile!),
                  fit: BoxFit.cover,
                )
              : optimizedImageUrl != null
                  ? DecorationImage(
                      image: NetworkImage(optimizedImageUrl),
                      fit: BoxFit.cover,
                    )
                  : null,
        ),
        child: _imageFile == null && _imageUrl == null
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _selectedDepartmentDetails.length,
          separatorBuilder: (context, index) => const SizedBox(height: 8),
          itemBuilder: (context, index) => _buildDepartmentCardNew(index),
        ),
      ],
    );
  }

  Widget _buildDepartmentCardNew(int index) {
    final deptDetail = _selectedDepartmentDetails[index];

    // التحقق من وجود القوائم المطلوبة
    List<MapEntry<String, String>> stageItems = stages
        .map((s) => MapEntry(s['id'].toString(), s['name'].toString()))
        .toList();

    List<MapEntry<String, String>> semesterItems = [];
    if (deptDetail.containsKey('semesters') &&
        deptDetail['semesters'] != null &&
        (deptDetail['semesters'] as List).isNotEmpty) {
      semesterItems = (deptDetail['semesters'] as List)
          .map((s) => MapEntry(
              (s['id'] ?? '').toString(), (s['name'] ?? '').toString()))
          .toList();
    }

    // Convertir valores a String para asegurar compatibilidad
    final stageId = deptDetail['stageId']?.toString() ?? '';
    final semesterId = deptDetail['semesterId']?.toString() ?? '';

    // Comprobar si los valores existen en las listas
    final bool stageExists = stageItems.any((item) => item.key == stageId);
    final bool semesterExists =
        semesterItems.any((item) => item.key == semesterId);

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
                    value: stageExists ? stageId : null,
                    items: stageItems,
                    hint: 'المرحلة الدراسية',
                    onChanged: (value) => _updateStage(index, value),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildDropdownNew(
                    value: semesterExists ? semesterId : null,
                    items: semesterItems,
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
    // Validar si el valor existe en la lista de items
    final bool valueExists = items.any((item) => item.key == value);
    final finalValue = valueExists ? value : null;

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
          value: finalValue, // Usar el valor validado
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
        const SizedBox(height: 12),
        // إضافة خيار تفعيل/تعطيل السعر
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.65),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: AppColors.buttonPrimary.withOpacity(0.1),
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              const Text(
                'تفعيل السعر',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontFamily: 'Cairo',
                ),
              ),
              const Spacer(),
              Switch(
                value: _isPricingActive,
                onChanged: (value) {
                  setState(() {
                    _isPricingActive = value;
                  });
                },
                activeColor: AppColors.buttonPrimary,
              ),
            ],
          ),
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

  // تعديل زر الحفظ ليكون أكثر وضوحاً وجاذبية
  Widget _buildSubmitButtonNew() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _saveCourse,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.buttonPrimary,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          // إضافة ظلال للزر
          elevation: 3,
          shadowColor: AppColors.buttonPrimary.withOpacity(0.5),
        ),
        child: Text(
          _isLoading ? 'جاري الحفظ...' : 'حفظ التعديلات',
          style: const TextStyle(
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
      style: const TextStyle(
        color: AppColors.buttonPrimary,
        fontSize: 15,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  // تعديل دالة بناء مؤشر التحميل لتغيير اللون
  Widget _buildUploadProgressNew() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      // إضافة خلفية داكنة لجعل النص والمؤشر أكثر وضوحاً
      decoration: BoxDecoration(
        color: AppColors.buttonPrimary.withOpacity(0.8),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // تغيير لون النص إلى أبيض واضح
          Text(
            'جاري حفظ التعديلات... ${(uploadProgress * 100).toInt()}%',
            style: const TextStyle(
              color: Colors.white, 
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          // تغيير ألوان مؤشر التحميل
          LinearProgressIndicator(
            value: uploadProgress,
            backgroundColor: Colors.white.withOpacity(0.3),
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.amber),
          ),
        ],
      ),
    );
  }

  void _showDepartmentSelectionDialog() {
    // إنشاء قائمة بالأقسام غير المدرجة بالفعل
    final existingDeptIds =
        _selectedDepartmentDetails.map((e) => e['departmentId']).toList();
    final availableDepartments = departments
        .where((dept) => !existingDeptIds.contains(dept['id']))
        .toList();

    // طباعة للتصحيح
    debugPrint('الأقسام المتاحة: ${availableDepartments.length}');
    debugPrint('الأقسام الموجودة: ${existingDeptIds.length}');

    if (availableDepartments.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إضافة جميع الأقسام بالفعل')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('اختر القسم'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: availableDepartments.map((dept) {
              return ListTile(
                title: Text(dept['name']),
                onTap: () {
                  _addDepartment(dept);
                  Navigator.pop(context);
                },
              );
            }).toList(),
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
    // طباعة للتصحيح
    debugPrint('إضافة قسم: ${dept['name']}');

    // Convertir explícitamente a Map<String, Object?>
    final Map<String, Object?> newDept = {
      'departmentId': dept['id'] as String,
      'departmentName': dept['name'] as String,
      'stageId': null,
      'stageName': null,
      'semesterId': null,
      'semesterName': null,
      'semesters': <Map<String, Object?>>[],
    };

    setState(() {
      _selectedDepartmentDetails.add(newDept);
    });
  }

  void _removeDepartment(int index) {
    setState(() {
      _selectedDepartmentDetails.removeAt(index);
    });
  }

  void _updateStage(int index, String? stageId) async {
    if (stageId == null) return;

    try {
      // Find stage name
      String stageName = '';
      for (var stage in stages) {
        if (stage['id'].toString() == stageId) {
          stageName = stage['name'].toString();
          break;
        }
      }

      // Get the departmentId safely
      final departmentId = _selectedDepartmentDetails[index]['departmentId'];
      if (departmentId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('معرف القسم غير متوفر')),
        );
        return;
      }

      final response = await SupabaseService.supabase
          .from('semesters')
          .select()
          .eq('department_id', departmentId.toString())
          .eq('stage_id', stageId);

      setState(() {
        // Update stage values and reset semester
        _selectedDepartmentDetails[index] = {
          ..._selectedDepartmentDetails[index],
          'stageId': stageId,
          'stageName': stageName,
          'semesterId': null,
          'semesterName': null,
          'semesters': (response as List).map((item) {
            return Map<String, Object?>.from(item as Map);
          }).toList(),
        };
      });
    } catch (e) {
      print('Error loading semesters: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحميل الفصول: $e')),
        );
      }
    }
  }

  void _updateSemester(int index, String? semesterId) {
    if (semesterId == null) return;

    // Find semester name in the semesters list
    final semesters = _selectedDepartmentDetails[index]['semesters'];
    if (semesters == null) {
      return;
    }

    // Safe type conversion
    String semesterName = 'غير معروف';
    for (var semester in semesters as List) {
      if (semester is Map) {
        final id = semester['id'];
        if (id != null && id.toString() == semesterId) {
          final name = semester['name'];
          semesterName = name?.toString() ?? 'غير معروف';
          break;
        }
      }
    }

    setState(() {
      // Update only semester values
      _selectedDepartmentDetails[index] = {
        ..._selectedDepartmentDetails[index],
        'semesterId': semesterId,
        'semesterName': semesterName,
      };
    });
  }
}