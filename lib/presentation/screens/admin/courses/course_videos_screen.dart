import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:mycourses/core/constants/app_colors.dart';
import 'package:mycourses/core/providers/player_options_provider.dart';
import 'package:mycourses/core/services/bunny_storage_service.dart';
import 'package:mycourses/core/services/course_videos_service.dart';
import 'package:mycourses/core/services/player_preferences_service.dart';
import 'package:mycourses/core/utils/drm_helper.dart';
import 'package:mycourses/models/course.dart';
import 'package:mycourses/models/course_section.dart';
import 'package:mycourses/models/course_video.dart';
import 'package:mycourses/presentation/screens/admin/courses/add_video_screen.dart';
import 'package:mycourses/presentation/screens/admin/courses/components/course_video_detail_component.dart';
import 'package:mycourses/presentation/screens/admin/courses/components/course_video_dialog_utils.dart';
import 'package:mycourses/presentation/screens/admin/courses/components/course_video_list_component.dart';
import 'package:mycourses/presentation/screens/admin/courses/components/course_video_player_component.dart';
// Import component files
import 'package:mycourses/presentation/screens/admin/courses/components/course_video_ui_utils.dart';
import 'package:mycourses/presentation/screens/admin/courses/file_viewer_screen.dart';
import 'package:mycourses/presentation/widgets/course_video_header.dart';
import 'package:mycourses/presentation/widgets/custom_progress_indicator.dart';
import 'package:pod_player/pod_player.dart';
import 'package:webview_flutter/webview_flutter.dart';

class CourseVideosScreen extends StatefulWidget {
  final Course course;

  const CourseVideosScreen({super.key, required this.course});

  @override
  State<CourseVideosScreen> createState() => _CourseVideosScreenState();
}

class _CourseVideosScreenState extends State<CourseVideosScreen>
    with WidgetsBindingObserver {
  // Core state variables
  bool _isLoading = true;
  List<CourseVideo> _videos = [];
  List<CourseSection> _sections = [];
  Map<String, List<CourseVideo>> _videosBySection = {};
  List<CourseVideo> _uncategorizedVideos = [];
  Set<String> _expandedSections = {};
  String? _errorMessage;
  CourseVideo? _selectedVideo;
  bool _isDetailsExpanded = false;

  // UI state variables
  final ScrollController _scrollController = ScrollController();
  bool _isDetailsVisible =
      true; // تغيير من _isVideoMinimized إلى _isDetailsVisible
  String _selectedPlayerType = 'iframe';
  bool _isDrmProtected = false;
  final bool _isPlayerLoading = false;
  final GlobalKey _playerKey = GlobalKey();
  bool _isVideoExpanded = false;
  bool _showVideoDetails = false;

  // Playback state variables
  Duration _currentVideoPosition = Duration.zero;
  dynamic _videoPlayerController;
  final Map<String, Duration> _videoPositions = {};
  bool _isNavigating = false;

  // إضافة مؤشر لتتبع ما إذا كانت الشاشة نشطة
  bool _isActive = true;

  // تعديل متغير التحكم للتعامل مع حياة المشغل
  bool _isPlayerBeingDisposed = false;

  // إضافة مؤشر للتحكم في محاولات إعادة البناء
  bool _isRebuildPrevented = false;

  @override
  void initState() {
    super.initState();
    _isActive = true;

    // إضافة مراقب لدورة حياة التطبيق لتنظيف الموارد عند تعليق التطبيق
    WidgetsBinding.instance.addObserver(this);

    _loadVideosAndSections();
    _loadPlayerPreference();

    // تعديل آلية التمرير لإخفاء التفاصيل فقط بدلاً من تصغير الفيديو
    _scrollController.addListener(() {
      final shouldHideDetails = _scrollController.offset > 50;
      if (shouldHideDetails != !_isDetailsVisible) {
        setState(() {
          _isDetailsVisible = !shouldHideDetails;
        });
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // تنظيف الموارد عندما يتم تعليق التطبيق
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      // حفظ موضع التشغيل الحالي
      _saveCurrentPlaybackPosition();

      // تنظيف مشغل الفيديو للتأكد من عدم تشغيل الفيديو في الخلفية
      if (_videoPlayerController != null && _selectedPlayerType == 'iframe') {
        _disposeVideoController();
      }
    }

    // منع إعادة البناء عند تعليق التطبيق
    if (state == AppLifecycleState.paused) {
      _isRebuildPrevented = true;
    } else if (state == AppLifecycleState.resumed) {
      // السماح بإعادة البناء عند استئناف التطبيق
      _isRebuildPrevented = false;
    }
  }

  @override
  void dispose() {
    _isActive = false;

    // إزالة مراقب دورة حياة التطبيق
    WidgetsBinding.instance.removeObserver(this);

    // تنظيف موارد الشاشة بشكل صحيح
    try {
      // إلغاء المستمعين لتجنب مشاكل دورة الحياة
      _scrollController.removeListener(_handleScroll);
      _scrollController.dispose();

      // تنظيف مشغل الفيديو الحالي
      _disposeVideoController();

      // إعادة توجيه الشاشة للوضع العمودي
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
          overlays: SystemUiOverlay.values);
    } catch (e) {
      debugPrint('خطأ أثناء تنظيف الموارد: $e');
    }
    super.dispose();
  }

  void _handleScroll() {
    final shouldMinimize = _scrollController.offset > 50;
    if (shouldMinimize != _isDetailsVisible) {
      setState(() {
        _isDetailsVisible = shouldMinimize;
      });
    }
  }

  // دالة منفصلة للتخلص من مشغل الفيديو
  void _disposeVideoController() {
    try {
      if (_videoPlayerController != null && !_isPlayerBeingDisposed) {
        _isPlayerBeingDisposed = true;

        debugPrint(
            '⚙️ تنظيف مشغل الفيديو نوع: ${_videoPlayerController.runtimeType}');

        if (_videoPlayerController is VideoPlayerController) {
          (_videoPlayerController as VideoPlayerController).pause().then((_) {
            (_videoPlayerController as VideoPlayerController).dispose();
            _videoPlayerController = null;
            _isPlayerBeingDisposed = false;
          }).catchError((e) {
            debugPrint('⚠️ خطأ عند تنظيف VideoPlayerController: $e');
            _videoPlayerController = null;
            _isPlayerBeingDisposed = false;
          });
        } else if (_videoPlayerController is WebViewController) {
          // الطريقة الصحيحة لتنظيف WebViewController
          try {
            // محاولة تحميل صفحة فارغة لوقف JavaScript
            (_videoPlayerController as WebViewController)
                .loadRequest(Uri.parse('about:blank'))
                .then((_) {
              debugPrint('✅ تم تحميل صفحة فارغة في WebViewController');
              _videoPlayerController = null;
              _isPlayerBeingDisposed = false;
            }).catchError((e) {
              debugPrint('⚠️ خطأ عند تحميل صفحة فارغة: $e');
              _videoPlayerController = null;
              _isPlayerBeingDisposed = false;
            });
          } catch (e) {
            // التعامل مع الأخطاء في WebViewController
            debugPrint('⚠️ خطأ عند تنظيف WebViewController: $e');
            _videoPlayerController = null;
            _isPlayerBeingDisposed = false;
          }
        } else if (_videoPlayerController is Player) {
          (_videoPlayerController as Player).dispose().then((_) {
            _videoPlayerController = null;
            _isPlayerBeingDisposed = false;
          }).catchError((e) {
            debugPrint('⚠️ خطأ عند تنظيف Player: $e');
            _videoPlayerController = null;
            _isPlayerBeingDisposed = false;
          });
        } else {
          // نوع غير معروف، فقط حرر المرجع
          _videoPlayerController = null;
          _isPlayerBeingDisposed = false;
        }
      }
    } catch (e) {
      debugPrint('⚠️ خطأ أثناء تنظيف مشغل الفيديو: $e');
      _videoPlayerController = null;
      _isPlayerBeingDisposed = false;
    }
  }

  // تحسين دالة تحميل الفيديوهات والأقسام لتجنب أخطاء التجديد
  Future<void> _loadVideosAndSections() async {
    // التحقق من أن الشاشة لا تزال نشطة
    if (!_isActive || !mounted) return;

    try {
      // تحديث حالة التحميل
      if (mounted) {
        setState(() {
          _isLoading = true;
          _errorMessage = null;
        });
      }

      // حفظ الفيديو المحدد الحالي ومواقع التشغيل
      final String? currentSelectedVideoId = _selectedVideo?.id;
      final Map<String, Duration> savedPositions = Map.from(_videoPositions);

      // تفريغ المتغيرات قبل تحميل البيانات الجديدة
      _disposeVideoController();
      if (mounted) {
        setState(() {
          _selectedVideo = null;
        });
      }

      // تنفيذ طلبات API بالتوازي
      final sectionsData =
          CourseVideosService.getCourseSections(widget.course.id);
      final videosData = CourseVideosService.getCourseVideos(widget.course.id);

      // انتظار نتائج الطلبات
      final results = await Future.wait([sectionsData, videosData]);

      // التحقق مرة أخرى من أن الشاشة لا تزال نشطة
      if (!_isActive || !mounted) return;

      // تحليل النتائج
      final sections = results[0] as List<CourseSection>;
      final videos = results[1] as List<CourseVideo>;

      // ترتيب الفيديوهات حسب الترتيب (order_number)
      videos.sort((a, b) {
        // إذا كان لديهما نفس القسم، رتب حسب الترتيب
        if (a.sectionId == b.sectionId) {
          return a.orderNumber.compareTo(b.orderNumber);
        }
        // إذا كان القسم مختلف، رتب حسب القسم ثم حسب الترتيب
        if (a.sectionId != null && b.sectionId != null) {
          final sectionCompare = a.sectionId!.compareTo(b.sectionId!);
          if (sectionCompare != 0) return sectionCompare;
        }
        // رتب حسب الترتيب إذا كان القسم مختلف
        return a.orderNumber.compareTo(b.orderNumber);
      });

      // تصنيف الفيديوهات حسب القسم
      final videosBySection = <String, List<CourseVideo>>{};
      final uncategorizedVideos = <CourseVideo>[];

      // تهيئة قوائم فارغة لجميع الأقسام
      for (var section in sections) {
        videosBySection[section.id] = [];
      }

      // تصنيف الفيديوهات
      for (var video in videos) {
        if (video.sectionId != null &&
            video.sectionId!.isNotEmpty &&
            videosBySection.containsKey(video.sectionId)) {
          videosBySection[video.sectionId]!.add(video);
        } else {
          uncategorizedVideos.add(video);
        }
      }

      // ترتيب الفيديوهات داخل كل قسم حسب الترتيب (order_number)
      for (var sectionId in videosBySection.keys) {
        videosBySection[sectionId]!.sort((a, b) {
          return a.orderNumber.compareTo(b.orderNumber);
        });
      }

      // ترتيب الفيديوهات غير المصنفة حسب الترتيب (order_number)
      uncategorizedVideos.sort((a, b) {
        return a.orderNumber.compareTo(b.orderNumber);
      });

      // توسيع جميع الأقسام افتراضيًا
      final expandedSections = sections.map((s) => s.id).toSet();
      expandedSections.add('uncategorized');

      // استعادة مواقع التشغيل المحفوظة
      _videoPositions.clear();
      _videoPositions.addAll(savedPositions);

      // Count videos per section
      final Map<String, int> sectionVideoCounts = {};
      for (var video in videos) {
        if (video.sectionId != null && video.sectionId!.isNotEmpty) {
          sectionVideoCounts[video.sectionId!] =
              (sectionVideoCounts[video.sectionId!] ?? 0) + 1;
        }
      }

      // Update each section with its video count
      for (var section in sections) {
        section.videoCount = sectionVideoCounts[section.id] ?? 0;
      }

      // تحديث الحالة
      if (mounted) {
        setState(() {
          _sections = sections;
          _videos = videos;
          _videosBySection = videosBySection;
          _uncategorizedVideos = uncategorizedVideos;
          _expandedSections = expandedSections;
          _isLoading = false;

          // استعادة اختيار الفيديو السابق أو اختيار الأول
          if (videos.isNotEmpty) {
            if (currentSelectedVideoId != null) {
              final videoIndex =
                  videos.indexWhere((v) => v.id == currentSelectedVideoId);
              if (videoIndex >= 0) {
                _selectedVideo = videos[videoIndex];
              } else {
                // دائمًا اختر الفيديو الأول بدلاً من الأخير
                _selectedVideo = videos.first;
              }
            } else {
              // دائمًا اختر الفيديو الأول بدلاً من الأخير
              _selectedVideo = videos.first;
            }
          }
        });
      }
    } catch (e) {
      // معالجة الأخطاء بشكل أفضل
      debugPrint('خطأ في تحميل الفيديوهات والأقسام: $e');
      if (!_isActive || !mounted) return;

      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  // Section handling
  void _toggleSection(String sectionId) {
    setState(() {
      if (_expandedSections.contains(sectionId)) {
        _expandedSections.remove(sectionId);
      } else {
        _expandedSections.add(sectionId);
      }
    });
  }

  // Keep this implementation of _playVideoInline but make it safer
  void _playVideoInline(CourseVideo video,
      {bool resetPosition = false, bool preserveFullscreen = false}) {
    if (!_isActive || !mounted || _isRebuildPrevented) return;

    // منع تغيير الفيديو أثناء تنظيف مشغل آخر
    if (_isPlayerBeingDisposed) {
      debugPrint('⏳ انتظار انتهاء عملية تنظيف المشغل الحالي...');
      // استخدام مؤقت واحد فقط لتجنب تكرار الطلبات
      Future.delayed(const Duration(milliseconds: 300), () {
        if (_isActive && mounted && !_isRebuildPrevented) {
          _playVideoInline(video,
              resetPosition: resetPosition,
              preserveFullscreen: preserveFullscreen);
        }
      });
      return;
    }

    // تجنب إعادة تحميل نفس الفيديو الذي يتم عرضه حاليًا
    if (_selectedVideo != null &&
        _selectedVideo!.id == video.id &&
        !resetPosition) {
      debugPrint(
          '🔄 الفيديو ${video.id} قيد التشغيل بالفعل، تجاهل طلب إعادة التحميل');
      return;
    }

    // تفريغ المشغل الحالي قبل تغيير الفيديو
    // حفظ موضع التشغيل الحالي قبل تغيير الفيديو
    if (_selectedVideo != null && _selectedVideo!.id != video.id) {
      _saveCurrentPlaybackPosition();
    }

    // Save current state
    final wasFullScreen = preserveFullscreen ||
        (_videoPlayerController is ChewieController &&
            (_videoPlayerController as ChewieController).isFullScreen);

    // تفريغ المشغل الحالي قبل تغيير الفيديو
    final oldController = _videoPlayerController;
    _videoPlayerController = null;

    setState(() {
      _selectedVideo = video;
      _isDetailsExpanded = false;
      _showVideoDetails = false;
      _isNavigating = true;
      if (resetPosition) {
        _currentVideoPosition = Duration.zero;
      } else {
        _currentVideoPosition = _videoPositions[video.id] ?? Duration.zero;
      }
    });

    // Clean up old controller after state update
    _disposeVideoControllerSafely(oldController);

    // Finish navigation after a short delay
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        setState(() {
          _isNavigating = false;
        });

        // If we need to restore fullscreen state, do it after the player is initialized
        if (wasFullScreen) {
          Future.delayed(const Duration(milliseconds: 500), () {
            if (_videoPlayerController is ChewieController && mounted) {
              (_videoPlayerController as ChewieController).enterFullScreen();
            }
          });
        }
      }
    });
  }

  // Video player functions
  void _playVideo(CourseVideo video) {
    CourseVideoDialogUtils.showLoadingDialog(
        context, 'جاري التحقق من خيارات التشغيل...');
    DrmHelper.isVideoDrmProtected(video.videoId).then((isDrmProtected) {
      Navigator.of(context).pop();
      setState(() {
        _isDrmProtected = isDrmProtected;
      });

      // تحديث نوع المشغل تلقائيًا للفيديوهات المحمية إذا كان المشغل الحالي لا يدعم DRM
      if (isDrmProtected) {
        final currentOption =
            PlayerOptionsProvider.getPlayerOptionById(_selectedPlayerType);
        if (!currentOption.supportsDrm) {
          // تبديل للمشغل الافتراضي الذي يدعم DRM
          final drmPlayers = PlayerOptionsProvider.getAvailablePlayerOptions()
              .where((option) => option.supportsDrm)
              .toList();

          if (drmPlayers.isNotEmpty) {
            _changePlayerType(drmPlayers.first.id);
          }
        }
      }

      CourseVideoDialogUtils.showPlayerOptionsDialog(
          context, video, isDrmProtected);
    }).catchError((error) {
      Navigator.of(context).pop();
      CourseVideoDialogUtils.showPlayerOptionsDialog(context, video, false);
    });
  }

  // تحسين حفظ موقع التشغيل للتأكد من حفظها بشكل صحيح
  void _saveCurrentPlaybackPosition() {
    try {
      if (_selectedVideo != null) {
        Duration position = _currentVideoPosition;
        if (position.inSeconds > 0) {
          debugPrint(
              '💾 حفظ موقع التشغيل لفيديو ${_selectedVideo!.id}: ${position.inSeconds} ثانية');
          _videoPositions[_selectedVideo!.id] = position;
        }
      }
    } catch (e) {
      debugPrint('⚠️ خطأ في حفظ موقع التشغيل: $e');
    }
  }

  Duration? _getCurrentPosition() {
    try {
      if (_videoPlayerController != null) {
        if (_videoPlayerController is VideoPlayerController) {
          final videoPlayerController =
              _videoPlayerController as VideoPlayerController;
          return videoPlayerController.value.position;
        } else if (_videoPlayerController is ChewieController) {
          final chewieController = _videoPlayerController as ChewieController;
          return chewieController.videoPlayerController.value.position;
        } else if (_videoPlayerController is Player) {
          final playerController = _videoPlayerController as Player;
          // Fix for Player class - use the position property instead of getCurrentPosition
          return playerController.state.position;
        }
      }
      return _currentVideoPosition.isNegative ? null : _currentVideoPosition;
    } catch (e) {
      return null;
    }
  }

  // Navigation functions
  CourseVideo? _findPreviousVideo() {
    if (_selectedVideo == null || _videos.isEmpty) return null;

    final currentIndex = _videos.indexWhere((v) => v.id == _selectedVideo!.id);
    if (currentIndex <= 0) return null;

    return _videos[currentIndex - 1];
  }

  CourseVideo? _findNextVideo() {
    if (_selectedVideo == null || _videos.isEmpty) return null;

    final currentIndex = _videos.indexWhere((v) => v.id == _selectedVideo!.id);
    if (currentIndex == -1 || currentIndex >= _videos.length - 1) return null;

    return _videos[currentIndex + 1];
  }

  void _navigateToPreviousVideo() {
    final previousVideo = _findPreviousVideo();
    if (previousVideo != null) {
      // Save current fullscreen state before switching videos
      final wasFullScreen = _videoPlayerController is ChewieController &&
          (_videoPlayerController as ChewieController).isFullScreen;

      // Save current position
      _saveCurrentPlaybackPosition();

      // Switch videos with a small delay to allow UI to update
      Future.delayed(const Duration(milliseconds: 50), () {
        if (mounted) {
          _playVideoInline(previousVideo, preserveFullscreen: wasFullScreen);
        }
      });
    }
  }

  void _navigateToNextVideo() {
    final nextVideo = _findNextVideo();
    if (nextVideo != null) {
      // Save current fullscreen state before switching videos
      final wasFullScreen = _videoPlayerController is ChewieController &&
          (_videoPlayerController as ChewieController).isFullScreen;

      // Save current position
      _saveCurrentPlaybackPosition();

      // Switch videos with a small delay to allow UI to update
      Future.delayed(const Duration(milliseconds: 50), () {
        if (mounted) {
          _playVideoInline(nextVideo, preserveFullscreen: wasFullScreen);
        }
      });
    }
  }

  // Screen orientation and video expansion
  void _expandVideo(CourseVideo video) {
    if (_selectedVideo == null) return;

    setState(() {
      _isVideoExpanded = !_isVideoExpanded;
    });

    if (_isVideoExpanded) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
          overlays: SystemUiOverlay.values);
    }
  }

  // CRUD operations
  Future<void> _addNewVideo() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddVideoScreen(course: widget.course)),
    );
    if (result == true) {
      _loadVideosAndSections();
    }
  }

  Future<void> _editVideo(CourseVideo video) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            AddVideoScreen(course: widget.course, videoToEdit: video),
      ),
    );
    if (result == true) {
      _loadVideosAndSections();
    }
  }

  Future<void> _deleteVideo(CourseVideo video) async {
    final confirmed = await CourseVideoDialogUtils.showDeleteConfirmationDialog(
      context,
      'تأكيد الحذف',
      'هل أنت متأكد من حذف الفيديو "${video.title}"؟',
    );

    if (confirmed) {
      try {
        setState(() => _isLoading = true);
        await CourseVideosService.deleteCourseVideo(video.id, widget.course.id);
        _loadVideosAndSections();
        if (mounted) {
          CourseVideoDialogUtils.showSnackBar(
            context,
            'تم حذف الفيديو بنجاح',
            backgroundColor: Colors.green,
          );
        }
      } catch (e) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
        if (mounted) {
          CourseVideoDialogUtils.showSnackBar(
            context,
            'فشل في حذف الفيديو: $e',
            backgroundColor: Colors.red,
          );
        }
      }
    }
  }

  // File attachment handling
  Future<void> _deleteAttachment(CourseFile file) async {
    final confirmed =
        await CourseVideoDialogUtils.showFileDeleteConfirmationDialog(
      context,
      file.title,
    );

    if (confirmed) {
      try {
        setState(() => _isLoading = true);
        final String? storageFilePath = _extractFilePathFromId(file.fileId);
        if (storageFilePath != null) {
          await BunnyStorageService.deleteFile(storageFilePath);
        }
        await CourseVideosService.deleteCourseFile(file.id);
        _loadVideosAndSections();
        if (mounted) {
          CourseVideoDialogUtils.showSnackBar(
            context,
            'تم حذف الملف بنجاح من الخادم وقاعدة البيانات',
            backgroundColor: Colors.green,
          );
        }
      } catch (e) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
        if (mounted) {
          CourseVideoDialogUtils.showSnackBar(
            context,
            'فشل في حذف الملف: $e',
            backgroundColor: Colors.red,
          );
        }
      }
    }
  }

  String? _extractFilePathFromId(String fileId) {
    try {
      if (fileId.isEmpty) return null;
      if (fileId.contains('/')) return fileId;
      return fileId;
    } catch (e) {
      return null;
    }
  }

  void _openAttachment(CourseFile file) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FileViewerScreen(
          file: file,
          fileUrl: CourseVideosService.getBunnyFileUrl(file.fileId),
        ),
      ),
    );
  }

  // UI component builders using our new component classes
  Widget _buildPlayerByType({Duration startFrom = Duration.zero}) {
    // استخدم الموقع المحفوظ إذا كان المشغل قد تم تصغيره سابقاً
    Duration position = startFrom;
    // إذا كان هناك فيديو محدد، استخدم الموقع المحفوظ له
    if (_selectedVideo != null &&
        _videoPositions.containsKey(_selectedVideo!.id)) {
      position = _videoPositions[_selectedVideo!.id]!;
      debugPrint(
          '🎬 استئناف الفيديو ${_selectedVideo!.id} من الموقع: ${position.inSeconds}s');
    }

    // استخدام مفتاح ثابت لمنع إعادة الإنشاء المستمرة
    final playerKey =
        ValueKey('player_${_selectedVideo?.id ?? 'none'}_$_selectedPlayerType');

    return KeyedSubtree(
      key: playerKey,
      child: CourseVideoPlayerComponent.buildPlayerByType(
        context: context, // تمرير السياق للتأكد من وجود سياق صحيح
        selectedVideo: _selectedVideo,
        playerType: _selectedPlayerType,
        startPosition: position,
        isNavigating: _isNavigating,
        videoPositions: _videoPositions,
        findPreviousVideo: _findPreviousVideo,
        findNextVideo: _findNextVideo,
        navigateToPreviousVideo: _navigateToPreviousVideo,
        navigateToNextVideo: _navigateToNextVideo,
        onPlayerCreated: (controller) {
          if (_isActive && mounted && !_isPlayerBeingDisposed) {
            setState(() {
              _videoPlayerController = controller;
            });
          }
        },
        onPositionChanged: (position) {
          _currentVideoPosition = position;
          // عدم استدعاء setState هنا لتجنب الأخطاء
        },
      ),
    );
  }

  Widget _buildCollapsibleVideoDetails() {
    return CourseVideoDetailComponent.buildCollapsibleVideoDetails(
      selectedVideo: _selectedVideo,
      showVideoDetails: _showVideoDetails,
      onToggleDetails: (value) {
        setState(() {
          _showVideoDetails = value;
        });
        // لا نقوم بأي تمرير تلقائي عند تبديل حالة التفاصيل
      },
      onPlayVideo: _playVideo,
      onEditVideo: _editVideo,
      onDeleteVideo: _deleteVideo,
      onOpenAttachment: _openAttachment,
      onDeleteAttachment: _deleteAttachment,
    );
  }

  Widget _buildEmbeddedPlayer() {
    if (_selectedVideo == null) return const SizedBox.shrink();

    // التحقق من وجود فيديو سابق/تالي
    final hasPrevious = _findPreviousVideo() != null;
    final hasNext = _findNextVideo() != null;

    if (_isVideoExpanded) {
      return Container(
        color: Colors.black,
        child: Stack(
          children: [
            _buildPlayerByType(startFrom: _currentVideoPosition),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // مشغل الفيديو (يظل ظاهراً دائماً)
        Stack(
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Container(
                key: _playerKey,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(12),
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  children: [
                    _buildPlayerByType(startFrom: _currentVideoPosition),
                    if (_isPlayerLoading)
                      const Center(
                          child:
                              CircularProgressIndicator(color: Colors.white)),
                  ],
                ),
              ),
            ),
          ],
        ),

        // تفاصيل الفيديو (تظهر فقط إذا كان _isDetailsVisible هو true)
        if (_isDetailsVisible) _buildCollapsibleVideoDetails(),
      ],
    );
  }

  double _calculateProgressPercentage() {
    if (_selectedVideo == null) return 0.0;
    final currentSeconds = _currentVideoPosition.inSeconds;
    final totalSeconds = _selectedVideo!.duration;
    if (totalSeconds <= 0) return 0.0;

    final progress = currentSeconds / totalSeconds;
    return progress.clamp(0.0, 1.0);
  }

  // إضافة دالة لتحميل تفضيل المشغل المخزن
  Future<void> _loadPlayerPreference() async {
    final savedType = await PlayerPreferencesService.getPlayerType();
    setState(() {
      _selectedPlayerType = savedType;
    });
  }

  // تحسين دالة تغيير المشغل لمنع الأخطاء أثناء التحديث
  Future<void> _changePlayerType(String playerType) async {
    if (!mounted || _isPlayerBeingDisposed || _isRebuildPrevented) return;
    // منع تغيير المشغل إذا كان هو نفس النوع المختار حالياً
    if (_selectedPlayerType == playerType) return;

    debugPrint('🔄 تغيير نوع المشغل من $_selectedPlayerType إلى $playerType');

    // استخدم حارس بوابة للتأكد من أن تغيير واحد فقط يحدث في وقت واحد
    if (_isPlayerBeingDisposed) {
      debugPrint('⏳ انتظار انتهاء عملية التنظيف الحالية...');
      return;
    }

    // حفظ موضع التشغيل الحالي قبل تغيير المشغل
    _saveCurrentPlaybackPosition();

    // تنظيف المشغل الحالي
    final oldController = _videoPlayerController;
    _videoPlayerController = null;

    if (mounted && !_isRebuildPrevented) {
      setState(() {
        _selectedPlayerType = playerType;
      });
    }

    // حفظ تفضيل المشغل
    await PlayerPreferencesService.savePlayerType(playerType);

    // تنظيف المشغل السابق بعد تغيير النوع بتأخير
    Future.delayed(const Duration(milliseconds: 300), () {
      // إضافة الفحص هنا
      if (!_isActive || !mounted) return;
      try {
        if (oldController != null) {
          if (oldController is VideoPlayerController) {
            oldController.pause().then((_) {
              oldController.dispose();
            }).catchError((e) {
              debugPrint('⚠️ خطأ في تنظيف المشغل السابق: $e');
            });
          } else if (oldController is Player) {
            oldController.dispose().catchError((e) {
              debugPrint('⚠️ خطأ في تنظيف المشغل السابق: $e');
            });
          }
        }
      } catch (e) {
        debugPrint('⚠️ خطأ في تنظيف المشغل السابق: $e');
      }
    });
  }

  // تحسين زر التحديث لتجنب الأخطاء
  Future<void> _refreshVideos() async {
    if (_isLoading || !_isActive || !mounted || _isPlayerBeingDisposed) return;

    // حفظ موضع التشغيل الحالي
    _saveCurrentPlaybackPosition();

    // تنظيف المشغل الحالي قبل التحديث
    _disposeVideoController();
    if (mounted) {
      setState(() {
        _videoPlayerController = null;
        _selectedVideo = null;
        _isLoading = true;
      });
    }

    // انتظار تنظيف الواجهة
    await Future.delayed(const Duration(milliseconds: 150));

    // بدء تحميل البيانات الجديدة
    await _loadVideosAndSections();
  }

  // Helper method for safely disposing controllers
  void _disposeVideoControllerSafely(dynamic controller) {
    if (controller == null) return;
    Future.delayed(const Duration(milliseconds: 100), () {
      try {
        if (controller is VideoPlayerController) {
          controller.pause().then((_) {
            controller.dispose();
          }).catchError((e) {
            debugPrint('⚠️ Error disposing VideoPlayerController: $e');
          });
        } else if (controller is ChewieController) {
          controller.dispose();
        } else if (controller is Player) {
          controller.dispose().catchError((e) {
            debugPrint('⚠️ Error disposing Player: $e');
          });
        }
      } catch (e) {
        debugPrint('⚠️ Error disposing controller: $e');
      }
    });
  }

  // إضافة دالة إعادة ترتيب الفيديوهات
  Future<void> _handleReorderVideo(
      CourseVideo video, int newIndex, String? sectionId) async {
    try {
      // تحديد القائمة المستهدفة
      List<CourseVideo> targetList;
      if (sectionId != null) {
        targetList = _videosBySection[sectionId] ?? [];
      } else {
        targetList = _uncategorizedVideos;
      }

      // حساب الترتيب الجديد
      int newOrderNumber;
      if (newIndex == 0) {
        // إذا كان في بداية القائمة
        newOrderNumber =
            targetList.isEmpty ? 1 : targetList.first.orderNumber - 1;
        // منع الأرقام السالبة
        newOrderNumber = newOrderNumber <= 0 ? 1 : newOrderNumber;
      } else if (newIndex >= targetList.length) {
        // إذا كان في نهاية القائمة
        newOrderNumber =
            targetList.isEmpty ? 1 : targetList.last.orderNumber + 1;
      } else {
        // إذا كان في وسط القائمة
        if (newIndex + 1 < targetList.length) {
          newOrderNumber = (targetList[newIndex].orderNumber +
                  targetList[newIndex + 1].orderNumber) ~/
              2;
        } else {
          newOrderNumber = targetList[newIndex].orderNumber + 1;
        }
      }

      setState(() {
        _isLoading = true;
      });

      // تحديث الترتيب في قاعدة البيانات
      await CourseVideosService.updateVideoOrder(
          video.id, newOrderNumber, sectionId);

      // إعادة تحميل البيانات
      await _loadVideosAndSections();
    } catch (e) {
      debugPrint('خطأ في إعادة ترتيب الفيديو: $e');
      if (mounted) {
        // إظهار رسالة خطأ للمستخدم
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء إعادة ترتيب الفيديو: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // استخدام مفتاح فريد لكل بناء للشاشة - لمنع مشكلة المفاتيح المكررة
    final screenKey = UniqueKey();

    // Handle fullscreen mode
    if (_isVideoExpanded && _selectedVideo != null) {
      return WillPopScope(
        onWillPop: () async {
          if (_isVideoExpanded) {
            _expandVideo(_selectedVideo!);
            return false;
          }
          return true;
        },
        child: Scaffold(
          backgroundColor: Colors.black,
          body: _buildEmbeddedPlayer(),
        ),
      );
    }

    // Main UI
    return Scaffold(
      key: screenKey,
      backgroundColor: Colors.white,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.primaryLight, Colors.white, Colors.white],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  // تحديث زر التحديث لاستخدام الدالة المحسنة
                  CourseVideoHeader(
                    title: widget.course.title,
                    onBack: () => Navigator.of(context).pop(),
                    onRefresh: _refreshVideos, // استخدام الدالة المحسنة
                    selectedPlayerId: _selectedPlayerType,
                    onPlayerChanged: _changePlayerType,
                    isDrmProtected: _isDrmProtected,
                  ),

                  // Embedded player - يظل دائماً مرئياً في الأعلى
                  if (!_isLoading &&
                      _errorMessage == null &&
                      _selectedVideo != null)
                    Builder(
                      builder: (context) => Padding(
                        padding: const EdgeInsets.fromLTRB(
                            16, 8, 16, 0), // تقليل الهامش السفلي
                        child: _buildEmbeddedPlayer(),
                      ),
                    ),

                  // زر الاستمرار في تصفح القائمة (يظهر فقط عندما تكون التفاصيل مخفية)
                  if (!_isLoading &&
                      _errorMessage == null &&
                      _selectedVideo != null &&
                      !_isDetailsVisible)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 2, horizontal: 16),
                      child: Row(
                        children: [
                          Text(
                            'اختر فيديو آخر:',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _isDetailsVisible = true;
                              });
                              // حذف كود التمرير التلقائي للأعلى هنا أيضاً
                            },
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 0),
                              minimumSize: const Size(0, 24),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text('عرض التفاصيل'),
                          ),
                        ],
                      ),
                    ),

                  // Video list
                  Expanded(
                    child: _isLoading
                        ? const Center(child: CustomProgressIndicator())
                        : _errorMessage != null
                            ? CourseVideoUIUtils.buildErrorState(
                                _errorMessage, _loadVideosAndSections)
                            : CourseVideoListComponent.buildVideosList(
                                videos: _videos,
                                sections: _sections,
                                videosBySection: _videosBySection,
                                uncategorizedVideos: _uncategorizedVideos,
                                expandedSections: _expandedSections,
                                scrollController: _scrollController,
                                selectedVideo: _selectedVideo,
                                onToggleSection: _toggleSection,
                                onPlayVideoInline: _playVideoInline,
                                onAddNewVideo: _addNewVideo,
                                onPlayVideo: _playVideo,
                                videoPositions: _videoPositions,
                                onReorderVideo:
                                    _handleReorderVideo, // إضافة معالج إعادة الترتيب
                              ),
                  ),
                ],
              ),

              // إزالة المشغل المصغر العائم لأنه لم يعد مطلوباً
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addNewVideo,
        backgroundColor: const Color.fromRGBO(0, 128, 255, 0.7),
        foregroundColor: Colors.white,
        child: const Icon(Icons.add, size: 22),
      ),
    );
  }
}
