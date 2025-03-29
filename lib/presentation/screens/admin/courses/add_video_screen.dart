import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mycourses/core/config/bunny_config.dart';
import 'package:mycourses/core/constants/app_colors.dart';
import 'package:mycourses/core/constants/app_text_styles.dart';
import 'package:mycourses/core/services/course_videos_service.dart';
import 'package:mycourses/models/course.dart';
import 'package:mycourses/models/course_section.dart';
import 'package:mycourses/models/course_video.dart';
import 'package:path/path.dart' as path;
import 'package:url_launcher/url_launcher.dart';

class AddVideoScreen extends StatefulWidget {
  final Course course;
  final CourseVideo? videoToEdit;

  const AddVideoScreen({
    super.key,
    required this.course,
    this.videoToEdit,
  });

  @override
  State<AddVideoScreen> createState() => _AddVideoScreenState();
}

class _AddVideoScreenState extends State<AddVideoScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _bunnyVideoIdController;

  bool _isLoading = false;
  bool _isSectionsLoading = true;
  String? _errorMessage;
  bool _isUploading = false;
  double _uploadProgress = 0.0;

  File? _videoFile;
  List<AttachmentFile> _attachments = [];
  bool _autoUpdateTitle = true;

  // Add variables for sections
  List<CourseSection> _sections = [];
  String? _selectedSectionId; // Track just the ID instead of the object
  bool _isCreatingNewSection = false;
  final TextEditingController _newSectionTitleController =
      TextEditingController();
  final TextEditingController _newSectionDescriptionController =
      TextEditingController();

  @override
  void initState() {
    super.initState();

    final videoToEdit = widget.videoToEdit;

    _titleController = TextEditingController(
      text: videoToEdit?.title ?? '',
    );

    _descriptionController = TextEditingController(
      text: videoToEdit?.description ?? '',
    );

    _bunnyVideoIdController = TextEditingController(
      text: videoToEdit?.videoId ?? '',
    );

    _autoUpdateTitle = videoToEdit == null || _titleController.text.isEmpty;

    if (videoToEdit != null && videoToEdit.attachments != null) {
      _attachments = videoToEdit.attachments!
          .map((file) => AttachmentFile.fromExisting(
                existingFile: file,
                originalFileName: file.title,
                displayName: file.title,
              ))
          .toList();
    }

    // Load course sections
    _loadCourseSections();
  }

  // Load course sections from the API
  Future<void> _loadCourseSections() async {
    setState(() {
      _isSectionsLoading = true;
    });

    try {
      final sections =
          await CourseVideosService.getCourseSections(widget.course.id);

      setState(() {
        _sections = sections;
        _selectedSectionId = null; // Start with no section selected

        // If editing a video with a section_id, set the selected ID
        if (widget.videoToEdit != null &&
            widget.videoToEdit!.sectionId != null &&
            widget.videoToEdit!.sectionId!.isNotEmpty) {
          _selectedSectionId = widget.videoToEdit!.sectionId;
        }

        _isSectionsLoading = false;
      });
    } catch (e) {
      setState(() {
        _isSectionsLoading = false;
        _errorMessage = 'فشل في تحميل أقسام الكورس: $e';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل في تحميل أقسام الكورس: $e')),
      );
    }
  }

  // Create a new section
  Future<void> _createNewSection() async {
    if (_newSectionTitleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إدخال عنوان القسم')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final newSection = await CourseVideosService.createCourseSection(
        widget.course.id,
        _newSectionTitleController.text.trim(),
        _newSectionDescriptionController.text.trim().isEmpty
            ? null
            : _newSectionDescriptionController.text.trim(),
      );

      setState(() {
        _sections.add(newSection);
        _selectedSectionId = newSection.id; // Set the ID, not the object
        _isCreatingNewSection = false;
        _newSectionTitleController.clear();
        _newSectionDescriptionController.clear();
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إنشاء القسم بنجاح'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل في إنشاء القسم: $e')),
      );
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _bunnyVideoIdController.dispose();
    _newSectionTitleController.dispose();
    _newSectionDescriptionController.dispose();
    for (var attachment in _attachments) {
      attachment.nameController.dispose();
    }
    super.dispose();
  }

  // تحديث دالة اختيار الفيديو للرفع مباشرة إلى Bunny.net
  Future<void> _pickAndUploadVideo() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _videoFile = File(result.files.single.path!);
        });

        // عرض مربع حوار لتأكيد الرفع
        final shouldUpload = await _showUploadConfirmationDialog();
        if (shouldUpload) {
          await _uploadVideoToBunny();
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل في اختيار الفيديو: $e')),
      );
    }
  }

  Future<bool> _showUploadConfirmationDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('رفع الفيديو'),
        content: const Text(
          'هل ترغب في رفع الفيديو إلى منصة Bunny.net؟ سيستغرق هذا بعض الوقت حسب حجم الفيديو.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.buttonPrimary,
            ),
            child: const Text('رفع'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  Future<void> _uploadVideoToBunny() async {
    if (_videoFile == null) return;

    try {
      setState(() {
        _isUploading = true;
        _uploadProgress = 0.0;
      });

      // تحديث شريط التقدم كل 100 مللي ثانية
      final progressTimer =
          Stream.periodic(const Duration(milliseconds: 100), (i) {
        if (_uploadProgress < 0.95) {
          setState(() {
            _uploadProgress += 0.005; // زيادة بطيئة للتقدم
            if (_uploadProgress > 0.95) _uploadProgress = 0.95;
          });
        }
        return i;
      }).listen((_) {});

      // استخدام اسم الملف كعنوان افتراضي للرفع
      final fileName = path.basenameWithoutExtension(_videoFile!.path);

      // رفع الفيديو إلى Bunny.net
      final videoId = await CourseVideosService.uploadVideoToBunny(
        _videoFile!,
        fileName, // استخدام اسم الملف كعنوان مؤقت
      );

      // إيقاف المؤقت
      await progressTimer.cancel();

      setState(() {
        _uploadProgress = 1.0;
        _bunnyVideoIdController.text = videoId;
      });

      // الحصول على معلومات الفيديو بعد الرفع
      try {
        final videoDetails = await CourseVideosService.getVideoDetails(videoId);

        // تحديث العنوان تلقائيًا إذا كان فارغًا أو كنا نريد تحديثه تلقائيًا
        if (_autoUpdateTitle && videoDetails['title'] != null) {
          setState(() {
            _titleController.text = videoDetails['title'];
          });
        }
      } catch (e) {
        debugPrint('خطأ في الحصول على تفاصيل الفيديو: $e');
      }

      setState(() {
        _isUploading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم رفع الفيديو بنجاح إلى Bunny.net'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() {
        _isUploading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل في رفع الفيديو: $e')),
      );
    }
  }

  void _enterBunnyVideoId() {
    final textController =
        TextEditingController(text: _bunnyVideoIdController.text);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إدخال معرف الفيديو من Bunny.net'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'أدخل معرف الفيديو الذي حصلت عليه من منصة Bunny.net:',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: textController,
              decoration: const InputDecoration(
                labelText: 'معرف الفيديو',
                hintText: 'مثال: 989b0866-b522-4c56-b7c3-487d858943ed',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            // Add quick sample buttons for testing
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton(
                  onPressed: () {
                    textController.text =
                        '989b0866-b522-4c56-b7c3-487d858943ed';
                  },
                  child: const Text('نموذج اختبار'),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () async {
              if (textController.text.trim().isNotEmpty) {
                final videoId = textController.text.trim();
                setState(() {
                  _bunnyVideoIdController.text = videoId;
                  _isLoading = true;
                });

                // محاولة الحصول على معلومات الفيديو بعد إدخال المعرف
                try {
                  final videoDetails =
                      await CourseVideosService.getVideoDetails(videoId);

                  if (_autoUpdateTitle && videoDetails['title'] != null) {
                    setState(() {
                      _titleController.text = videoDetails['title'];
                    });
                  }
                } catch (e) {
                  debugPrint('خطأ في الحصول على تفاصيل الفيديو: $e');
                } finally {
                  setState(() {
                    _isLoading = false;
                  });
                }
              }
              Navigator.of(context).pop();
            },
            style: TextButton.styleFrom(
              foregroundColor: AppColors.buttonPrimary,
            ),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAttachment() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.any,
      );

      if (result != null && result.files.isNotEmpty) {
        for (var file in result.files) {
          if (file.path != null) {
            // استخراج اسم الملف الأصلي وإنشاء نموذج الملف المرفق
            final originalFileName = file.name;
            final fileObj = File(file.path!);

            setState(() {
              _attachments.add(AttachmentFile(
                file: fileObj,
                originalFileName: originalFileName,
                displayName:
                    originalFileName, // الاسم الأصلي كاسم معروض افتراضي
              ));
            });
          }
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل في اختيار الملف: $e')),
      );
    }
  }

  // تعديل دالة حذف الملف المرفق لدعم الملفات الموجودة
  void _removeAttachment(int index) async {
    final attachment = _attachments[index];

    // في حالة الملفات الموجودة سابقاً، نحتاج إلى تأكيد وحذف من الخادم
    if (attachment.isExistingFile && attachment.existingFile != null) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('تأكيد الحذف'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('هل أنت متأكد من حذف الملف "${attachment.title}"؟'),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        color: Colors.red.shade700, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'سيتم حذف الملف نهائياً من الخادم ولا يمكن استعادته!',
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('إلغاء'),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('حذف نهائياً'),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        setState(() => _isLoading = true);

        try {
          // حذف الملف من الخادم وقاعدة البيانات
          await CourseVideosService.deleteCourseFile(
              attachment.existingFile!.id);

          // إظهار رسالة نجاح
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('تم حذف الملف بنجاح'),
                backgroundColor: Colors.green,
              ),
            );
          }

          // حذف الملف من القائمة المحلية
          setState(() {
            attachment.nameController.dispose();
            _attachments.removeAt(index);
            _isLoading = false;
          });
        } catch (e) {
          debugPrint('خطأ في حذف الملف: $e');

          // إظهار رسالة خطأ
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('فشل في حذف الملف: $e'),
                backgroundColor: Colors.red,
              ),
            );
            setState(() => _isLoading = false);
          }
        }
      }
    } else {
      // للملفات الجديدة، فقط نقوم بإزالتها من القائمة
      setState(() {
        attachment.nameController.dispose();
        _attachments.removeAt(index);
      });
    }
  }

  Future<void> _saveVideo() async {
    if (!_formKey.currentState!.validate()) return;

    // التحقق من وجود معرف Bunny.net
    if (_bunnyVideoIdController.text.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('يرجى إدخال معرف الفيديو من Bunny.net')),
        );
      }
      return;
    }

    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final isEditing = widget.videoToEdit != null;
      final videoId = _bunnyVideoIdController.text.trim();

      // الحصول على تفاصيل الفيديو من Bunny.net لتحديث المدة
      int videoDuration = 0;
      String videoTitle = _titleController.text;

      try {
        final videoDetails = await CourseVideosService.getVideoDetails(videoId);
        videoDuration = videoDetails['length'] ?? 0;

        // تحديث العنوان تلقائيًا إذا كان فارغًا
        if (_titleController.text.isEmpty && videoDetails['title'] != null) {
          videoTitle = videoDetails['title'];
        }
      } catch (e) {
        debugPrint('خطأ في الحصول على تفاصيل الفيديو: $e');
        // إذا فشل الحصول على المدة، استخدم القيمة الموجودة أو صفر
        videoDuration = widget.videoToEdit?.duration ?? 0;
      }

      // Important: Check if mounted before proceeding
      if (!mounted) return;

      if (isEditing) {
        // تحديث فيديو موجود
        final updatedVideo = CourseVideo(
          id: widget.videoToEdit!.id,
          courseId: widget.course.id,
          title: videoTitle,
          description: _descriptionController.text,
          videoId: videoId,
          duration: videoDuration,
          orderNumber: widget.videoToEdit!.orderNumber,
          createdAt: widget.videoToEdit!.createdAt,
          sectionId: _selectedSectionId?.isEmpty == true
              ? null
              : _selectedSectionId, // Ensure empty strings are converted to null
        );

        await CourseVideosService.updateCourseVideo(
          widget.videoToEdit!.id,
          updatedVideo,
        );

        // معالجة المرفقات
        await _processAttachments(widget.videoToEdit!.id);
      } else {
        // إنشاء فيديو جديد
        final newVideo = CourseVideo(
          id: '', // سيتم إنشاؤه تلقائيًا
          courseId: widget.course.id,
          title: videoTitle,
          description: _descriptionController.text,
          videoId: videoId,
          duration: videoDuration,
          orderNumber: 0, // سيتم تحديده تلقائيًا
          createdAt: DateTime.now(),
          sectionId: _selectedSectionId?.isEmpty == true
              ? null
              : _selectedSectionId, // Ensure empty strings are converted to null
        );

        // Add debug output before and after API call
        debugPrint(
            'About to add video: sectionId: ${_selectedSectionId ?? "null"}');

        final createdVideo = await CourseVideosService.addCourseVideo(newVideo);
        debugPrint('Video added successfully with ID: ${createdVideo.id}');

        // Check if mounted again after the API call
        if (!mounted) return;

        // معالجة المرفقات
        await _processAttachments(createdVideo.id);
      }

      // Final check if mounted before showing success message and navigating
      if (mounted) {
        // Show success message first
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حفظ الفيديو بنجاح'),
            backgroundColor: Colors.green,
          ),
        );

        // Small delay to ensure the SnackBar is visible before navigation
        await Future.delayed(const Duration(milliseconds: 500));

        if (mounted) {
          Navigator.of(context).pop(true); // العودة مع إشارة التحديث
        }
      }
    } catch (e) {
      debugPrint('Error saving video: $e');
      // Check if still mounted before showing error
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل في حفظ الفيديو: $e')),
        );
      }
    }
  }

  // تحديث دالة معالجة المرفقات لتتبع الملفات المحذوفة
  Future<void> _processAttachments(String videoId) async {
    // رفع جميع المرفقات الجديدة فقط (الملفات الموجودة قد تم التعامل معها بالفعل)
    for (var attachment in _attachments) {
      if (!attachment.isExistingFile && attachment.file != null) {
        setState(() {
          _isUploading = true;
          _uploadProgress = 0.0;
        });

        // محاكاة تقدم الرفع
        final progressTimer =
            Stream.periodic(const Duration(milliseconds: 100), (i) {
          if (_uploadProgress < 0.95) {
            setState(() {
              _uploadProgress += 0.02;
              if (_uploadProgress > 0.95) _uploadProgress = 0.95;
            });
          }
          return i;
        }).listen((_) {});

        try {
          // رفع الملف
          final fileId = await CourseVideosService.uploadFileToBunny(
            attachment.file!,
            attachment.title,
          );

          await progressTimer.cancel();
          setState(() => _uploadProgress = 1.0);

          // إنشاء سجل الملف
          final newFile = CourseFile(
            id: '',
            videoId: videoId,
            title: attachment.title,
            description: attachment.description,
            fileId: fileId,
            fileType: attachment.fileType ?? 'unknown',
            fileSize: attachment.fileSize ?? 0,
            downloadCount: 0,
            orderNumber: 0,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );

          await CourseVideosService.addCourseFile(newFile);
        } catch (e) {
          debugPrint('فشل في رفع الملف: $e');
          await progressTimer.cancel();
        } finally {
          setState(() => _isUploading = false);
        }
      }
    }
  }

  void _openBunnyStreamDashboard() async {
    const url = 'https://dash.bunny.net/stream/library';
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل في فتح لوحة التحكم: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.videoToEdit != null;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          isEditing ? 'تعديل فيديو' : 'إضافة فيديو جديد',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        backgroundColor: AppColors.buttonPrimary,
        elevation: 0,
        actions: [
          // إضافة زر لفتح لوحة تحكم Bunny.net
          IconButton(
            icon: const Icon(Icons.open_in_browser, color: Colors.white),
            onPressed: _openBunnyStreamDashboard,
            tooltip: 'فتح لوحة تحكم Bunny.net',
          ),
        ],
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
          child: Stack(
            children: [
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Section selection
                            _buildSectionSelector(),
                            const SizedBox(height: 24),

                            // اختيار ورفع الفيديو
                            _buildVideoSection(),
                            const SizedBox(height: 24),

                            // تفاصيل الفيديو - تعديل لإظهار العنوان كحقل اختياري
                            _buildVideoDetails(),
                            const SizedBox(height: 24),

                            // المرفقات
                            _buildAttachmentsSection(),
                            const SizedBox(height: 32),

                            // زر الحفظ
                            ElevatedButton(
                              onPressed: _saveVideo,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.buttonPrimary,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                isEditing ? 'حفظ التعديلات' : 'إضافة الفيديو',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

              // عرض شريط التقدم عند الرفع
              if (_isUploading)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: _buildUploadProgress(),
                ),

              // عرض مربع حوار إنشاء قسم جديد
              if (_isCreatingNewSection)
                Positioned.fill(
                  child: GestureDetector(
                    onTap: () {
                      // Close dialog if tapped outside
                      setState(() {
                        _isCreatingNewSection = false;
                      });
                    },
                    child: Container(
                      color: Colors.black.withOpacity(0.5),
                      child: Center(
                        child: GestureDetector(
                          onTap:
                              () {}, // Prevent closing when tapping inside dialog
                          child: _buildCreateSectionDialog(),
                        ),
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

  Widget _buildUploadProgress() {
    return Container(
      color: Colors.black.withOpacity(0.7),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'جاري رفع الملف... ${(_uploadProgress * 100).toInt()}%',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: _uploadProgress,
            backgroundColor: Colors.grey[700],
            valueColor:
                const AlwaysStoppedAnimation<Color>(AppColors.buttonPrimary),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoSection() {
    final hasBunnyId = _bunnyVideoIdController.text.isNotEmpty;
    final isEditMode = widget.videoToEdit != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'الفيديو',
                style: AppTextStyles.titleMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.buttonPrimary,
                ),
              ),
            ),
            if (hasBunnyId)
              IconButton(
                icon: const Icon(Icons.edit, color: AppColors.buttonPrimary),
                onPressed: _enterBunnyVideoId,
                tooltip: 'تعديل معرف الفيديو',
              ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 160,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: InkWell(
            onTap: hasBunnyId ? _enterBunnyVideoId : _pickAndUploadVideo,
            borderRadius: BorderRadius.circular(12),
            child: hasBunnyId
                ? Stack(
                    alignment: Alignment.center,
                    children: [
                      // Show thumbnail if we have a video ID
                      if (_bunnyVideoIdController.text.isNotEmpty)
                        Positioned.fill(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              BunnyConfig.getThumbnailUrl(
                                  _bunnyVideoIdController.text),
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(),
                            ),
                          ),
                        ),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.video_library,
                              size: 40,
                              color: Colors.white.withOpacity(0.8),
                            ),
                            const SizedBox(height: 12),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              child: Text(
                                'معرف الفيديو: ${_bunnyVideoIdController.text}',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'انقر لتغيير معرف الفيديو',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.cloud_upload,
                        size: 40,
                        color: Colors.white.withOpacity(0.8),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        isEditMode ? 'تغيير الفيديو' : 'رفع فيديو جديد',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'انقر لاختيار ورفع فيديو',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'أو أدخل معرف الفيديو يدويًا',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
              TextButton(
                onPressed: _enterBunnyVideoId,
                child: const Text('إدخال معرف الفيديو'),
              ),
            ],
          ),
        ),
        // إضافة أزرار نماذج اختبار جاهزة
        _buildTestSamplesButtons(),
      ],
    );
  }

  Widget _buildTestSamplesButtons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            'نماذج اختبار سريعة',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildTestSampleButton(
                'فيديو اختبار',
                '989b0866-b522-4c56-b7c3-487d858943ed',
              ),
            ],
          ),
        ),
        if (_bunnyVideoIdController.text ==
            '989b0866-b522-4c56-b7c3-487d858943ed')
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildVideoInfoItem(
                    title: 'رابط HLS',
                    value:
                        'https://vz-00908cfa-8cc.b-cdn.net/989b0866-b522-4c56-b7c3-487d858943ed/playlist.m3u8'),
                _buildVideoInfoItem(
                    title: 'رابط الصورة المصغرة',
                    value:
                        'https://vz-00908cfa-8cc.b-cdn.net/989b0866-b522-4c56-b7c3-487d858943ed/thumbnail.jpg'),
                _buildVideoInfoItem(
                    title: 'رابط المعاينة المتحركة',
                    value:
                        'https://vz-00908cfa-8cc.b-cdn.net/989b0866-b522-4c56-b7c3-487d858943ed/preview.webp'),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildVideoInfoItem({required String title, required String value}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: AppColors.textSecondary,
            ),
          ),
          Row(
            children: [
              // Limit the text size to prevent overflow
              Expanded(
                child: Text(
                  value,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Add some spacing to avoid the copy icon being too close to the text
              const SizedBox(width: 4),
              // Use minimumSize instead of constraints to avoid overflow
              IconButton(
                icon: const Icon(Icons.copy, size: 14),
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: value)).then((_) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('تم نسخ الرابط')),
                      );
                    }
                  });
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTestSampleButton(String label, String videoId) {
    final isSelected = _bunnyVideoIdController.text == videoId;

    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: ElevatedButton.icon(
        onPressed: () {
          setState(() {
            _bunnyVideoIdController.text = videoId;
            _autoUpdateTitle = true;
          });

          // التحقق من معلومات الفيديو
          CourseVideosService.getVideoDetails(videoId).then((details) {
            setState(() {
              if (_autoUpdateTitle && details['title'] != null) {
                _titleController.text = details['title'];
              }
            });
          }).catchError((e) {
            debugPrint('خطأ في الحصول على تفاصيل الفيديو: $e');
          });
        },
        icon: Icon(
          isSelected ? Icons.check_circle : Icons.video_library,
          size: 16,
        ),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: isSelected
              ? AppColors.buttonPrimary
              : AppColors.buttonSecondary.withOpacity(0.7),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          textStyle: const TextStyle(fontSize: 12),
        ),
      ),
    );
  }

  Widget _buildVideoDetails() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'معلومات الفيديو',
            style: AppTextStyles.titleMedium.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.buttonPrimary,
            ),
          ),
          const SizedBox(height: 16),
          // عنوان اختياري (سيتم أخذه من الفيديو إذا كان فارغاً)
          TextFormField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'عنوان الفيديو (اختياري)',
              hintText: 'سيتم استخدام عنوان الفيديو الأصلي إذا تُرك فارغاً',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              // إذا قام المستخدم بتعديل العنوان، لا نريد تحديثه تلقائيًا بعد ذلك
              if (value.isNotEmpty) {
                setState(() {
                  _autoUpdateTitle = false;
                });
              } else {
                setState(() {
                  _autoUpdateTitle = true;
                });
              }
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _descriptionController,
            decoration: const InputDecoration(
              labelText: 'وصف الفيديو (اختياري)',
              hintText: 'أدخل وصف الفيديو',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          // حقل معرف الفيديو - مخفي ولكن مطلوب
          Opacity(
            opacity: 0.0,
            child: TextFormField(
              controller: _bunnyVideoIdController,
              decoration: const InputDecoration(
                labelText: 'معرف الفيديو',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'يرجى إدخال معرف الفيديو من Bunny.net';
                }
                return null;
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttachmentsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text(
          'الملفات المرفقة (اختياري)',
          style: AppTextStyles.titleMedium.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.buttonPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _pickAttachment,
                icon: const Icon(
                  Icons.attach_file,
                  size: 18,
                  color: Colors.white,
                ),
                label: const Text('إضافة ملف مرفق',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    )),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.buttonSecondary,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // عرض قائمة الملفات المختارة
        for (int i = 0; i < _attachments.length; i++) _buildAttachmentItem(i),
      ],
    );
  }

  Widget _buildAttachmentItem(int index) {
    final attachment = _attachments[index];
    final fileIcon = attachment.isExistingFile
        ? _getFileIcon(attachment.existingFile!.fileType)
        : _getFileIcon(attachment.file!.path);

    final fileSize = attachment.isExistingFile
        ? attachment.existingFile!.formattedSize
        : _formatFileSize(attachment.file!);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 3,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(fileIcon, color: AppColors.buttonSecondary, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // حقل نصي لتعديل اسم الملف المعروض
                    TextField(
                      controller: attachment.nameController,
                      decoration: InputDecoration(
                        hintText: 'اسم الملف المعروض',
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.clear, size: 16),
                          onPressed: () => attachment.nameController.clear(),
                        ),
                      ),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'الاسم الأصلي: ${attachment.originalFileName}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.insert_drive_file_outlined,
                            size: 12, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Text(
                          'الحجم: $fileSize',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        if (attachment.isExistingFile)
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: Text(
                              '(ملف موجود)',
                              style: TextStyle(
                                fontSize: 10,
                                fontStyle: FontStyle.italic,
                                color: Colors.green.shade700,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                onPressed: () => _removeAttachment(index),
              ),
            ],
          ),
          if (attachment.isUploading) ...[
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: attachment.uploadProgress,
              backgroundColor: Colors.grey.shade200,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppColors.buttonPrimary),
            ),
            const SizedBox(height: 4),
            Text(
              'جاري الرفع... ${(attachment.uploadProgress * 100).toInt()}%',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  IconData _getFileIcon(String fileType) {
    switch (fileType.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow;
      case 'jpg':
      case 'jpeg':
      case 'png':
        return Icons.image;
      default:
        return Icons.insert_drive_file;
    }
  }

  String _formatFileSize(File file) {
    final sizeInBytes = file.lengthSync();
    if (sizeInBytes < 1024) {
      return '$sizeInBytes B';
    } else if (sizeInBytes < 1024 * 1024) {
      return '${(sizeInBytes / 1024).toStringAsFixed(1)} KB';
    } else if (sizeInBytes < 1024 * 1024 * 1024) {
      return '${(sizeInBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(sizeInBytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }

  // Section selector widget - completely rewritten to fix syntax errors
  Widget _buildSectionSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // const Icon(Icons.folder, color: AppColors.accent),
              // const SizedBox(width: 8),
              Text(
                'قسم الفيديو (اختياري)',
                style: AppTextStyles.titleMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.buttonPrimary,
                  fontSize: 12,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _isCreatingNewSection = true;
                  });
                },
                icon: const Icon(Icons.add, size: 16),
                label: const Text('قسم جديد'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_isSectionsLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else if (_sections.isEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'لا توجد أقسام في هذا الكورس بعد',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.amber,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'انقر على "قسم جديد" لإنشاء أول قسم في هذا الكورس',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.amber.shade800,
                    ),
                  ),
                ],
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: DropdownButton<String?>(
                    value: _selectedSectionId,
                    isExpanded: true,
                    underline: Container(), // Remove the default underline
                    icon: const Icon(Icons.arrow_drop_down),
                    hint: const Text(
                      'اختر قسم الفيديو (اختياري)',
                      style: TextStyle(fontSize: 14),
                    ),
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                    onChanged: (sectionId) {
                      setState(() {
                        _selectedSectionId = sectionId;
                      });
                    },
                    items: [
                      // "No section" option that explicitly returns null
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('بدون قسم'),
                      ),
                      // Add a custom divider
                      const DropdownMenuItem<String?>(
                        enabled: false,
                        value:
                            'divider', // use a unique string that won't match any section id
                        child: Divider(thickness: 1),
                      ),
                      // Add all sections as options
                      ..._sections.map((section) {
                        return DropdownMenuItem<String?>(
                          value: section.id,
                          child: Text(section.title),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Dialog for creating a new section
  Widget _buildCreateSectionDialog() {
    return Container(
      width: MediaQuery.of(context).size.width * 0.85,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.folder_open, color: AppColors.buttonPrimary),
              const SizedBox(width: 8),
              Text(
                'إنشاء قسم جديد',
                style: AppTextStyles.titleMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  setState(() {
                    _isCreatingNewSection = false;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _newSectionTitleController,
            decoration: const InputDecoration(
              labelText: 'عنوان القسم *',
              hintText: 'أدخل عنوان القسم',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _newSectionDescriptionController,
            decoration: const InputDecoration(
              labelText: 'وصف القسم (اختياري)',
              hintText: 'أدخل وصف القسم',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _createNewSection,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.buttonPrimary,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: const Text('إنشاء القسم'),
          ),
        ],
      ),
    );
  }
}

class AttachmentFile {
  File? file; // Now optional
  String originalFileName;
  String displayName;
  TextEditingController nameController;
  bool isUploading = false;
  double uploadProgress = 0.0;
  CourseFile? existingFile;

  // Standard constructor for new files
  AttachmentFile({
    required File file,
    required this.originalFileName,
    required String displayName,
    this.existingFile,
  })  : file = file,
        displayName = displayName,
        nameController = TextEditingController(text: displayName);

  // New constructor for existing files
  AttachmentFile.fromExisting({
    required this.existingFile,
    required this.originalFileName,
    required String displayName,
  })  : file = null, // No local file for existing ones
        displayName = displayName,
        nameController = TextEditingController(text: displayName);

  // Property to check if it's an existing file
  bool get isExistingFile => existingFile != null && file == null;

  // Update getter for title
  String get title => nameController.text.trim().isNotEmpty
      ? nameController.text.trim()
      : originalFileName;

  String? get description => null;

  // Update getter for file type
  String? get fileType {
    if (isExistingFile) {
      return existingFile!.fileType;
    } else if (file != null) {
      final extension =
          path.extension(file!.path).toLowerCase().replaceAll('.', '');
      return extension.isNotEmpty ? extension : 'unknown';
    }
    return null;
  }

  // Update getter for file size
  int? get fileSize {
    if (isExistingFile) {
      return existingFile!.fileSize;
    } else if (file != null) {
      try {
        return file!.lengthSync();
      } catch (e) {
        debugPrint('Error getting file size: $e');
        return null;
      }
    }
    return null;
  }

  // Getter for formatted size
  String get formattedSize {
    final size = fileSize;
    if (size == null) return 'Unknown size';

    if (size < 1024) {
      return '$size B';
    } else if (size < 1024 * 1024) {
      return '${(size / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }

  // يمكن استخدام هذه الدالة للحصول على الاسم المعروض النهائي
  String getFinalDisplayName() {
    return nameController.text.trim().isNotEmpty
        ? nameController.text.trim()
        : originalFileName;
  }
}
