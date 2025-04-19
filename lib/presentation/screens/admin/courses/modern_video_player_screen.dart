import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mycourses/core/config/bunny_config.dart';
import 'package:mycourses/core/constants/app_colors.dart';
import 'package:mycourses/core/constants/app_text_styles.dart';
import 'package:mycourses/core/utils/drm_helper.dart';
import 'package:mycourses/models/course_video.dart';
import 'package:pod_player/pod_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class ModernVideoPlayerScreen extends StatefulWidget {
  final CourseVideo video;
  final bool embedded;
  final Duration startPosition;
  final Function(dynamic controller)? onPlayerCreated;
  final Function(Duration position)? onPositionChanged;

  const ModernVideoPlayerScreen({
    super.key,
    required this.video,
    this.embedded = false,
    this.startPosition = Duration.zero,
    this.onPlayerCreated,
    this.onPositionChanged,
  });

  @override
  State<ModernVideoPlayerScreen> createState() =>
      _ModernVideoPlayerScreenState();
}

class _ModernVideoPlayerScreenState extends State<ModernVideoPlayerScreen> {
  late PodPlayerController _controller;
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;
  bool _isDrmProtected = false;
  Timer? _positionTimer;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
    // منع قفل الشاشة أثناء تشغيل الفيديو
    WakelockPlus.enable();

    // Setup position tracking
    _positionTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (widget.onPositionChanged != null) {
        // In a real implementation, get actual position from your controller
        _getPositionAndNotify();
      }
    });
  }

  Future<void> _initializePlayer() async {
    try {
      // تحقق من حماية DRM
      final requirement =
          await DrmHelper.getPlaybackRequirement(widget.video.videoId);

      setState(() {
        _isDrmProtected = requirement.isDrmProtected;
      });

      if (_isDrmProtected) {
        setState(() {
          _hasError = true;
          _errorMessage =
              'هذا الفيديو محمي بنظام DRM ويتطلب استخدام مشغل Embed';
          _isLoading = false;
        });
        return;
      }

      // اختيار الرابط المناسب (HLS أفضل من MP4)
      final videoUrl = BunnyConfig.getDirectVideoUrl(widget.video.videoId);
      final thumbnailUrl = BunnyConfig.getThumbnailUrl(widget.video.videoId);

      // تهيئة المشغل مع إعدادات خاصة لتفعيل كل أدوات التحكم
      _controller = PodPlayerController(
        playVideoFrom: PlayVideoFrom.network(
          videoUrl,
          // إضافة رؤوس HTTP لتجنب مشاكل CORS
          httpHeaders: {
            'Origin': 'https://bunny.net',
            'Referer': 'https://bunny.net/'
          },
        ),
        podPlayerConfig: const PodPlayerConfig(
          autoPlay: true,
          isLooping: false,
          videoQualityPriority: [720, 480, 360],
          // تم حذف enableFullscreen لأنه لم يعد موجودًا في النسخة الحالية
        ),
      )..initialise().then((_) {
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
          }

          // Notify when controller is ready
          if (widget.onPlayerCreated != null) {
            widget.onPlayerCreated!(_controller);
          }

          // Seek to start position once initialized
          if (widget.startPosition.inMilliseconds > 0) {
            // Implement seeking logic based on your controller type
          }
        }).catchError((e) {
          // في حالة الفشل، جرب صيغة MP4
          _tryMp4Fallback();
        });
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = 'فشل في تحميل الفيديو: $e';
        _isLoading = false;
      });
    }
  }

  void _tryMp4Fallback() {
    try {
      // محاولة تشغيل بصيغة MP4 كخطة بديلة
      final mp4Url = BunnyConfig.getDirectMp4Url(widget.video.videoId);

      // تحرير المشغل السابق وتهيئة مشغل جديد
      _controller.dispose();
      _controller = PodPlayerController(
        playVideoFrom: PlayVideoFrom.network(
          mp4Url,
          httpHeaders: {
            'Origin': 'https://bunny.net',
            'Referer': 'https://bunny.net/'
          },
        ),
        podPlayerConfig: const PodPlayerConfig(
          autoPlay: true,
          isLooping: false,
          // تم حذف enableFullscreen لأنه لم يعد موجودًا في النسخة الحالية
        ),
      )..initialise().then((_) {
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
          }

          // Notify when controller is ready
          if (widget.onPlayerCreated != null) {
            widget.onPlayerCreated!(_controller);
          }

          // Seek to start position once initialized
          if (widget.startPosition.inMilliseconds > 0) {
            // Implement seeking logic based on your controller type
          }
        }).catchError((e) {
          if (mounted) {
            setState(() {
              _hasError = true;
              _errorMessage = 'تعذر تشغيل الفيديو بجميع الصيغ: $e';
              _isLoading = false;
            });
          }
        });
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = 'فشل في تحميل الفيديو بصيغة MP4: $e';
        _isLoading = false;
      });
    }
  }

  void _getPositionAndNotify() {
    // Get current position from controller and notify via callback
    // This is a placeholder - implement according to your actual controller
    Duration currentPosition = Duration.zero; // Get from controller
    if (widget.onPositionChanged != null) {
      widget.onPositionChanged!(currentPosition);
    }
  }

  @override
  void dispose() {
    _positionTimer?.cancel();
    if (!_hasError) {
      _controller.dispose();
    }
    // السماح بقفل الشاشة مرة أخرى عند الخروج
    WakelockPlus.disable();
    // استعادة توجيه الشاشة الافتراضي
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
        overlays: SystemUiOverlay.values);
    super.dispose();
  }

  void _toggleFullScreen() async {
    if (MediaQuery.of(context).orientation == Orientation.portrait) {
      // الانتقال إلى وضع ملء الشاشة
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      // العودة من وضع ملء الشاشة
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
          overlays: SystemUiOverlay.values);
    }

    // إعادة بناء الواجهة بعد تغيير الاتجاه
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: isLandscape
          ? null // إخفاء شريط التطبيق في وضع ملء الشاشة
          : AppBar(
              backgroundColor: Colors.black,
              elevation: 0,
              systemOverlayStyle: SystemUiOverlayStyle.light,
              title: Text(
                widget.video.title,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.fullscreen, color: Colors.white),
                  onPressed: _toggleFullScreen,
                  tooltip: 'ملء الشاشة',
                ),
                if (_isDrmProtected)
                  IconButton(
                    icon:
                        const Icon(Icons.security, color: Colors.orangeAccent),
                    onPressed: () => _showDrmInfoDialog(),
                    tooltip: 'معلومات حماية الفيديو',
                  ),
              ],
            ),
      body: SafeArea(
        minimum: isLandscape
            ? EdgeInsets.zero
            : const EdgeInsets.all(0), // Replace null with non-null EdgeInsets
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : _hasError
                ? _buildErrorWidget()
                : Column(
                    children: [
                      // مشغل الفيديو
                      Stack(
                        children: [
                          PodVideoPlayer(
                            controller: _controller,
                            videoThumbnail: DecorationImage(
                              image: NetworkImage(BunnyConfig.getThumbnailUrl(
                                  widget.video.videoId)),
                              fit: BoxFit.cover,
                            ),
                            podProgressBarConfig: const PodProgressBarConfig(
                              playingBarColor: AppColors.buttonPrimary,
                              circleHandlerColor: AppColors.buttonPrimary,
                              backgroundColor: Colors.grey,
                            ),
                            matchVideoAspectRatioToFrame: true,
                            matchFrameAspectRatioToVideo: true,
                            alwaysShowProgressBar: true,
                          ),
                          if (isLandscape)
                            Positioned(
                              top: 8,
                              right: 8,
                              child: IconButton(
                                icon: const Icon(Icons.fullscreen_exit,
                                    color: Colors.white, size: 28),
                                onPressed: _toggleFullScreen,
                              ),
                            ),
                        ],
                      ),
                      // معلومات الفيديو (إظهار في الوضع العمودي فقط)
                      if (!isLandscape)
                        Expanded(
                          child: _buildVideoInfo(),
                        ),
                    ],
                  ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            const Text(
              'فشل في تحميل الفيديو',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'حدث خطأ غير متوقع',
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white70,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (_isDrmProtected) ...[
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(
                    context,
                    '/web_video_player',
                    arguments: widget.video,
                  );
                },
                icon: const Icon(Icons.security),
                label: const Text('استخدام مشغل DRM'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
            ] else ...[
              ElevatedButton.icon(
                onPressed: _initializePlayer,
                icon: const Icon(Icons.refresh),
                label: const Text('إعادة المحاولة'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.buttonPrimary,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildVideoInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.video.title,
            style: AppTextStyles.titleMedium.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'المدة: ${widget.video.formattedDuration}',
            style: AppTextStyles.bodyMedium.copyWith(
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 12),
          if (widget.video.description.isNotEmpty)
            Text(
              widget.video.description,
              style: AppTextStyles.bodyMedium.copyWith(
                color: Colors.white70,
              ),
            ),
        ],
      ),
    );
  }

  void _showDrmInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.security, color: Colors.orange),
            const SizedBox(width: 8),
            const Text('حماية MediaCage DRM'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(DrmHelper.getDrmInfoMessage()),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: const Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.info, color: Colors.blue, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'معلومات تقنية',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    'MediaCage Basic من Bunny.net هو نظام DRM يشفر ملفات الفيديو ديناميكيًا لحمايتها من التنزيل غير المصرح به. وفقًا لوثائق Bunny.net، عند تفعيل هذه الميزة، سيكون الفيديو قابلاً للتشغيل فقط من خلال واجهة Embed.',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('فهمت'),
          ),
        ],
      ),
    );
  }
}
