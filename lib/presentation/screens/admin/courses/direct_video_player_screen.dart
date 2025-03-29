import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mycourses/core/config/bunny_config.dart';
import 'package:mycourses/core/constants/app_colors.dart';
import 'package:mycourses/core/constants/app_text_styles.dart';
import 'package:mycourses/core/services/course_videos_service.dart';
import 'package:mycourses/models/course_video.dart';
import 'package:mycourses/presentation/widgets/video_player/custom_chewie_controls.dart';
import 'package:video_player/video_player.dart';

class DirectVideoPlayerScreen extends StatefulWidget {
  final CourseVideo video;
  final bool embedded;
  final Duration startPosition;
  final Function(dynamic controller)? onPlayerCreated;
  final Function(Duration position)? onPositionChanged;
  // إضافة خصائص التنقل بين الفيديوهات
  final VoidCallback? onNextVideo;
  final VoidCallback? onPreviousVideo;

  const DirectVideoPlayerScreen({
    super.key,
    required this.video,
    this.embedded = false,
    this.startPosition = Duration.zero,
    this.onPlayerCreated,
    this.onPositionChanged,
    // تعريف المتغيرات الجديدة
    this.onNextVideo,
    this.onPreviousVideo,
  });

  @override
  State<DirectVideoPlayerScreen> createState() =>
      _DirectVideoPlayerScreenState();
}

class _DirectVideoPlayerScreenState extends State<DirectVideoPlayerScreen> {
  late VideoPlayerController _videoPlayerController;
  ChewieController? _chewieController;
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;
  Map<String, dynamic>? _videoDetails;
  int _retryCount = 0;
  final int _maxRetries = 3;

  // Track position for reporting back
  Duration _currentPosition = Duration.zero;

  // Navigation properties
  bool get _hasPreviousVideo => widget.onPreviousVideo != null;
  bool get _hasNextVideo => widget.onNextVideo != null;

  // إضافة متغيرات التحكم بالجودة
  final List<String> _availableQualities = ['Auto', '720', '420', '360'];
  String _currentQuality = 'Auto'; // تغيير القيمة الافتراضية إلى Auto
  String? _currentVideoUrl;

  @override
  void initState() {
    super.initState();
    _currentPosition = widget.startPosition;
    _loadVideoDetails();
  }

  Future<void> _loadVideoDetails() async {
    try {
      final details =
          await CourseVideosService.getVideoDetails(widget.video.videoId);

      if (mounted) {
        setState(() {
          _videoDetails = details;
        });
      }
    } catch (e) {
      debugPrint('خطأ في تحميل تفاصيل الفيديو: $e');
    } finally {
      _initializeVideoPlayer();
    }
  }

  Future<bool> _checkVideoAccessibility(String url) async {
    try {
      final response = await http.head(Uri.parse(url));
      return response.statusCode < 400; // رمز 200 أو 300 يعني أن الملف متاح
    } catch (e) {
      debugPrint('فشل فحص إمكانية الوصول للفيديو: $e');
      return false;
    }
  }

  Future<void> _initializeVideoPlayer() async {
    try {
      setState(() {
        _isLoading = true;
        _hasError = false;
        _errorMessage = null;
      });

      // تحديد جودة الفيديو الافتراضية
      _currentQuality = 'Auto';

      // الحصول على رابط الفيديو بناءً على الجودة المختارة
      String videoUrl = _getVideoUrlForQuality(_currentQuality);
      _currentVideoUrl = videoUrl;

      if (videoUrl.isEmpty) {
        throw Exception('لم يتم العثور على رابط الفيديو الصحيح');
      }

      debugPrint('استخدام رابط الفيديو: $videoUrl');

      // تهيئة مشغل الفيديو
      _videoPlayerController = VideoPlayerController.networkUrl(
        Uri.parse(videoUrl),
        httpHeaders: {
          'Referer': 'https://bunny.net/',
          'Origin': 'https://bunny.net/',
          'User-Agent': 'Mozilla/5.0 Flutter Video Player',
        },
      );

      // Add error listener before initialization
      _videoPlayerController.addListener(() {
        final error = _videoPlayerController.value.errorDescription;
        if (error != null && error.isNotEmpty) {
          debugPrint('Video player error: $error');
          // If we get an error and haven't tried HLS yet, fallback to it
          if (_retryCount < _maxRetries &&
              !videoUrl.contains('playlist.m3u2')) {
            _retryCount++;
            _tryHlsPlayback();
          }
        }

        // Track position changes
        if (_videoPlayerController.value.isInitialized &&
            !_videoPlayerController.value.isBuffering) {
          final newPosition = _videoPlayerController.value.position;
          if (newPosition != _currentPosition) {
            _currentPosition = newPosition;
            if (widget.onPositionChanged != null) {
              widget.onPositionChanged!(_currentPosition);
            }
          }
        }
      });

      // انتظار التهيئة
      await _videoPlayerController.initialize();

      // Seek to start position
      if (widget.startPosition.inSeconds > 0) {
        await _videoPlayerController.seekTo(widget.startPosition);
      }

      // تكوين chewie controller
      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController,
        autoPlay: true,
        looping: false,
        allowMuting: true,
        allowFullScreen: true,
        allowPlaybackSpeedChanging: true,
        showControls: true,
        aspectRatio: _videoPlayerController.value.aspectRatio,
        errorBuilder: (context, errorMessage) {
          return _buildErrorWidget(errorMessage);
        },
        materialProgressColors: ChewieProgressColors(
          playedColor: AppColors.buttonPrimary,
          handleColor: AppColors.buttonPrimary,
          backgroundColor: Colors.grey.shade300,
          bufferedColor: AppColors.buttonPrimary.withOpacity(0.5),
        ),
        customControls: CustomChewieControls(
          hasPreviousVideo: _hasPreviousVideo,
          hasNextVideo: _hasNextVideo,
          onPreviousVideo: widget.onPreviousVideo,
          onNextVideo: widget.onNextVideo,
          primaryColor: AppColors.buttonPrimary,
          showQualitySelector: true,
          availableQualities:
              _availableQualities.where((q) => q != 'Auto').toList(),
          currentQuality: _currentQuality,
          onQualityChanged: _changeVideoQuality,
        ),
      );

      // Notify when the player is created
      if (widget.onPlayerCreated != null) {
        widget.onPlayerCreated!(_videoPlayerController);
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Player initialization error: $e');

      // If we got an error with MP4, try HLS instead if we haven't already
      if (_retryCount < _maxRetries) {
        _retryCount++;
        _tryHlsPlayback();
        return;
      }

      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  // الحصول على رابط الفيديو حسب الجودة
  String _getVideoUrlForQuality(String quality) {
    switch (quality) {
      case 'Auto':
        // بالنسبة للجودة التلقائية، استخدم رابط m3u2 لدعم التبديل التلقائي للجودة
        return BunnyConfig.getDirectVideoUrl(widget.video.videoId);
      case '720':
        return BunnyConfig.getVideoUrlWithQuality(widget.video.videoId, '720');
      case '420':
        return BunnyConfig.getVideoUrlWithQuality(widget.video.videoId, '420');
      case '360':
        return BunnyConfig.getVideoUrlWithQuality(widget.video.videoId, '360');
      default:
        // إعادة الجودة التلقائية كافتراضي
        return BunnyConfig.getDirectVideoUrl(widget.video.videoId);
    }
  }

  // تغيير جودة الفيديو - تحسين للتعامل مع الخطأ والانتقال بين الجودات
  Future<void> _changeVideoQuality(String quality) async {
    // لا نفعل شيئًا إذا كانت الجودة هي نفسها المحددة حاليًا
    if (quality == _currentQuality) return;

    // حفظ حالة التشغيل الحالية
    final currentPosition = _videoPlayerController.value.position;
    final wasPlaying = _videoPlayerController.value.isPlaying;

    setState(() {
      _isLoading = true;
      _currentQuality = quality;
    });

    try {
      // تخزين وحدات التحكم القديمة مؤقتًا
      final oldController = _videoPlayerController;
      final oldChewieController = _chewieController;

      // الحصول على رابط الفيديو للجودة الجديدة
      final newVideoUrl = _getVideoUrlForQuality(quality);
      _currentVideoUrl = newVideoUrl;

      debugPrint('🔄 تغيير الجودة إلى $quality - الرابط: $newVideoUrl');

      // إنشاء وحدة تحكم جديدة
      final newController = VideoPlayerController.networkUrl(
        Uri.parse(newVideoUrl),
        httpHeaders: {
          'Referer': 'https://bunny.net/',
          'Origin': 'https://bunny.net/',
          'User-Agent': 'Mozilla/5.0 Flutter Video Player',
        },
      );

      // تهيئة وحدة التحكم الجديدة
      await newController.initialize();

      // الانتقال إلى نفس موضع التشغيل السابق
      await newController.seekTo(currentPosition);

      // حفظ معدل التشغيل الحالي للاستخدام مع المشغل الجديد
      final currentPlaybackSpeed = oldController.value.playbackSpeed;
      await newController.setPlaybackSpeed(currentPlaybackSpeed);

      // بدء التشغيل إذا كان المشغل القديم يعمل
      if (oldController.value.isPlaying) {
        await newController.play();
      }

      // إنشاء وحدة تحكم Chewie جديدة
      final newChewieController = ChewieController(
        videoPlayerController: newController,
        autoPlay: wasPlaying, // استخدام حالة التشغيل السابقة
        looping: false,
        allowMuting: true,
        allowFullScreen: true,
        allowPlaybackSpeedChanging: true,
        showControls: true,
        aspectRatio: newController.value.aspectRatio,
        errorBuilder: (context, errorMessage) {
          return _buildErrorWidget(errorMessage);
        },
        materialProgressColors: ChewieProgressColors(
          playedColor: AppColors.buttonPrimary,
          handleColor: AppColors.buttonPrimary,
          backgroundColor: Colors.grey.shade300,
          bufferedColor: AppColors.buttonPrimary.withOpacity(0.5),
        ),
        customControls: CustomChewieControls(
          hasPreviousVideo: _hasPreviousVideo,
          hasNextVideo: _hasNextVideo,
          onPreviousVideo: widget.onPreviousVideo,
          onNextVideo: widget.onNextVideo,
          primaryColor: AppColors.buttonPrimary,
          showQualitySelector: true,
          availableQualities:
              _availableQualities.where((q) => q != 'Auto').toList(),
          currentQuality: _currentQuality,
          onQualityChanged: _changeVideoQuality,
        ),
      );

      // تحديث المتغيرات بوحدات التحكم الجديدة
      if (mounted) {
        setState(() {
          _videoPlayerController = newController;
          _chewieController = newChewieController;
          _isLoading = false;
        });
      }

      // التخلص من وحدات التحكم القديمة بعد تحديث الحالة
      Future.delayed(const Duration(milliseconds: 300), () {
        try {
          if (oldChewieController != null) {
            oldChewieController.dispose();
          }
          oldController.dispose();
        } catch (e) {
          debugPrint('خطأ غير مؤثر أثناء التخلص من المتحكمات القديمة: $e');
        }
      });
    } catch (e) {
      debugPrint('❌ خطأ في تغيير جودة الفيديو: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = 'فشل في تغيير جودة الفيديو: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _tryHlsPlayback() async {
    try {
      // Clean up previous controller
      await _videoPlayerController.dispose();

      // Get HLS URL and try again
      String hlsUrl = BunnyConfig.getDirectVideoUrl(widget.video.videoId);

      _videoPlayerController = VideoPlayerController.networkUrl(
        Uri.parse(hlsUrl),
        httpHeaders: {
          'Referer': 'https://bunny.net/',
          'Origin': 'https://bunny.net/',
          'User-Agent': 'Mozilla/5.0 Flutter Video Player',
        },
      );

      await _videoPlayerController.initialize();

      // Seek to start position
      if (widget.startPosition.inSeconds > 0) {
        await _videoPlayerController.seekTo(widget.startPosition);
      }

      // Configure Chewie for HLS
      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController,
        autoPlay: true,
        looping: false,
        showControls: true,
        aspectRatio: _videoPlayerController.value.aspectRatio,
        errorBuilder: (context, errorMessage) {
          return _buildErrorWidget(errorMessage);
        },
        customControls: CustomChewieControls(
          hasPreviousVideo: _hasPreviousVideo,
          hasNextVideo: _hasNextVideo,
          onPreviousVideo: widget.onPreviousVideo,
          onNextVideo: widget.onNextVideo,
          primaryColor: AppColors.buttonPrimary,
          showQualitySelector: true,
          availableQualities: _availableQualities,
          currentQuality: _currentQuality,
          onQualityChanged: _changeVideoQuality,
        ),
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = 'فشل تشغيل الفيديو بصيغة HLS: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    // Report final position
    if (widget.onPositionChanged != null) {
      widget.onPositionChanged!(_currentPosition);
    }

    _videoPlayerController.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  void _retryPlayback() {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = null;
    });
    _initializeVideoPlayer();
  }

  Widget _buildErrorWidget(String errorMessage) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 42),
          const SizedBox(height: 2),
          Text(
            'فشل في تشغيل الفيديو',
            style: AppTextStyles.titleMedium.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 4),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              errorMessage,
              style: AppTextStyles.bodyMedium.copyWith(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 2),
          ElevatedButton.icon(
            onPressed: _retryPlayback,
            icon: const Icon(Icons.refresh),
            label: const Text('إعادة المحاولة'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.buttonPrimary,
            ),
          ),
          const SizedBox(height: 4),
          TextButton(
            onPressed: () => _tryAlternativePlaybackMethod(),
            child: const Text('استخدام طريقة عرض بديلة'),
          ),
        ],
      ),
    );
  }

  void _tryAlternativePlaybackMethod() {
    // يمكن هنا محاولة استخدام طريقة تشغيل بديلة، مثل WebView أو طريقة أخرى
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('طرق عرض بديلة'),
        content: const Text('هل ترغب في تجربة تشغيل الفيديو بطريقة أخرى؟'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // محاولة تشغيل مباشرة بدون Chewie
              _initializePlainVideoPlayer();
            },
            child: const Text('تشغيل مباشر'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context); // العودة إلى الشاشة السابقة
            },
            child: const Text('إلغاء'),
          ),
        ],
      ),
    );
  }

  void _initializePlainVideoPlayer() {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    // الحصول على رابط مباشر آخر (مثل MP4 إذا كان متاحًا)
    final directUrl = BunnyConfig.getDirectVideoUrl(widget.video.videoId);
    final mp4Url = directUrl.replaceAll('playlist.m3u2', 'video.mp4');

    try {
      _videoPlayerController = VideoPlayerController.networkUrl(
        Uri.parse(mp4Url),
        httpHeaders: {
          'Referer': 'https://bunny.net/',
          'User-Agent': 'Mozilla/5.0 BunnyPlayer',
        },
      );

      _videoPlayerController.initialize().then((_) {
        _chewieController = ChewieController(
          videoPlayerController: _videoPlayerController,
          autoPlay: true,
          looping: false,
          showControls: true,
        );

        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }).catchError((error) {
        if (mounted) {
          setState(() {
            _hasError = true;
            _errorMessage = 'فشل في التشغيل المباشر: $error';
            _isLoading = false;
          });
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = 'فشل في تهيئة التشغيل المباشر: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // إذا كان مضمّناً في صفحة أخرى، لا نعرض أي عناصر إضافية
    if (widget.embedded) {
      return _buildVideoPlayer();
    }

    // عند العرض كشاشة مستقلة، نعرض الفيديو فقط بملء الشاشة
    return Scaffold(
      backgroundColor: Colors.black,
      // إزالة الـ AppBar تماماً
      body: SafeArea(
        // تضمين الفيديو فقط بدون أي معلومات إضافية
        child: _buildVideoPlayer(),
      ),
    );
  }

  Widget _buildVideoPlayer() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.buttonPrimary),
        ),
      );
    }

    if (_hasError || _chewieController == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 24),
            const SizedBox(height: 2),
            Text(
              'فشل في تشغيل الفيديو',
              style: AppTextStyles.titleMedium.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                _errorMessage ?? 'حدث خطأ غير معروف',
                style: AppTextStyles.bodyMedium.copyWith(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 2),
            ElevatedButton.icon(
              onPressed: _retryPlayback,
              icon: const Icon(Icons.refresh),
              label: const Text('إعادة المحاولة'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.buttonPrimary,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 5),
              ),
            ),
            const SizedBox(height: 4),
            TextButton.icon(
              icon: const Icon(Icons.switch_video, size: 16),
              label: const Text('تجربة طريقة أخرى'),
              onPressed: _tryAlternativePlaybackMethod,
            ),
          ],
        ),
      );
    }

    // مهم: لا نستخدم Directionality هنا حيث سنضبط اتجاه العناصر في أماكن أخرى
    return Directionality(
      textDirection: TextDirection.ltr, // تطبيق اتجاه LTR على مشغل الفيديو
      child: _chewieController != null
          ? Chewie(
              controller: _chewieController!,
            )
          : const SizedBox.shrink(),
    );
  }
}
