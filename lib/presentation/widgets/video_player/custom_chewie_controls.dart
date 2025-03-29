import 'dart:async';

import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:mycourses/core/constants/app_colors.dart';
import 'package:video_player/video_player.dart';

/// واجهة تحكم مخصصة لمشغل Chewie
class CustomChewieControls extends StatefulWidget {
  final bool hasPreviousVideo;
  final bool hasNextVideo;
  final VoidCallback? onPreviousVideo;
  final VoidCallback? onNextVideo;
  final Color primaryColor;
  final bool showQualitySelector;
  // إضافة وظائف التحكم بالجودة
  final List<String>? availableQualities;
  final Function(String)? onQualityChanged;
  final String? currentQuality;

  const CustomChewieControls({
    super.key,
    this.hasPreviousVideo = false,
    this.hasNextVideo = false,
    this.onPreviousVideo,
    this.onNextVideo,
    this.primaryColor = AppColors.buttonPrimary,
    this.showQualitySelector = false,
    this.availableQualities,
    this.onQualityChanged,
    this.currentQuality,
  });

  @override
  State<CustomChewieControls> createState() => _CustomChewieControlsState();
}

class _CustomChewieControlsState extends State<CustomChewieControls>
    with SingleTickerProviderStateMixin {
  late AnimationController _hideControlsTimer;
  bool _controlsVisible = true;
  late VideoPlayerValue _latestValue;
  Timer? _positionTimer;
  Timer? _bufferingTimer;
  bool _displayBufferingIndicator = false;

  // سرعات التشغيل المتاحة
  final List<double> _playbackSpeeds = [
    0.25,
    0.5,
    0.75,
    1.0,
    1.25,
    1.5,
    1.75,
    2.0
  ];

  ChewieController? _chewieController;

  // تعديل قائمة الجودات المتاحة لإضافة خيار "تلقائي"
  List<String> get _qualityOptions {
    if (widget.availableQualities == null ||
        widget.availableQualities!.isEmpty) {
      return ['Auto'];
    }
    // تأكد من وجود خيار تلقائي في المقدمة وعدم وجود تكرار
    final List<String> qualities = ['Auto'];
    for (String quality in widget.availableQualities!) {
      if (quality != 'Auto') {
        qualities.add(quality);
      }
    }
    return qualities;
  }

  @override
  void initState() {
    super.initState();
    _hideControlsTimer = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    _hideControlsTimer.addStatusListener(_animationStatusListener);
  }

  @override
  void dispose() {
    _positionTimer?.cancel();
    _bufferingTimer?.cancel();
    _hideControlsTimer.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _chewieController = ChewieController.of(context);
    if (_chewieController != null &&
        _chewieController!.videoPlayerController.value.isInitialized) {
      _latestValue = _chewieController!.videoPlayerController.value;

      // مراقبة التغييرات في الفيديو
      _chewieController!.videoPlayerController.addListener(_updateState);

      // بدء مؤقت إخفاء عناصر التحكم
      _hideControlsTimer.forward();
    }
  }

  void _updateState() {
    if (!mounted) return;

    // تحديث حالة المشغل
    final newValue = _chewieController!.videoPlayerController.value;
    final isBuffering = _latestValue.isBuffering != newValue.isBuffering;

    if (isBuffering) {
      _displayBufferingIndicator = true;
      _bufferingTimer?.cancel();
      _bufferingTimer = Timer(const Duration(milliseconds: 500), () {
        if (mounted) {
          setState(() => _displayBufferingIndicator = false);
        }
      });
    }

    setState(() {
      _latestValue = newValue;
    });
  }

  void _animationStatusListener(AnimationStatus status) {
    if (status == AnimationStatus.completed && _controlsVisible) {
      setState(() => _controlsVisible = false);
    }
  }

  void _toggleControls() {
    setState(() {
      _controlsVisible = !_controlsVisible;
      if (_controlsVisible) {
        _hideControlsTimer.forward(from: 0);
      } else {
        _hideControlsTimer.reset();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_chewieController == null ||
        !_chewieController!.videoPlayerController.value.isInitialized) {
      return Container(
        color: Colors.black,
        child: Center(
          child: CircularProgressIndicator(color: widget.primaryColor),
        ),
      );
    }

    // استخدام Directionality لتطبيق LTR داخل عناصر التحكم فقط
    return Directionality(
      textDirection: TextDirection.ltr, // تطبيق اتجاه LTR لعناصر التحكم
      child: GestureDetector(
        onTap: _toggleControls,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          children: [
            // الخلفية السوداء
            Container(color: Colors.black),

            // الفيديو نفسه
            Center(
              child: AspectRatio(
                aspectRatio:
                    _chewieController!.videoPlayerController.value.aspectRatio,
                child: VideoPlayer(_chewieController!.videoPlayerController),
              ),
            ),

            // مؤشر التحميل
            if (_displayBufferingIndicator)
              Center(
                child: CircularProgressIndicator(color: widget.primaryColor),
              ),

            // عناصر التحكم
            AnimatedOpacity(
              opacity: _controlsVisible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: Stack(
                children: [
                  // طبقة شفافة سوداء لتحسين تباين عناصر التحكم
                  Container(
                    color: Colors.black.withOpacity(0.4),
                  ),

                  // أزرار التنقل في الوسط - تصغير الأحجام
                  Center(
                    child: Row(
                      mainAxisAlignment:
                          MainAxisAlignment.center, // تعديل التوسيط
                      children: [
                        if (widget.hasPreviousVideo)
                          _buildControlButton(
                            icon: Icons.skip_previous,
                            onPressed: widget.onPreviousVideo,
                            tooltip: 'الفيديو السابق',
                            size: _chewieController!.isFullScreen
                                ? 16
                                : 16, // حجم مختلف بناءً على حالة ملء الشاشة
                          ),

                        SizedBox(
                            width: _chewieController!.isFullScreen ? 16 : 8),

                        // زر التشغيل/الإيقاف المؤقت - تصغير الحجم
                        _buildPlayPauseButton(),

                        SizedBox(
                            width: _chewieController!.isFullScreen ? 16 : 8),

                        if (widget.hasNextVideo)
                          _buildControlButton(
                            icon: Icons.skip_next,
                            onPressed: widget.onNextVideo,
                            tooltip: 'الفيديو التالي',
                            size: _chewieController!.isFullScreen
                                ? 16
                                : 16, // تصغير حجم الأيقونة
                          ),
                      ],
                    ),
                  ),

                  // شريط التحكم السفلي
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: _buildBottomBar(),
                  ),

                  // زر ملء الشاشة في الأعلى - تغيير الموضع
                  Positioned(
                    top: 0,
                    left: 5, // تغيير من right إلى left للتوافق مع LTR
                    child: _buildFullscreenButton(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback? onPressed,
    required String tooltip,
    double size = 10, // تقليل الحجم الافتراضي للأيقونة
  }) {
    final bool isFullScreen = _chewieController?.isFullScreen ?? false;
    return Container(
      width: isFullScreen ? 36 : 16, // تقليل العرض والارتفاع أكثر
      height: isFullScreen ? 36 : 16, // تقليل العرض والارتفاع أكثر
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(icon, size: size, color: Colors.white),
        onPressed: onPressed,
        tooltip: tooltip,
        padding: EdgeInsets.zero,
        constraints: BoxConstraints(
          minWidth: isFullScreen ? 36 : 16,
          minHeight: isFullScreen ? 36 : 16,
        ),
      ),
    );
  }

  Widget _buildPlayPauseButton() {
    final bool isFullScreen = _chewieController?.isFullScreen ?? false;
    return Container(
      width: isFullScreen ? 48 : 28, // تقليل العرض والارتفاع أكثر
      height: isFullScreen ? 48 : 28, // تقليل العرض والارتفاع أكثر
      decoration: BoxDecoration(
        color: widget.primaryColor.withOpacity(0.8),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(
          _latestValue.isPlaying ? Icons.pause : Icons.play_arrow,
          size: isFullScreen ? 32 : 16, // تقليل حجم الأيقونة
          color: Colors.white,
        ),
        onPressed: () {
          // إصلاح مشكلة عدم الاستجابة لزر التشغيل/الإيقاف
          if (_latestValue.isPlaying) {
            // التأكد من إيقاف التشغيل فعلياً
            _chewieController!.videoPlayerController.pause().then((_) {
              debugPrint('✅ تم إيقاف الفيديو بنجاح');
            }).catchError((error) {
              debugPrint('❌ خطأ عند إيقاف الفيديو: $error');
            });
          } else {
            // التأكد من التشغيل فعلياً
            _chewieController!.videoPlayerController.play().then((_) {
              debugPrint('✅ تم تشغيل الفيديو بنجاح');
            }).catchError((error) {
              debugPrint('❌ خطأ عند تشغيل الفيديو: $error');
            });
          }

          // إعادة ضبط مؤقت الإخفاء
          _hideControlsTimer.forward(from: 0);
        },
        padding: EdgeInsets.zero,
        constraints: BoxConstraints(
          minWidth: isFullScreen ? 48 : 28,
          minHeight: isFullScreen ? 48 : 28,
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    final bool isFullScreen = _chewieController?.isFullScreen ?? false;
    // تعديل المسافات الداخلية لشريط التحكم السفلي
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: isFullScreen ? 16 : 4, // تقليل التباعد الأفقي
          vertical: isFullScreen ? 8 : 0), // تقليل المسافة العمودية
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // شريط التقدم
          _buildProgressBar(),

          // تقليل المسافة بين شريط التقدم والتحكم
          SizedBox(height: isFullScreen ? 4 : 1),

          // الوقت والأزرار الإضافية
          SizedBox(
            height: isFullScreen ? null : 20, // تقليل ارتفاع الصف أكثر
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // الوقت الحالي - تقليل المساحة
                SizedBox(
                  width: isFullScreen ? null : 36, // تحديد عرض ثابت للنص
                  child: Text(
                    _formatDuration(_latestValue.position),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isFullScreen ? 12 : 8, // تصغير حجم الخط أكثر
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                // المدة الإجمالية - تقليل المساحة
                SizedBox(
                  width: isFullScreen ? null : 36, // تحديد عرض ثابت للنص
                  child: Text(
                    ' / ${_formatDuration(_latestValue.duration)}',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: isFullScreen ? 12 : 8, // تصغير حجم الخط أكثر
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                // المسافة المرنة - تقليلها
                SizedBox(width: isFullScreen ? 8 : 2),

                // أزرار التحكم بحجم أصغر وتباعد أقل
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // أزرار التقديم والإرجاع 5 ثواني
                    _buildSkipButtons(),
                    // زر سرعة التشغيل
                    _buildSpeedButton(),
                    // زر جودة الفيديو
                    _buildQualityButton(),
                    // زر كتم الصوت
                    _buildMuteButton(),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    return SliderTheme(
      data: SliderThemeData(
        trackHeight: 2, // تقليل سمك شريط التقدم
        thumbShape: RoundSliderThumbShape(
            enabledThumbRadius: 5), // تقليل حجم مؤشر التقدم
        thumbColor: widget.primaryColor,
        activeTrackColor: widget.primaryColor,
        inactiveTrackColor: Colors.grey[600],
        overlayColor: widget.primaryColor.withOpacity(0.2),
      ),
      child: Slider(
        value: _latestValue.position.inMilliseconds.toDouble().clamp(
              0,
              _latestValue.duration.inMilliseconds.toDouble(),
            ),
        min: 0,
        max: _latestValue.duration.inMilliseconds.toDouble(),
        onChanged: (value) {
          _chewieController!.seekTo(Duration(milliseconds: value.toInt()));

          // إعادة ضبط مؤقت الإخفاء
          _hideControlsTimer.forward(from: 0);
        },
      ),
    );
  }

  Widget _buildFullscreenButton() {
    return Container(
      width: 35,
      height: 35,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(
          _chewieController!.isFullScreen
              ? Icons.fullscreen_exit
              : Icons.fullscreen,
          color: Colors.white,
          size: 18,
        ),
        onPressed: () {
          _chewieController!.toggleFullScreen();
        },
        padding: EdgeInsets.zero,
      ),
    );
  }

  Widget _buildSpeedButton() {
    final bool isFullScreen = _chewieController?.isFullScreen ?? false;
    return PopupMenuButton<double>(
      tooltip: 'سرعة التشغيل',
      iconSize: isFullScreen ? 20 : 10, // تصغير حجم الأيقونة
      padding: EdgeInsets.zero, // إزالة الهوامش الداخلية
      constraints: BoxConstraints(
        minWidth: isFullScreen ? 40 : 16, // تقليل الحد الأدنى للعرض
        minHeight: isFullScreen ? 40 : 16, // تقليل الحد الأدنى للارتفاع
      ),
      icon:
          Icon(Icons.speed, color: Colors.white, size: isFullScreen ? 20 : 10),
      onSelected: (double speed) {
        // Fix the method name - use the correct method from ChewieController
        _chewieController!.videoPlayerController.setPlaybackSpeed(speed);
      },
      itemBuilder: (context) {
        return _playbackSpeeds.map((speed) {
          return PopupMenuItem<double>(
            value: speed,
            child: Row(
              children: [
                Text('${speed}x'),
                if (speed ==
                    _chewieController!
                        .videoPlayerController.value.playbackSpeed)
                  Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: Icon(Icons.check, color: widget.primaryColor),
                  ),
              ],
            ),
          );
        }).toList();
      },
    );
  }

  // إضافة أزرار للتقدم والرجوع 5 ثواني - تصغير الأحجام بشكل أكبر
  Widget _buildSkipButtons() {
    final bool isFullScreen = _chewieController?.isFullScreen ?? false;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // زر الرجوع 5 ثواني
        IconButton(
          icon: Icon(
            Icons.replay_5,
            color: Colors.white,
            size: isFullScreen ? 24 : 10, // تصغير الأيقونة أكثر
          ),
          onPressed: () {
            final currentPosition = _latestValue.position;
            final newPosition = currentPosition - const Duration(seconds: 5);
            _chewieController!.seekTo(
              newPosition.isNegative ? Duration.zero : newPosition,
            );
            // إعادة ضبط مؤقت الإخفاء
            _hideControlsTimer.forward(from: 0);
          },
          tooltip: 'الرجوع 5 ثواني',
          constraints: BoxConstraints(
            minWidth: isFullScreen ? 40 : 16, // تقليل الحد الأدنى للعرض
            minHeight: isFullScreen ? 40 : 16, // تقليل الحد الأدنى للارتفاع
          ),
          padding: EdgeInsets.zero,
        ),

        // زر التقدم 5 ثواني
        IconButton(
          icon: Icon(
            Icons.forward_5,
            color: Colors.white,
            size: isFullScreen ? 24 : 10, // تصغير الأيقونة أكثر
          ),
          onPressed: () {
            final currentPosition = _latestValue.position;
            final maxDuration = _latestValue.duration;
            final newPosition = currentPosition + const Duration(seconds: 5);
            _chewieController!.seekTo(
              newPosition > maxDuration ? maxDuration : newPosition,
            );
            // إعادة ضبط مؤقت الإخفاء
            _hideControlsTimer.forward(from: 0);
          },
          tooltip: 'التقدم 5 ثواني',
          constraints: BoxConstraints(
            minWidth: isFullScreen ? 40 : 16, // تقليل الحد الأدنى للعرض
            minHeight: isFullScreen ? 40 : 16, // تقليل الحد الأدنى للارتفاع
          ),
          padding: EdgeInsets.zero,
        ),
      ],
    );
  }

  // تحسين زر اختيار الجودة مع تصغير الحجم
  Widget _buildQualityButton() {
    final bool isFullScreen = _chewieController?.isFullScreen ?? false;
    // إذا لم تكن جودات متاحة، لا نعرض الزر
    if (!widget.showQualitySelector) {
      return const SizedBox.shrink();
    }

    return PopupMenuButton<String>(
      tooltip: 'جودة الفيديو',
      iconSize: isFullScreen ? 20 : 10, // تصغير حجم الأيقونة
      padding: EdgeInsets.zero, // إزالة الهوامش الداخلية
      constraints: BoxConstraints(
        minWidth: isFullScreen ? 40 : 16, // تقليل الحد الأدنى للعرض
        minHeight: isFullScreen ? 40 : 16, // تقليل الحد الأدنى للارتفاع
      ),
      icon: Icon(Icons.hd, color: Colors.white, size: isFullScreen ? 20 : 10),
      // قم بإزالة Row للعرض المبسط في الوضع العادي (غير ملء الشاشة)
      onSelected: (String quality) {
        if (widget.onQualityChanged != null) {
          widget.onQualityChanged!(quality);
        }
      },
      itemBuilder: (context) {
        return _qualityOptions.map((quality) {
          return PopupMenuItem<String>(
            value: quality,
            child: Row(
              children: [
                Text(quality),
                if (quality == (widget.currentQuality ?? 'Auto'))
                  Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: Icon(Icons.check, color: widget.primaryColor),
                  ),
              ],
            ),
          );
        }).toList();
      },
    );
  }

  Widget _buildMuteButton() {
    final bool isFullScreen = _chewieController?.isFullScreen ?? false;
    return IconButton(
      icon: Icon(
        _latestValue.volume > 0 ? Icons.volume_up : Icons.volume_off,
        color: Colors.white,
        size: isFullScreen ? 20 : 10, // تصغير حجم الأيقونة
      ),
      onPressed: () {
        if (_latestValue.volume > 0) {
          _chewieController!.setVolume(0);
        } else {
          _chewieController!.setVolume(1.0);
        }
      },
      constraints: BoxConstraints(
        minWidth: isFullScreen ? 40 : 16, // تقليل الحد الأدنى للعرض
        minHeight: isFullScreen ? 40 : 16, // تقليل الحد الأدنى للارتفاع
      ),
      padding: EdgeInsets.zero,
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    if (duration.inHours > 0) {
      return '${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds';
    }
    return '$twoDigitMinutes:$twoDigitSeconds';
  }
}
