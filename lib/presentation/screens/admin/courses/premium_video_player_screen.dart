import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:mycourses/core/config/bunny_config.dart';
import 'package:mycourses/core/constants/app_colors.dart';
import 'package:mycourses/models/course_video.dart';
import 'package:mycourses/presentation/screens/admin/courses/direct_video_player_screen.dart';

class PremiumVideoPlayerScreen extends StatefulWidget {
  final CourseVideo video;
  final bool embedded;
  final Duration startPosition;
  final Function(dynamic controller)? onPlayerCreated;
  final Function(Duration position)? onPositionChanged;

  const PremiumVideoPlayerScreen({
    super.key,
    required this.video,
    this.embedded = false,
    this.startPosition = Duration.zero,
    this.onPlayerCreated,
    this.onPositionChanged,
  });

  @override
  State<PremiumVideoPlayerScreen> createState() =>
      _PremiumVideoPlayerScreenState();
}

class _PremiumVideoPlayerScreenState extends State<PremiumVideoPlayerScreen> {
  late Player _player;
  late VideoController _controller;
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;
  bool _isMediaKitAvailable = true;
  Duration _currentPosition = Duration.zero;

  @override
  void initState() {
    super.initState();
    _currentPosition = widget.startPosition;
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    try {
      setState(() {
        _isLoading = true;
        _hasError = false;
        _errorMessage = null;
      });

      // التحقق من توفر MediaKit (يتم القيام بذلك من خلال إنشاء مثيل Player)
      try {
        _player = Player();
        _controller = VideoController(_player);
        _isMediaKitAvailable = true;
      } catch (e) {
        debugPrint('⚠️ خطأ في إنشاء مشغل MediaKit: $e');
        setState(() {
          _isMediaKitAvailable = false;
          _hasError = true;
          _errorMessage = 'المكتبات المطلوبة للمشغل المتطور غير متوفرة. $e';
        });
        return;
      }

      // إعداد مسار التشغيل
      final videoUrl = BunnyConfig.getDirectVideoUrl(widget.video.videoId);
      if (videoUrl.isEmpty) {
        throw Exception('لم يتم العثور على رابط الفيديو');
      }

      // إضافة مراقب لمواقع التشغيل
      _player.stream.position.listen((position) {
        if (position != _currentPosition) {
          _currentPosition = position;
          if (widget.onPositionChanged != null) {
            widget.onPositionChanged!(position);
          }
        }
      });

      // تشغيل الفيديو
      await _player.open(Media(videoUrl));

      // الانتقال إلى موقع التشغيل المحدد
      if (widget.startPosition.inSeconds > 0) {
        await _player.seek(widget.startPosition);
      }

      // إخطار الشاشة الأم بإنشاء المشغل
      if (widget.onPlayerCreated != null) {
        widget.onPlayerCreated!(_player);
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('⚠️ خطأ في تهيئة المشغل المتطور: $e');
      setState(() {
        _hasError = true;
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    // حفظ موقع التشغيل الأخير
    if (widget.onPositionChanged != null) {
      widget.onPositionChanged!(_currentPosition);
    }

    // تنظيف موارد المشغل
    if (_isMediaKitAvailable) {
      _player.dispose();
    }

    super.dispose();
  }

  void _handleFallbackPlayer() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => DirectVideoPlayerScreen(
          video: widget.video,
          startPosition: _currentPosition,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.buttonPrimary),
        ),
      );
    }

    if (_hasError || !_isMediaKitAvailable) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text(
                'غير قادر على تشغيل الفيديو',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage ?? 'مكتبات المشغل المتطور غير متوفرة',
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.white70,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              // إضافة توجيهات للمستخدم
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blueGrey.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    const Text(
                      'لتثبيت المكتبات المطلوبة:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '1. قم بتنزيل ملف libmpv-2.dll من موقع MPV الرسمي\n'
                      '2. قم بوضع الملف في مجلد التطبيق\n'
                      '3. أعد تشغيل التطبيق',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _handleFallbackPlayer,
                icon: const Icon(Icons.video_library),
                label: const Text('استخدام مشغل بديل'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.buttonPrimary,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Video(
      controller: _controller,
      controls: AdaptiveVideoControls,
      fill: Colors.black,
    );
  }
}
