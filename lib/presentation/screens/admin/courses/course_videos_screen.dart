import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:mycourses/core/constants/app_colors.dart';
import 'package:mycourses/core/providers/player_options_provider.dart';
import 'package:mycourses/core/services/bunny_storage_service.dart';
import 'package:mycourses/core/services/course_videos_service.dart';
import 'package:mycourses/core/services/player_preferences_service.dart';
import 'package:mycourses/core/utils/drm_helper.dart';
import 'package:mycourses/core/utils/logging_utils.dart';
import 'package:mycourses/core/utils/performance_optimizer.dart';
import 'package:mycourses/models/course.dart';
import 'package:mycourses/models/course_section.dart';
import 'package:mycourses/models/course_video.dart';
import 'package:mycourses/presentation/screens/admin/courses/add_video_screen.dart';
import 'package:mycourses/presentation/screens/admin/courses/components/course_video_detail_component.dart';
import 'package:mycourses/presentation/screens/admin/courses/components/course_video_dialog_utils.dart';
import 'package:mycourses/presentation/screens/admin/courses/components/course_video_list_component.dart';
import 'package:mycourses/presentation/screens/admin/courses/components/course_video_player_component.dart';
import 'package:mycourses/presentation/screens/admin/courses/components/course_video_ui_utils.dart';
import 'package:mycourses/presentation/screens/admin/courses/file_viewer_screen.dart';
import 'package:mycourses/presentation/widgets/course_video_navigation_buttons.dart';
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
  final bool _isDetailsExpanded = false;

  // UI state variables
  final ScrollController _mainScrollController = ScrollController();
  final Map<String, double> _scrollPositions = {};
  String _selectedPlayerType = 'iframe';
  bool _isDrmProtected = false;
  final bool _isPlayerLoading = false;
  final GlobalKey _playerKey = GlobalKey();
  bool _isVideoExpanded = false;
  final ValueNotifier<bool> _videoDetailsNotifier = ValueNotifier<bool>(false);

  // Playback state variables
  Duration _currentVideoPosition = Duration.zero;
  dynamic _videoPlayerController;
  final Map<String, Duration> _videoPlaybackPositions = {};
  bool _isNavigating = false;

  bool _isActive = true;
  bool _isPlayerBeingDisposed = false;
  bool _isRebuildPrevented = false;

  final ValueNotifier<bool> _sectionExpandStateNotifier =
      ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();
    _isActive = true;

    WidgetsBinding.instance.addObserver(this);

    _initScrollController();

    _loadVideosAndSections();
    _loadPlayerPreference();
  }

  void _initScrollController() {
    _mainScrollController.addListener(() {
      if (!_mainScrollController.hasClients) return;
      if (_selectedVideo != null) {
        _checkVideoVisibility(_selectedVideo!);
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _saveCurrentPlaybackPosition();

      if (_videoPlayerController != null) {
        _disposeVideoController();
      }
    }

    if (state == AppLifecycleState.paused) {
      _isRebuildPrevented = true;
    } else if (state == AppLifecycleState.resumed) {
      _isRebuildPrevented = false;
      if (mounted && _selectedVideo != null) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            _refreshPlayerIfNeeded();
          }
        });
      }
    }
  }

  void _refreshPlayerIfNeeded() {
    if (_isPlayerBeingDisposed || !mounted || _selectedVideo == null) return;

    // Only refresh iframe players as they cause most issues
    if (_selectedPlayerType == 'iframe' && _videoPlayerController != null) {
      _saveCurrentPlaybackPosition();
      _disposeVideoController();

      setState(() {
        _videoPlayerController = null;
      });
    }
  }

  @override
  void dispose() {
    _isActive = false;

    WidgetsBinding.instance.removeObserver(this);

    try {
      _mainScrollController.dispose();

      _disposeVideoController();

      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
          overlays: SystemUiOverlay.values);
    } catch (e) {
      debugPrint('خطأ أثناء تنظيف الموارد: $e');
    }
    _videoDetailsNotifier.dispose();
    super.dispose();
  }

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
          try {
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

  Future<void> _loadVideosAndSections() async {
    _scrollPositions.clear();
    debugPrint('📚 Loading videos and sections...');

    if (!_isActive || !mounted) {
      debugPrint('⚠️ Component not active or mounted');
      return;
    }

    try {
      final String? currentVideoId = _selectedVideo?.id;
      debugPrint('💾 Current selected video ID: $currentVideoId');

      if (mounted) {
        setState(() {
          _isLoading = true;
          _errorMessage = null;
        });
      }

      final Map<String, Duration> savedPositions =
          Map.from(_videoPlaybackPositions);

      _disposeVideoController();
      if (mounted) {
        setState(() {
          _selectedVideo = null;
        });
      }

      final sectionsData =
          CourseVideosService.getCourseSections(widget.course.id);
      final videosData = CourseVideosService.getCourseVideos(widget.course.id);

      final results = await Future.wait([sectionsData, videosData]);

      if (!_isActive || !mounted) return;

      final sections = results[0] as List<CourseSection>;
      final videos = results[1] as List<CourseVideo>;

      sections.sort((a, b) => a.orderNumber.compareTo(b.orderNumber));

      videos.sort((a, b) {
        if (a.sectionId == b.sectionId) {
          return a.orderNumber.compareTo(b.orderNumber);
        }

        if (a.sectionId != null && b.sectionId != null) {
          int sectionOrderA = sections
              .firstWhere((s) => s.id == a.sectionId,
                  orElse: () => CourseSection(
                      id: '',
                      courseId: '',
                      title: '',
                      orderNumber: 999,
                      isPublished: true,
                      createdAt: DateTime.now(),
                      updatedAt: DateTime.now()))
              .orderNumber;

          int sectionOrderB = sections
              .firstWhere((s) => s.id == b.sectionId,
                  orElse: () => CourseSection(
                      id: '',
                      courseId: '',
                      title: '',
                      orderNumber: 999,
                      isPublished: true,
                      createdAt: DateTime.now(),
                      updatedAt: DateTime.now()))
              .orderNumber;

          if (sectionOrderA != sectionOrderB) {
            return sectionOrderA.compareTo(sectionOrderB);
          }
        }

        if (a.sectionId == null && b.sectionId != null) {
          return 1;
        }
        if (a.sectionId != null && b.sectionId == null) {
          return -1;
        }

        return a.orderNumber.compareTo(b.orderNumber);
      });

      final videosBySection = <String, List<CourseVideo>>{};
      final uncategorizedVideos = <CourseVideo>[];

      for (var section in sections) {
        videosBySection[section.id] = [];
      }

      for (var video in videos) {
        if (video.sectionId != null &&
            video.sectionId!.isNotEmpty &&
            videosBySection.containsKey(video.sectionId)) {
          videosBySection[video.sectionId]!.add(video);
        } else {
          uncategorizedVideos.add(video);
        }
      }

      for (var sectionId in videosBySection.keys) {
        videosBySection[sectionId]!.sort((a, b) {
          return a.orderNumber.compareTo(b.orderNumber);
        });
      }

      uncategorizedVideos.sort((a, b) {
        return a.orderNumber.compareTo(b.orderNumber);
      });

      final expandedSections = sections.map((s) => s.id).toSet();
      expandedSections.add('uncategorized');

      _videoPlaybackPositions.clear();
      _videoPlaybackPositions.addAll(savedPositions);

      final Map<String, int> sectionVideoCounts = {};
      for (var video in videos) {
        if (video.sectionId != null && video.sectionId!.isNotEmpty) {
          sectionVideoCounts[video.sectionId!] =
              (sectionVideoCounts[video.sectionId!] ?? 0) + 1;
        }
      }

      for (var section in sections) {
        section.videoCount = sectionVideoCounts[section.id] ?? 0;
      }

      final allVideosOrdered = <CourseVideo>[];

      for (var section in sections) {
        final sectionVideos = videosBySection[section.id] ?? [];
        allVideosOrdered.addAll(sectionVideos);
      }

      allVideosOrdered.addAll(uncategorizedVideos);

      if (mounted) {
        debugPrint('🔄 Updating state with loaded data');
        debugPrint('   - Videos count: ${allVideosOrdered.length}');
        debugPrint('   - Sections count: ${sections.length}');

        setState(() {
          _sections = sections;
          _videos = allVideosOrdered;
          _videosBySection = videosBySection;
          _uncategorizedVideos = uncategorizedVideos;
          _expandedSections = expandedSections;
          _isLoading = false;

          if (allVideosOrdered.isNotEmpty) {
            if (currentVideoId != null) {
              final videoIndex =
                  allVideosOrdered.indexWhere((v) => v.id == currentVideoId);
              debugPrint('🎯 Found previous video at index: $videoIndex');
              if (videoIndex >= 0) {
                _selectedVideo = allVideosOrdered[videoIndex];
              } else {
                _selectedVideo = allVideosOrdered.first;
              }
            } else {
              _selectedVideo = allVideosOrdered.first;
            }
            debugPrint('✅ Selected video set to: ${_selectedVideo?.title}');
          }
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading data: $e');
      if (!_isActive || !mounted) return;

      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  void _toggleSection(String sectionId) {
    _expandedSections = Set<String>.from(_expandedSections);

    if (_expandedSections.contains(sectionId)) {
      _expandedSections.remove(sectionId);
    } else {
      _expandedSections.add(sectionId);
    }

    _sectionExpandStateNotifier.value = !_sectionExpandStateNotifier.value;
  }

  void _playVideoInline(CourseVideo video,
      {bool resetPosition = false, bool preserveFullscreen = false}) {
    debugPrint(
        '🎥 _playVideoInline called for video: ${video.title} (${video.id})');

    if (!_isActive || !mounted || _isRebuildPrevented) {
      debugPrint(
          '⚠️ Early return: isActive=$_isActive, mounted=$mounted, isRebuildPrevented=$_isRebuildPrevented');
      return;
    }

    // منع التحميل المتكرر للفيديو نفسه
    if (_selectedVideo?.id == video.id && !resetPosition) {
      debugPrint('🔄 Same video selected, only scrolling to position');
      _scrollToSelectedVideo(video);
      return;
    }

    if (_isPlayerBeingDisposed) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (_isActive && mounted && !_isRebuildPrevented) {
          _playVideoInline(video,
              resetPosition: resetPosition,
              preserveFullscreen: preserveFullscreen);
        }
      });
      return;
    }

    if (_selectedVideo != null) {
      _saveCurrentPlaybackPosition();
    }

    final wasFullScreen = preserveFullscreen ||
        (_videoPlayerController is ChewieController &&
            (_videoPlayerController as ChewieController).isFullScreen);

    debugPrint(
        '📍 Current scroll position: ${_mainScrollController.position.pixels}');

    setState(() {
      debugPrint('🔄 Updating state: selectedVideo=${video.title}');
      _selectedVideo = video;
      _videoDetailsNotifier.value = false;
      _isNavigating = true;
      _currentVideoPosition = resetPosition
          ? Duration.zero
          : (_videoPlaybackPositions[video.id] ?? Duration.zero);
    });

    // تأخير قصير قبل التمرير للسماح للواجهة بالتحديث
    Future.delayed(const Duration(milliseconds: 50), () {
      _scrollToSelectedVideo(video);
    });

    final oldController = _videoPlayerController;

    _disposeVideoControllerSafely(oldController);
    _videoPlayerController = null;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      setState(() {
        _isNavigating = false;
      });

      if (wasFullScreen) {
        Future.delayed(const Duration(milliseconds: 300), () {
          if (_videoPlayerController is ChewieController && mounted) {
            (_videoPlayerController as ChewieController).enterFullScreen();
          }
        });
      }
    });
  }

  void _scrollToSelectedVideo(CourseVideo video) {
    if (!mounted || !_mainScrollController.hasClients) return;

    debugPrint('📜 Attempting to scroll to video: ${video.title}');

    try {
      // First try using cached position
      final cachedPosition = _scrollPositions[video.id];
      if (cachedPosition != null) {
        _mainScrollController.animateTo(
          cachedPosition,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutCubic,
        );
        return;
      }

      // If no cached position, calculate from widget
      SchedulerBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;

        final videoKey = GlobalObjectKey('video_item_${video.id}');
        final videoContext = videoKey.currentContext;

        if (videoContext == null) {
          debugPrint('⚠️ Video context not found, retrying in 300ms');
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) _scrollToSelectedVideo(video);
          });
          return;
        }

        final box = videoContext.findRenderObject() as RenderBox;
        final position = box.localToGlobal(Offset.zero);

        final viewportHeight = MediaQuery.of(context).size.height;
        final videoHeight = box.size.height;

        double targetPosition =
            position.dy - (viewportHeight - videoHeight) / 3;
        targetPosition = targetPosition.clamp(
            0.0, _mainScrollController.position.maxScrollExtent);

        // Cache the calculated position
        _scrollPositions[video.id] = targetPosition;

        if (mounted) {
          await _mainScrollController.animateTo(
            targetPosition,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOutCubic,
          );
        }
      });
    } catch (e) {
      debugPrint('❌ Error during scroll calculation: $e');
    }
  }

  void _checkVideoVisibility(CourseVideo video) {
    if (!mounted || !_mainScrollController.hasClients) return;

    try {
      final videoKey = GlobalObjectKey('video_item_${video.id}');
      final videoContext = videoKey.currentContext;

      if (videoContext != null) {
        final box = videoContext.findRenderObject() as RenderBox;
        final position = box.localToGlobal(Offset.zero);

        final viewportHeight = MediaQuery.of(context).size.height;
        if (position.dy < 0 || position.dy > viewportHeight) {
          _scrollToSelectedVideo(video);
        }
      }
    } catch (e) {
      debugPrint('❌ Error checking visibility: $e');
    }
  }

  void _playVideo(CourseVideo video) {
    CourseVideoDialogUtils.showLoadingDialog(
        context, 'جاري التحقق من خيارات التشغيل...');
    DrmHelper.isVideoDrmProtected(video.videoId).then((isDrmProtected) {
      Navigator.of(context).pop();
      setState(() {
        _isDrmProtected = isDrmProtected;
      });

      if (isDrmProtected) {
        final currentOption =
            PlayerOptionsProvider.getPlayerOptionById(_selectedPlayerType);
        if (!currentOption.supportsDrm) {
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

  void _saveCurrentPlaybackPosition() {
    try {
      if (_selectedVideo != null) {
        Duration position = _currentVideoPosition;
        if (position.inSeconds > 0) {
          debugPrint(
              '💾 حفظ موقع التشغيل لفيديو ${_selectedVideo!.id}: ${position.inSeconds} ثانية');
          _videoPlaybackPositions[_selectedVideo!.id] = position;
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
          return playerController.state.position;
        }
      }
      return _currentVideoPosition.isNegative ? null : _currentVideoPosition;
    } catch (e) {
      return null;
    }
  }

  CourseVideo? _findPreviousVideo() {
    if (_selectedVideo == null || _videos.isEmpty) return null;

    final currentIndex = _videos.indexWhere((v) => v.id == _selectedVideo!.id);
    if (currentIndex <= 0) return null;

    return _videos[currentIndex - 1];
  }

  CourseVideo? _findNextVideo() {
    if (_selectedVideo == null || _videos.isEmpty) return null;

    final currentIndex = _videos.indexWhere((v) => v.id == _selectedVideo!.id);

    if (currentIndex < 0 || currentIndex >= _videos.length - 1) return null;

    return _videos[currentIndex + 1];
  }

  void _navigateToPreviousVideo() {
    final previousVideo = _findPreviousVideo();
    if (previousVideo != null) {
      final wasFullScreen = _videoPlayerController is ChewieController &&
          (_videoPlayerController as ChewieController).isFullScreen;

      _saveCurrentPlaybackPosition();
      _playVideoInline(previousVideo, preserveFullscreen: wasFullScreen);
    }
  }

  void _navigateToNextVideo() {
    final nextVideo = _findNextVideo();
    if (nextVideo != null) {
      final wasFullScreen = _videoPlayerController is ChewieController &&
          (_videoPlayerController as ChewieController).isFullScreen;

      _saveCurrentPlaybackPosition();
      _playVideoInline(nextVideo, preserveFullscreen: wasFullScreen);
    }
  }

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

  Widget _buildPlayerByType({Duration startFrom = Duration.zero}) {
    Duration position = startFrom;
    if (_selectedVideo != null &&
        _videoPlaybackPositions.containsKey(_selectedVideo!.id)) {
      position = _videoPlaybackPositions[_selectedVideo!.id]!;
      debugPrint(
          '🎬 استئناف الفيديو ${_selectedVideo!.id} من الموقع: ${position.inSeconds}s');
    }

    return CourseVideoPlayerComponent.buildPlayerByType(
      context: context,
      selectedVideo: _selectedVideo,
      playerType: _selectedPlayerType,
      startPosition: position,
      isNavigating: _isNavigating,
      videoPositions: _videoPlaybackPositions,
      findPreviousVideo: _findPreviousVideo,
      findNextVideo: _findNextVideo,
      navigateToPreviousVideo: _navigateToPreviousVideo,
      navigateToNextVideo: _navigateToNextVideo,
      onPlayerCreated: (controller) {
        if (_isActive &&
            mounted &&
            !_isPlayerBeingDisposed &&
            _videoPlayerController != controller) {
          setState(() {
            _videoPlayerController = controller;
          });
        }
      },
      onPositionChanged: (position) {
        if ((_currentVideoPosition.inSeconds - position.inSeconds).abs() > 1) {
          _currentVideoPosition = position;
        }
      },
    );
  }

  Widget _buildEmbeddedPlayer() {
    if (_selectedVideo == null) return const SizedBox.shrink();

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

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RepaintBoundary(
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(13),
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
          ),
          _buildVideoHeader(),
          ValueListenableBuilder<bool>(
            valueListenable: _videoDetailsNotifier,
            builder: (context, isExpanded, _) {
              return AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: isExpanded
                    ? CourseVideoDetailComponent.buildCollapsibleVideoDetails(
                        key: ValueKey<String>('details_${_selectedVideo!.id}'),
                        selectedVideo: _selectedVideo,
                        showVideoDetails: true,
                        onToggleDetails: (_) {},
                        onPlayVideo: _playVideo,
                        onEditVideo: _editVideo,
                        onDeleteVideo: _deleteVideo,
                        onOpenAttachment: _openAttachment,
                        onDeleteAttachment: _deleteAttachment,
                      )
                    : const SizedBox.shrink(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildVideoHeader() {
    return ValueListenableBuilder<bool>(
      valueListenable: _videoDetailsNotifier,
      builder: (context, isExpanded, _) {
        return InkWell(
          onTap: _handleToggleDetails,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
            child: Row(
              children: [
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: AppColors.buttonPrimary,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      _selectedVideo!.orderNumber.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _selectedVideo!.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      color: AppColors.buttonPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.buttonPrimary.withOpacity(0.15),
                      width: 0.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 8,
                        color: AppColors.buttonPrimary.withOpacity(0.7),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        _selectedVideo!.formattedDuration,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 8,
                          color: AppColors.buttonPrimary.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: isExpanded
                        ? AppColors.buttonSecondary.withOpacity(0.1)
                        : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.buttonSecondary.withOpacity(0.2),
                      width: 0.5,
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      isExpanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      color: AppColors.buttonSecondary,
                      size: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _handleToggleDetails() {
    _videoDetailsNotifier.value = !_videoDetailsNotifier.value;
  }

  Future<void> _loadPlayerPreference() async {
    final savedType = await PlayerPreferencesService.getPlayerType();
    setState(() {
      _selectedPlayerType = savedType;
    });
  }

  Future<void> _changePlayerType(String playerType) async {
    if (!mounted || _isPlayerBeingDisposed || _isRebuildPrevented) return;
    if (_selectedPlayerType == playerType) return;

    debugPrint('🔄 تغيير نوع المشغل من $_selectedPlayerType إلى $playerType');

    if (_isPlayerBeingDisposed) {
      debugPrint('⏳ انتظار انتهاء عملية التنظيف الحالية...');
      return;
    }

    _saveCurrentPlaybackPosition();

    final oldController = _videoPlayerController;
    _videoPlayerController = null;

    if (mounted && !_isRebuildPrevented) {
      setState(() {
        _selectedPlayerType = playerType;
      });
    }

    await PlayerPreferencesService.savePlayerType(playerType);

    Future.delayed(const Duration(milliseconds: 300), () {
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

  /// تحديث قائمة الفيديوهات مع الحفاظ على حالة التشغيل الحالية
  Future<void> _refreshVideos() async {
    debugPrint('🔄 بدء تحديث قائمة الفيديوهات...');

    if (_isLoading || !_isActive || !mounted || _isPlayerBeingDisposed) {
      debugPrint(
          '⚠️ لا يمكن التحديث: isLoading=$_isLoading, isActive=$_isActive, mounted=$mounted');
      return;
    }

    // حفظ موقع التشغيل الحالي قبل التحديث
    _saveCurrentPlaybackPosition();
    final String? currentVideoId = _selectedVideo?.id;
    debugPrint('💾 تم حفظ موقع التشغيل للفيديو: $currentVideoId');

    // تنظيف المشغل الحالي
    _disposeVideoController();

    if (mounted) {
      setState(() {
        _videoPlayerController = null;
        _selectedVideo = null;
        _isLoading = true;
      });
    }

    // تأخير بسيط للسماح بتنظيف الموارد
    await Future.delayed(const Duration(milliseconds: 150));

    // إعادة تحميل البيانات
    await _loadVideosAndSections();

    // التأكد من عدم فقدان موقع التمرير
    if (currentVideoId != null && mounted) {
      debugPrint('🎯 محاولة العودة للفيديو السابق: $currentVideoId');
      final videoIndex = _videos.indexWhere((v) => v.id == currentVideoId);
      if (videoIndex >= 0) {
        debugPrint('✅ تم العثور على الفيديو السابق في الموقع: $videoIndex');
        _scrollToSelectedVideo(_videos[videoIndex]);
      }
    }
  }

  /// التنظيف الآمن لمشغل الفيديو
  void _disposeVideoControllerSafely(dynamic controller) {
    debugPrint('🧹 تنظيف آمن لمشغل الفيديو: ${controller.runtimeType}');

    if (controller == null) return;

    Future.delayed(const Duration(milliseconds: 100), () {
      try {
        if (controller is VideoPlayerController) {
          controller.pause().then((_) {
            controller.dispose();
            debugPrint('✅ تم تنظيف VideoPlayerController');
          }).catchError((e) {
            debugPrint('⚠️ خطأ في تنظيف VideoPlayerController: $e');
          });
        } else if (controller is ChewieController) {
          controller.dispose();
          debugPrint('✅ تم تنظيف ChewieController');
        } else if (controller is Player) {
          controller.dispose().catchError((e) {
            debugPrint('⚠️ خطأ في تنظيف Player: $e');
          });
        }
      } catch (e) {
        debugPrint('⚠️ خطأ في تنظيف المشغل: $e');
      }
    });
  }

  Future<void> _handleReorderVideo(
      CourseVideo video, int newIndex, String? sectionId) async {
    DialogRoute? loadingDialog;

    try {
      loadingDialog = DialogRoute<void>(
        context: context,
        builder: (context) => AlertDialog(
          content: SizedBox(
            width: 300,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: AppColors.buttonPrimary),
                const SizedBox(width: 20),
                const Flexible(
                  child: Text('جاري إعادة ترتيب الفيديوهات...'),
                ),
              ],
            ),
          ),
        ),
      );

      Navigator.of(context).push(loadingDialog);

      LoggingUtils.debugLog('🔄 Processing video reorder request:');
      LoggingUtils.debugLog('  - Video: ${video.title} (${video.id})');
      LoggingUtils.debugLog(
          '  - From Section: ${video.sectionId ?? "uncategorized"}');
      LoggingUtils.debugLog('  - To Section: ${sectionId ?? "uncategorized"}');
      LoggingUtils.debugLog('  - To Position: $newIndex');

      await PerformanceOptimizer.withTimeout(
        PerformanceOptimizer.debounce(
          () => CourseVideosService.updateVideoOrder(
              video.id, newIndex, sectionId),
          key:
              'reorder_video_${video.id}_${DateTime.now().millisecondsSinceEpoch}',
          duration: const Duration(milliseconds: 300),
        ),
        const Duration(seconds: 8),
        'video_reorder',
      );

      _dismissLoadingDialog(loadingDialog);
      loadingDialog = null;

      final String? currentVideoId = _selectedVideo?.id;

      await _loadVideosAndSections();

      if (mounted &&
          currentVideoId != null &&
          _videos.any((v) => v.id == currentVideoId)) {
        setState(() {
          _selectedVideo = _videos.firstWhere((v) => v.id == currentVideoId);
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تحديث ترتيب الفيديوهات بنجاح'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      LoggingUtils.debugLog('❌ خطأ في إعادة ترتيب الفيديو: $e');

      if (loadingDialog != null) {
        _dismissLoadingDialog(loadingDialog);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء إعادة ترتيب الفيديو: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleSectionReorder(
      CourseSection section, int newIndex) async {
    DialogRoute? loadingDialog;

    try {
      loadingDialog = DialogRoute<void>(
        context: context,
        builder: (context) => AlertDialog(
          content: SizedBox(
            width: 300,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: AppColors.buttonPrimary),
                SizedBox(width: 20),
                Flexible(
                  child: Text('جاري إعادة ترتيب الأقسام...'),
                ),
              ],
            ),
          ),
        ),
      );

      Navigator.of(context).push(loadingDialog);

      LoggingUtils.debugLog(
          '🔄 بدء إعادة ترتيب القسم: ${section.title} إلى الموضع: ${newIndex + 1}');

      final uniqueKey =
          'section_reorder_${section.id}_${DateTime.now().millisecondsSinceEpoch}';

      final shouldProceed = await PerformanceOptimizer.withTimeout(
        PerformanceOptimizer.throttle(
          () async {
            try {
              await CourseVideosService.updateSectionOrder(
                  section.id, newIndex + 1);
            } catch (e) {
              LoggingUtils.debugLog('❌ خطأ داخلي في إعادة ترتيب القسم: $e');
              rethrow;
            }
          },
          key: uniqueKey,
          duration: const Duration(milliseconds: 500),
        ),
        const Duration(seconds: 10),
        'section_reorder',
        fallbackValue: true,
      );

      _dismissLoadingDialog(loadingDialog);
      loadingDialog = null;

      if (!shouldProceed) return;

      final String? selectedVideoId = _selectedVideo?.id;

      await _loadVideosAndSections();

      if (selectedVideoId != null && mounted) {
        final int videoIndex =
            _videos.indexWhere((v) => v.id == selectedVideoId);
        if (videoIndex >= 0) {
          setState(() {
            _selectedVideo = _videos[videoIndex];
          });
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تحديث ترتيب الأقسام والفيديوهات بنجاح'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      LoggingUtils.debugLog('❌ خطأ في إعادة ترتيب الأقسام: $e');

      if (loadingDialog != null) {
        _dismissLoadingDialog(loadingDialog);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء إعادة ترتيب الأقسام: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _dismissLoadingDialog(DialogRoute? dialog) {
    if (dialog != null && mounted) {
      try {
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).removeRoute(dialog);
        }
      } catch (e) {
        LoggingUtils.debugLog('⚠️ Error dismissing dialog: $e');

        if (mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      }
    }
  }

  Future<void> _showReorderVideoDialog(CourseVideo video) async {
    LoggingUtils.debugLog(
        "🔄 Opening reorder dialog for video: ${video.title}");

    try {
      final result = await CourseVideoDialogUtils.showReorderVideoDialog(
        context,
        video,
        _sections,
        _videosBySection,
        _uncategorizedVideos,
      );

      LoggingUtils.debugLog("📊 Dialog result: $result");

      if (result != null) {
        final String? targetSectionId = result['sectionId'];
        final int targetPosition = result['position'];

        await Future.delayed(const Duration(milliseconds: 50));

        await _handleReorderVideo(video, targetPosition, targetSectionId);
      }
    } catch (e) {
      LoggingUtils.debugLog("❌ Error showing reorder dialog: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء محاولة إعادة الترتيب: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildVideosList() {
    return RepaintBoundary(
      child: ValueListenableBuilder<bool>(
        valueListenable: _sectionExpandStateNotifier,
        builder: (context, _, __) {
          return CourseVideoListComponent.buildVideosList(
            videos: _videos,
            sections: _sections,
            videosBySection: _videosBySection,
            uncategorizedVideos: _uncategorizedVideos,
            expandedSections: _expandedSections,
            scrollController: _mainScrollController,
            selectedVideo: _selectedVideo,
            onToggleSection: _toggleSection,
            onPlayVideoInline: _playVideoInline,
            onAddNewVideo: _addNewVideo,
            onPlayVideo: _playVideo,
            videoPositions: _videoPlaybackPositions,
            onReorderVideo: _handleReorderVideo,
            onReorderSection: _handleSectionReorder,
            onReorderRequested: _showReorderVideoDialog,
          );
        },
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CustomProgressIndicator(),
          const SizedBox(height: 10),
          Text(
            'جاري تحميل الفيديوهات...',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFixedCurrentVideoBar() {
    if (_selectedVideo == null) return const SizedBox.shrink();

    final bgColor = Color.fromARGB(255, 70, 115, 174);

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        boxShadow: [
          BoxShadow(
            color: AppColors.buttonPrimary.withOpacity(0.15),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(13),
          topRight: Radius.circular(13),
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            bgColor.withOpacity(0.95),
            bgColor,
          ],
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: const Center(
              child: Icon(
                Icons.video_library,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'قيد التشغيل الآن',
                  style: TextStyle(
                    fontSize: 8,
                    color: Colors.white.withOpacity(0.8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  _selectedVideo!.title,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildNavigationButton(
                icon: Icons.skip_previous,
                enabled: _findPreviousVideo() != null,
                onPressed: _navigateToPreviousVideo,
                tooltip: 'الفيديو السابق',
              ),
              const SizedBox(width: 4),
              _buildNavigationButton(
                icon: Icons.skip_next,
                enabled: _findNextVideo() != null,
                onPressed: _navigateToNextVideo,
                tooltip: 'الفيديو التالي',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationButton({
    required IconData icon,
    required bool enabled,
    required VoidCallback onPressed,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      textStyle: const TextStyle(fontSize: 10, color: Colors.white),
      child: InkWell(
        onTap: enabled ? onPressed : null,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: enabled
                ? Colors.white.withOpacity(0.2)
                : Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: enabled
                  ? Colors.white.withOpacity(0.3)
                  : Colors.white.withOpacity(0.1),
              width: 1,
            ),
          ),
          child: Center(
            child: Icon(
              icon,
              color: enabled ? Colors.white : Colors.white.withOpacity(0.4),
              size: 16,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingActionButton() {
    return Positioned(
      bottom: 75,
      left: 14,
      child: FloatingActionButton(
        onPressed: _addNewVideo,
        backgroundColor: AppColors.buttonPrimary,
        foregroundColor: Colors.white,
        elevation: 2,
        mini: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(13),
        ),
        child: const Icon(Icons.add, size: 20),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenKey = UniqueKey();

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

    return GestureDetector(
      onTap: () {},
      behavior: HitTestBehavior.translucent,
      child: Scaffold(
        key: screenKey,
        backgroundColor: AppColors.primaryBg,
        extendBodyBehindAppBar: true,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(0),
          child: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            systemOverlayStyle: const SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: Brightness.dark,
            ),
          ),
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
                Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12.0, vertical: 8.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              widget.course.title,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppColors.buttonPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          PopupMenuButton<String>(
                            icon: const Icon(
                              Icons.more_vert,
                              color: AppColors.buttonPrimary,
                              size: 16,
                            ),
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'refresh',
                                child: Row(
                                  children: [
                                    Icon(Icons.refresh,
                                        size: 14,
                                        color: AppColors.buttonPrimary),
                                    SizedBox(width: 6),
                                    Text('تحديث',
                                        style: TextStyle(fontSize: 12)),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'player_iframe',
                                child: Row(
                                  children: [
                                    Icon(Icons.web,
                                        size: 14,
                                        color: AppColors.buttonPrimary),
                                    SizedBox(width: 6),
                                    Text('مشغل iframe',
                                        style: TextStyle(fontSize: 12)),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'player_media_kit',
                                child: Row(
                                  children: [
                                    Icon(Icons.play_circle_fill,
                                        size: 14,
                                        color: AppColors.buttonPrimary),
                                    SizedBox(width: 6),
                                    Text('مشغل Media Kit',
                                        style: TextStyle(fontSize: 12)),
                                  ],
                                ),
                              ),
                            ],
                            onSelected: (value) {
                              if (value == 'refresh') {
                                _refreshVideos();
                              } else if (value.startsWith('player_')) {
                                final playerType = value.substring(7);
                                _changePlayerType(playerType);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    if (!_isLoading &&
                        _errorMessage == null &&
                        _selectedVideo != null)
                      Container(
                        constraints: BoxConstraints(
                          maxHeight: MediaQuery.of(context).size.height * 0.5,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
                          child: RepaintBoundary(
                            child: _buildEmbeddedPlayer(),
                          ),
                        ),
                      ),
                    if (!_isLoading &&
                        _errorMessage == null &&
                        _videos.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'محتويات الكورس (${_videos.length})',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            if (_selectedVideo != null)
                              CourseVideoNavigationButtons(
                                videos: _videos,
                                selectedVideo: _selectedVideo!,
                                onNavigate: (video) => _playVideoInline(video),
                              ),
                          ],
                        ),
                      ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: _isLoading
                            ? _buildLoadingState()
                            : _errorMessage != null
                                ? CourseVideoUIUtils.buildErrorState(
                                    _errorMessage, _loadVideosAndSections)
                                : CustomScrollView(
                                    controller: _mainScrollController,
                                    physics: const BouncingScrollPhysics(),
                                    slivers: [
                                      SliverToBoxAdapter(
                                        child: RepaintBoundary(
                                          child: _buildVideosList(),
                                        ),
                                      ),
                                      SliverToBoxAdapter(
                                        child: SizedBox(height: 100),
                                      ),
                                    ],
                                  ),
                      ),
                    ),
                  ],
                ),
                if (!_isLoading &&
                    _errorMessage == null &&
                    _selectedVideo != null)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: _buildFixedCurrentVideoBar(),
                  ),
                _buildFloatingActionButton(),
              ],
            ),
          ),
        ),
        floatingActionButton: null,
      ),
    );
  }
}
