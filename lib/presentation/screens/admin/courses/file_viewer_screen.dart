import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:http/http.dart' as http;
import 'package:mycourses/core/constants/app_colors.dart';
import 'package:mycourses/core/constants/app_text_styles.dart';
// Añadir esta importación
import 'package:mycourses/core/services/course_videos_service.dart';
import 'package:mycourses/models/course_video.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class FileViewerScreen extends StatefulWidget {
  final CourseFile file;
  final String fileUrl;

  const FileViewerScreen({
    super.key,
    required this.file,
    required this.fileUrl,
  });

  @override
  State<FileViewerScreen> createState() => _FileViewerScreenState();
}

class _FileViewerScreenState extends State<FileViewerScreen> {
  bool _isLoading = true;
  String? _localFilePath;
  String? _errorMessage;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _downloadAndOpenFile();
  }

  Future<void> _downloadAndOpenFile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _isDownloading = true;
      _downloadProgress = 0.0;
    });

    try {
      final url = widget.fileUrl;
      debugPrint('جاري تحميل الملف من الرابط: $url');

      // تحسين رؤوس HTTP للتغلب على مشاكل CORS وأي قيود أخرى
      final headers = {
        'Accept': '*/*',
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
        'Origin': 'https://mysite.com', // يمكن تغييره إلى موقعك
        'Referer': 'https://mysite.com/', // يمكن تغييره إلى موقعك
      };

      // تجربة تنزيل الملف مع رؤوس HTTP محسنة
      final request = http.Request('GET', Uri.parse(url));
      request.headers.addAll(headers);

      // طباعة الرؤوس للتشخيص
      debugPrint('HTTP Headers: ${request.headers}');

      final response = await http.Client().send(request);

      if (response.statusCode != 200) {
        throw Exception('فشل تحميل الملف: رمز الحالة ${response.statusCode}');
      }

      // الحصول على مجلد التطبيق المؤقت
      final directory = await getTemporaryDirectory();

      // استخدام اسم الملف الأصلي (إزالة الطابع الزمني)
      final originalFileName = _extractOriginalFileName(widget.file.fileId);
      final filePath = '${directory.path}/$originalFileName';

      // إنشاء ملف محلي
      final file = File(filePath);
      final fileSize = response.contentLength ?? 0;
      final fileStream = file.openWrite();

      int bytesReceived = 0;

      // تنزيل الملف مع عرض تقدم التحميل
      await response.stream.listen((bytes) {
        fileStream.add(bytes);
        bytesReceived += bytes.length;

        if (fileSize > 0) {
          setState(() {
            _downloadProgress = bytesReceived / fileSize;
          });
        }
      }).asFuture();

      await fileStream.close();

      // حفظ المسار للاستخدام في العرض
      setState(() {
        _localFilePath = filePath;
        _isLoading = false;
        _isDownloading = false;
      });
    } catch (e) {
      debugPrint('خطأ أثناء تحميل الملف: $e');
      setState(() {
        _errorMessage = 'فشل في تحميل الملف: $e';
        _isLoading = false;
        _isDownloading = false;
      });
    }
  }

  // دالة مساعدة لاستخراج اسم الملف الأصلي من معرف الملف المخزن
  String _extractOriginalFileName(String fileId) {
    // تنسيق الملف المخزن: 1742890582822_Free Courses.pdf
    // نريد استخراج اسم الملف الأصلي بعد الشرطة التحتية
    try {
      final parts = fileId.split('_');
      if (parts.length > 1) {
        // إزالة الطابع الزمني واستخدام اسم الملف الأصلي
        return fileId.substring(fileId.indexOf('_') + 1);
      }
    } catch (e) {
      debugPrint('خطأ في استخراج اسم الملف: $e');
    }
    // في حال الفشل، استخدم اسم الملف كاملاً
    return fileId;
  }

  // إضافة زر جديد لإعادة التنزيل بصورة صريحة (مثلاً إذا كان هناك خطأ)
  Future<void> _retryWithNewToken() async {
    try {
      // توليد رابط جديد بتوقيت حالي جديد
      final newUrl =
          CourseVideosService.getDirectStorageUrl(widget.file.fileId);

      // إعادة تعيين المتغيرات وعرض واجهة التحميل
      setState(() {
        _localFilePath = null;
        _errorMessage = null;
        _isLoading = true;
        _isDownloading = true;
        _downloadProgress = 0.0;
      });

      // مساعدة المطور في التشخيص
      debugPrint('محاولة تنزيل الملف عبر رابط مباشر: $newUrl');

      // تحسين رؤوس HTTP للمساعدة في الوصول
      final headers = {
        'Accept': '*/*',
        'User-Agent': 'Mozilla/5.0 BunnyFileDownloader/1.0',
        'Content-Type': 'application/octet-stream',
        'AccessKey':
            '4aaa2c3f-7d2e-4c7c-b5cedea9b01b-b225-45d6', // إضافة المفتاح مباشرة للتغلب على المشاكل
      };

      // إنشاء طلب HTTP مع الرؤوس المخصصة
      final request = http.Request('GET', Uri.parse(newUrl));
      request.headers.addAll(headers);

      // طباعة الرؤوس للتشخيص
      debugPrint('HTTP Headers: ${request.headers}');

      final response = await http.Client().send(request);

      if (response.statusCode != 200) {
        throw Exception('فشل تحميل الملف: رمز الحالة ${response.statusCode}');
      }

      // الحصول على مجلد التطبيق المؤقت
      final directory = await getTemporaryDirectory();
      final originalFileName = _extractOriginalFileName(widget.file.fileId);
      final filePath = '${directory.path}/$originalFileName';

      // إنشاء ملف محلي
      final file = File(filePath);
      final fileSize = response.contentLength ?? 0;
      final fileStream = file.openWrite();

      int bytesReceived = 0;

      // تنزيل الملف مع عرض تقدم التحميل
      await response.stream.listen((bytes) {
        fileStream.add(bytes);
        bytesReceived += bytes.length;

        if (fileSize > 0 && mounted) {
          setState(() {
            _downloadProgress = bytesReceived / fileSize;
          });
        }
      }).asFuture();

      await fileStream.close();

      // حفظ المسار للاستخدام في العرض
      if (mounted) {
        setState(() {
          _localFilePath = filePath;
          _isLoading = false;
          _isDownloading = false;
        });
      }
    } catch (e) {
      debugPrint('خطأ أثناء إعادة تحميل الملف: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'فشل في تحميل الملف: $e';
          _isLoading = false;
          _isDownloading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.file.title,
          style: AppTextStyles.titleMedium,
        ),
        actions: [
          if (_localFilePath != null) ...[
            // 1. زر الفتح المباشر (بأيقونة جديدة)
            IconButton(
              icon: const Icon(Icons.open_in_new),
              onPressed: _openExternally,
              tooltip: 'فتح الملف',
            ),
            // 2. زر التنزيل الجديد (مع اختيار المكان)
            IconButton(
              icon: const Icon(Icons.download),
              onPressed: _saveFileToDownloads,
              tooltip: 'تنزيل الملف',
            ),
            // 3. زر المشاركة (كما هو)
            IconButton(
              icon: const Icon(Icons.share),
              onPressed: _shareFile,
              tooltip: 'مشاركة الملف',
            ),
          ],
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isDownloading) ...[
              CircularProgressIndicator(
                value: _downloadProgress > 0 ? _downloadProgress : null,
                color: AppColors.buttonPrimary,
              ),
              const SizedBox(height: 16),
              Text(
                'جاري تحميل الملف (${(_downloadProgress * 100).toStringAsFixed(0)}%)...',
                style: AppTextStyles.bodyMedium,
              ),
            ] else ...[
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'جاري تحميل الملف...',
                style: AppTextStyles.bodyMedium,
              ),
            ],
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return _buildErrorState();
    }

    if (_localFilePath != null) {
      return _buildFileViewer();
    }

    return const Center(
      child: Text('حدث خطأ غير متوقع'),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              'فشل في فتح الملف',
              style: AppTextStyles.titleMedium.copyWith(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              style: AppTextStyles.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: _downloadAndOpenFile,
                  icon: const Icon(Icons.refresh),
                  label: const Text('إعادة المحاولة'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.buttonPrimary,
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _retryWithNewToken,
                  icon: const Icon(Icons.security),
                  label: const Text('تحديث الرابط'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('العودة'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileViewer() {
    final fileType = widget.file.fileType.toLowerCase();

    // عارض ملفات PDF
    if (fileType == 'pdf') {
      return PDFView(
        filePath: _localFilePath!,
        enableSwipe: true,
        swipeHorizontal: false,
        autoSpacing: true,
        pageFling: true,
        onError: (error) {
          setState(() {
            _errorMessage = 'فشل في عرض ملف PDF: $error';
          });
        },
        onPageError: (page, error) {
          debugPrint('خطأ في صفحة $page: $error');
        },
      );
    }

    // عارض الصور
    else if (fileType == 'jpg' || fileType == 'jpeg' || fileType == 'png') {
      return Center(
        child: Image.file(
          File(_localFilePath!),
          errorBuilder: (context, error, stackTrace) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.broken_image, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                Text('فشل في عرض الصورة: $error'),
              ],
            );
          },
        ),
      );
    }

    // عارض الويب للملفات الأخرى
    else {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.insert_drive_file,
              size: 72,
              color: AppColors.buttonPrimary,
            ),
            const SizedBox(height: 24),
            Text(
              widget.file.title,
              style: AppTextStyles.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'نوع الملف: ${widget.file.fileType}',
              style: AppTextStyles.bodyMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'حجم الملف: ${widget.file.formattedSize}',
              style: AppTextStyles.bodyMedium,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _openExternally,
              icon: const Icon(Icons.open_in_new),
              label: const Text('فتح الملف باستخدام تطبيق خارجي'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.buttonPrimary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _openExternally() async {
    try {
      final result = await OpenFile.open(_localFilePath!);
      if (result.type != ResultType.done) {
        setState(() {
          _errorMessage = 'فشل في فتح الملف: ${result.message}';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'فشل في فتح الملف: $e';
      });
    }
  }

  // دالة جديدة مخصصة للمشاركة مع معالجة أفضل للأخطاء وطرق مشاركة بديلة
  Future<void> _shareFile() async {
    try {
      if (_localFilePath == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لم يتم تنزيل الملف بعد')),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('جاري مشاركة الملف...')),
      );

      // 1. أولاً نحاول استخدام الطريقة العادية من مكتبة share_plus
      try {
        await Share.shareXFiles(
          [XFile(_localFilePath!)],
          text: widget.file.title,
          subject: 'مشاركة: ${widget.file.title}',
        );
        return; // إذا نجحت، نخرج من الدالة
      } catch (shareError) {
        debugPrint('فشل الطريقة الأولى للمشاركة: $shareError');

        // 2. نحاول استخدام طريقة Share.share البسيطة
        try {
          await Share.share(
            'مشاركة: ${widget.file.title}',
            subject: widget.file.title,
          );
          return; // إذا نجحت، نخرج من الدالة
        } catch (simpleShareError) {
          debugPrint('فشل الطريقة الثانية للمشاركة: $simpleShareError');

          // 3. نحاول استخدام قناة مخصصة للمشاركة
          try {
            final channel = MethodChannel('com.example.mycourses/file_sharing');
            await channel.invokeMethod('shareFile', {
              'filePath': _localFilePath,
              'title': widget.file.title,
            });
            return; // إذا نجحت، نخرج من الدالة
          } catch (channelError) {
            debugPrint('فشل المشاركة عبر القناة المخصصة: $channelError');

            // 4. كحل أخير، نحاول فتح الملف مباشرة
            final result = await OpenFile.open(_localFilePath!);
            if (result.type != ResultType.done) {
              throw Exception('فشل في فتح الملف: ${result.message}');
            }
          }
        }
      }
    } catch (e) {
      debugPrint('خطأ في مشاركة الملف: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل في مشاركة الملف: $e')),
      );
    }
  }

  // دالة التنزيل المحسنة التي تتيح اختيار موقع التخزين بحرية كاملة
  Future<void> _saveFileToDownloads() async {
    if (_localFilePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لم يتم تنزيل الملف بعد')),
      );
      return;
    }

    try {
      // استخدام اسم الملف الأصلي
      final originalFileName = _extractOriginalFileName(widget.file.fileId);
      final fileExtension = widget.file.fileType.toLowerCase();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('جاري تحضير وضع التخزين...')),
      );

      String? saveLocation;

      if (Platform.isAndroid) {
        // 1. على أندرويد، استخدم FilePicker لاختيار المجلد
        final directoryPath = await FilePicker.platform.getDirectoryPath(
          dialogTitle: 'اختر مكان تخزين الملف',
        );

        if (directoryPath != null) {
          saveLocation = '$directoryPath/$originalFileName';
        }
      } else {
        // 2. على نظم التشغيل المكتبية، استخدم saveFile المباشر
        saveLocation = await FilePicker.platform.saveFile(
          dialogTitle: 'حفظ الملف',
          fileName: originalFileName,
          allowedExtensions: [fileExtension],
          type: FileType.custom,
        );
      }

      // إذا اختار المستخدم مكان للحفظ، نقوم بنسخ الملف
      if (saveLocation != null && saveLocation.isNotEmpty) {
        // نسخ الملف إلى المكان المختار
        final sourceFile = File(_localFilePath!);
        await sourceFile.copy(saveLocation);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('تم حفظ الملف بنجاح في المكان المختار'),
              action: SnackBarAction(
                label: 'فتح',
                onPressed: () => OpenFile.open(saveLocation),
              ),
              duration: const Duration(seconds: 5),
            ),
          );
        }
      } else {
        // المستخدم ألغى العملية
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم إلغاء عملية الحفظ')),
          );
        }
      }
    } catch (e) {
      debugPrint('خطأ أثناء محاولة حفظ الملف: $e');

      // في حالة الفشل، نعرض خيارات الحفظ البديلة
      _showFallbackSaveOptions();
    }
  }

  // دالة لعرض خيارات الحفظ البديلة في حال فشل الطريقة الرئيسية
  void _showFallbackSaveOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.folder),
            title: const Text('حفظ في مجلد التنزيلات'),
            onTap: () {
              Navigator.pop(context);
              _saveFileFallbackToDownloads();
            },
          ),
          ListTile(
            leading: const Icon(Icons.share),
            title: const Text('مشاركة الملف'),
            onTap: () {
              Navigator.pop(context);
              _shareFile();
            },
          ),
          ListTile(
            leading: const Icon(Icons.open_in_new),
            title: const Text('فتح الملف مباشرة'),
            onTap: () {
              Navigator.pop(context);
              _openExternally();
            },
          ),
        ],
      ),
    );
  }

  // تعديل الدالة الحالية للتركيز على التنزيل فقط
  Future<void> _saveFileFallbackToDownloads() async {
    try {
      final originalFileName = _extractOriginalFileName(widget.file.fileId);

      // استخدام مكتبة path_provider للوصول إلى مجلد التنزيلات
      Directory? downloadsDir;

      if (Platform.isAndroid) {
        // محاولة الوصول إلى مجلد التنزيلات باستخدام طرق متعددة
        try {
          downloadsDir = Directory('/storage/emulated/0/Download');
          if (!await downloadsDir.exists()) {
            throw Exception('مجلد التنزيلات غير موجود');
          }
        } catch (_) {
          // الطريقة البديلة - استخدام المجلد العام
          final extDir = await getExternalStorageDirectory();
          downloadsDir = extDir;
        }
      } else {
        // لنظام iOS ونظم التشغيل الأخرى
        downloadsDir = await getApplicationDocumentsDirectory();
      }

      if (downloadsDir == null) {
        throw Exception('لم يتم العثور على مجلد التنزيلات');
      }

      // تكوين مسار الملف الهدف
      final targetPath = '${downloadsDir.path}/$originalFileName';

      // نسخ الملف
      final sourceFile = File(_localFilePath!);
      await sourceFile.copy(targetPath);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم حفظ الملف في: $targetPath'),
            action: SnackBarAction(
              label: 'فتح',
              onPressed: () => OpenFile.open(targetPath),
            ),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      debugPrint('خطأ في الطريقة الاحتياطية: $e');
      throw Exception('فشل في حفظ الملف: $e');
    }
  }

  // تحسين دالة حذف المرفق لعرض حالة الحذف بشكل أفضل
  Future<void> _deleteAttachment(CourseFile file) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('هل أنت متأكد من حذف الملف "${file.title}"؟'),
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
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('حذف نهائياً'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // Show loading dialog with more user-friendly message
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('جاري حذف الملف من الخادم...'),
            ],
          ),
        ),
      );

      try {
        // Delete from server first
        final bool result = await CourseVideosService.deleteCourseFile(file.id);

        // Close the loading dialog
        if (mounted) Navigator.of(context).pop();

        if (result) {
          if (mounted) {
            // Show success message and close the file viewer
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('تم حذف الملف بنجاح من الخادم وقاعدة البيانات'),
                backgroundColor: Colors.green,
              ),
            );

            // Wait a moment to show the success message before closing
            await Future.delayed(const Duration(milliseconds: 800));
            if (mounted) {
              Navigator.of(context)
                  .pop(true); // Return true to indicate deletion
            }
          }
        } else {
          throw Exception('فشل في حذف الملف من الخادم');
        }
      } catch (e) {
        // Close the loading dialog if still open
        if (mounted) Navigator.of(context).pop();

        // Show error message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('فشل في حذف الملف: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  void dispose() {
    // تنظيف الملف المؤقت عند الخروج من الشاشة إذا لزم الأمر
    super.dispose();
  }
}
