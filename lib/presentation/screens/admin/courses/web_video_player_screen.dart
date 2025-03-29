import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mycourses/core/constants/app_colors.dart';
import 'package:mycourses/core/constants/app_text_styles.dart';
import 'package:mycourses/core/utils/responsive_helper.dart';
import 'package:mycourses/models/course_video.dart';
import 'package:mycourses/presentation/screens/admin/courses/direct_video_player_screen.dart';
import 'package:webview_flutter/webview_flutter.dart';

class WebVideoPlayerScreen extends StatefulWidget {
  final CourseVideo video;
  final bool embedded;
  final Duration startPosition;
  final Function(dynamic controller)? onPlayerCreated;
  final Function(Duration position)? onPositionChanged;
  // Add parameters for navigation
  final bool hasNextVideo;
  final bool hasPreviousVideo;
  final VoidCallback? onNextVideo;
  final VoidCallback? onPreviousVideo;

  const WebVideoPlayerScreen({
    super.key,
    required this.video,
    this.embedded = false,
    this.startPosition = Duration.zero,
    this.onPlayerCreated,
    this.onPositionChanged,
    // Initialize new parameters with default values
    this.hasNextVideo = false,
    this.hasPreviousVideo = false,
    this.onNextVideo,
    this.onPreviousVideo,
  });

  @override
  State<WebVideoPlayerScreen> createState() => _WebVideoPlayerScreenState();
}

class _WebVideoPlayerScreenState extends State<WebVideoPlayerScreen> {
  late WebViewController _controller;
  bool _isLoading = true;
  bool _isFullScreen = false;
  Duration _currentPosition = Duration.zero;
  Timer? _positionTimer;
  bool _isWebViewAvailable = true; // Flag to track WebView availability

  // إضافة متغيرات للتعامل مع الأخطاء وإعادة المحاولة
  int _errorCount = 0;
  bool _isVideoElementFound = false;
  bool _isRecoveringFromError = false;
  Timer? _videoElementCheckTimer;

  // إضافة متغير للتحكم في حالة الشاشة
  bool _disposed = false;
  int _videoJsCheckAttempts = 0;
  final int _maxVideoJsCheckAttempts = 5;
  Timer? _setupNavButtonsTimer;

  @override
  void initState() {
    super.initState();
    debugPrint(
        '⏱️ تشغيل الفيديو ${widget.video.title} من الموقع: ${widget.startPosition.inSeconds}s');
    _currentPosition = widget.startPosition;

    _positionTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (widget.onPositionChanged != null && !_disposed) {
        widget.onPositionChanged!(_currentPosition);
        _currentPosition = _currentPosition + const Duration(seconds: 1);
      }
    });

    // Initialize WebView with error handling
    _initializeController();
  }

  void _initializeController() {
    try {
      debugPrint(
          '🎬 Initializing WebVideoPlayer for ${widget.video.title} at position: ${widget.startPosition.inSeconds}s');

      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.black)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageStarted: (String url) {
              if (mounted) {
                setState(() {
                  _isLoading = true;

                  // Reset error recovery state on new page load
                  _isRecoveringFromError = false;
                  _errorCount = 0;
                });
              }
            },
            onPageFinished: (String url) {
              if (mounted) {
                setState(() {
                  _isLoading = false;
                });

                // بدء فحص دوري لتوفر عناصر الفيديو
                _startVideoElementCheck();

                // إضافة فحص لوجود videojs قبل محاولة استخدامه
                _injectVideoJsCheck();

                // Delay seek to ensure the video is ready
                Future.delayed(const Duration(milliseconds: 1000), () {
                  if (widget.startPosition.inSeconds > 0 && mounted) {
                    debugPrint(
                        '🎯 محاولة الانتقال إلى موقع التشغيل: ${widget.startPosition.inSeconds}s');
                    _seekToPosition(widget.startPosition.inSeconds);

                    // Additional attempt after delay
                    Future.delayed(const Duration(milliseconds: 2000), () {
                      if (mounted) {
                        _seekToPosition(widget.startPosition.inSeconds);
                      }
                    });
                  }
                });
              }
            },
            onWebResourceError: (WebResourceError error) {
              debugPrint('WebView error: ${error.description}');

              // تعامل مختلف مع الأخطاء - لا نعين _isWebViewAvailable=false مباشرة
              _handleWebViewError(error);
            },
          ),
        )
        ..loadRequest(
          Uri.parse(_getBunnyEmbedUrl()),
          headers: {
            'Referer': 'https://bunny.net/',
            'Origin': 'https://bunny.net',
          },
        );

      if (widget.onPlayerCreated != null) {
        Future.delayed(
            Duration.zero, () => widget.onPlayerCreated!(_controller));
      }
    } catch (e) {
      debugPrint('WebView initialization error: $e');
      setState(() {
        _isWebViewAvailable = false;
        _isLoading = false;
      });
    }
  }

  // دالة جديدة للتعامل مع أخطاء WebView بشكل أكثر مرونة
  void _handleWebViewError(WebResourceError error) {
    // زيادة عداد الأخطاء
    _errorCount++;

    // بعض الأخطاء يمكن تجاهلها إذا كانت متعلقة بموارد ثانوية غير مهمة
    bool isIgnorableError = error.description.contains('ERR_FAILED') &&
        !_isVideoElementFound &&
        _errorCount < 5;

    if (isIgnorableError) {
      debugPrint('⚠️ خطأ غير مؤثر في WebView: ${error.description}');
      // لا نفعل شيئًا، نترك الصفحة تحاول التحميل
    } else if (_errorCount >= 5 && !_isRecoveringFromError) {
      // إذا كان هناك العديد من الأخطاء، نحاول إعادة تحميل الصفحة
      _isRecoveringFromError = true;
      debugPrint('🔄 محاولة إعادة تحميل صفحة الفيديو بعد خطأ متكرر');

      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          _controller.reload();

          // إعادة تعيين عداد الأخطاء بعد إعادة التحميل
          Future.delayed(const Duration(seconds: 1), () {
            _errorCount = 0;
            _isRecoveringFromError = false;
          });
        }
      });
    } else if (_errorCount >= 10) {
      // بعد محاولات كثيرة، نعتبر أن WebView غير متاح
      if (mounted) {
        setState(() {
          _isWebViewAvailable = false;
          _isLoading = false;
        });
      }
    }
  }

  // إضافة دالة لفحص عناصر الفيديو بشكل دوري
  void _startVideoElementCheck() {
    // إلغاء أي مؤقت سابق
    _videoElementCheckTimer?.cancel();

    if (_disposed) return;

    // بدء فحص دوري لعناصر الفيديو
    _videoElementCheckTimer =
        Timer.periodic(const Duration(seconds: 3), (timer) {
      if (_disposed) {
        timer.cancel();
        return;
      }

      _controller.runJavaScript('''
        var videoElement = document.querySelector('video');
        var videojsPlayer = (typeof videojs !== 'undefined') ? videojs(document.querySelector('video')) : null;
        
        if (videoElement && (videoElement.readyState >= 2 || videojsPlayer)) {
          console.log("VIDEO_ELEMENT_FOUND: " + (videojsPlayer ? "videojs" : "html5"));
        } else {
          console.log("VIDEO_ELEMENT_NOT_FOUND");
        }
      ''');
    });
  }

  void _seekToPosition(int seconds) {
    if (seconds <= 0) return;

    _controller.runJavaScript('''
      try {
        // التحقق من وجود videojs قبل استخدامه
        if (typeof videojs !== 'undefined') {
          var player = videojs(document.querySelector('video'));
          if (player) {
            player.currentTime($seconds);
            console.log("تم الانتقال إلى الموقع: $seconds ثانية");
          }
        } else {
          console.log('Cannot seek: videojs not available yet');
          // محاولة استخدام HTML5 video API مباشرة كبديل
          var videoElement = document.querySelector('video');
          if (videoElement) {
            videoElement.currentTime = $seconds;
            console.log("تم الانتقال إلى الموقع باستخدام HTML5 API: $seconds ثانية");
          }
        }
      } catch(e) {
        console.error('خطأ أثناء محاولة الانتقال إلى موقع معين:', e);
      }
    ''');
  }

  String _getBunnyEmbedUrl() {
    // صحيح - أخذ المعرف من الفيديو
    final videoId = widget.video.videoId;
    final libraryId = '399973'; // معرف المكتبة الافتراضي للتطوير

    // إضافة معلمات مخصصة لتحسين التوافق ومنع مشاكل مضمن الفيديو
    final customParams = {
      'autoplay': 'true',
      'muted': 'false',
      'loop': 'false',
      'preload': 'true',
      'responsive': 'true',
      'background': '000000',
      'startTime': widget.startPosition.inSeconds.toString(),
      'backward': 'true',
      'forward': 'true',
      'fullscreenButton': 'true',
      'controls': 'true',
      't': DateTime.now().millisecondsSinceEpoch.toString(),
    };

    final queryString = customParams.entries
        .map((entry) => '${entry.key}=${entry.value}')
        .join('&');

    return 'https://iframe.mediadelivery.net/embed/$libraryId/$videoId?$queryString';
  }

  void _injectSimpleControls() {
    if (_disposed) return;

    // تعديل كود JavaScript ليتحقق من وجود videojs قبل استخدامه
    _controller.runJavaScript('''
      // تعريف دالة آمنة للتعامل مع videojs
      function safeVideoJs(callback) {
        if (typeof videojs !== 'undefined') {
          try {
            callback();
          } catch(e) {
            console.error("Error in videojs callback:", e);
          }
        } else {
          console.log("videojs not available for operation");
        }
      }
      
      // إضافة مستمع بسيط لحدث ملء الشاشة مع تغيير الاتجاه
      document.addEventListener('fullscreenchange', function() {
        if (document.fullscreenElement) {
          console.log("FLUTTER_FULLSCREEN_ENTER");
        } else {
          console.log("FLUTTER_FULLSCREEN_EXIT");
        }
      });
      
      // مراقبة أحداث نقر زر ملء الشاشة
      var fullscreenButton = document.querySelector('.vjs-fullscreen-control');
      if (fullscreenButton) {
        fullscreenButton.addEventListener('click', function(e) {
          var isCurrentlyFullscreen = !!(document.fullscreenElement);
          
          if (isCurrentlyFullscreen) {
            console.log("FLUTTER_FULLSCREEN_EXIT");
          } else {
            console.log("FLUTTER_FULLSCREEN_ENTER");
          }
        });
      }

      // تحسين وإصلاح أزرار التنقل بين الفيديوهات 
      window.setupNavButtonsAttempts = 0;
      window.setupCustomNavigationButtons = function() {
        window.setupNavButtonsAttempts++;
        console.log("Setting up CUSTOM navigation buttons: hasPrevious=${widget.hasPreviousVideo}, hasNext=${widget.hasNextVideo}, attempt " + window.setupNavButtonsAttempts);
        
        // لا تستمر بعد عدد محدد من المحاولات
        if (window.setupNavButtonsAttempts > 10) {
          console.log("تم الوصول للحد الأقصى من محاولات إعداد أزرار التنقل");
          return;
        }
        
        // التحقق من وجود لاعب الفيديو
        var player = document.querySelector('video');
        if (!player) {
          console.log("Video element not found, retrying in 1s...");
          setTimeout(setupCustomNavigationButtons, 1000);
          return;
        }
        
        // بحث عن حاوية الفيديو
        var videoContainer = document.querySelector('.video-js');
        if (!videoContainer) {
          console.log("Video container not found, retrying in 1s...");
          setTimeout(setupCustomNavigationButtons, 1000);
          return;
        }
        
        // التحقق من عدم وجود الأزرار مسبقًا (لتجنب التكرار)
        var existingNavControls = document.querySelector('.custom-nav-controls');
        if (existingNavControls) {
          existingNavControls.remove();
        }
        
        // إنشاء حاوية جديدة للأزرار
        var navControls = document.createElement('div');
        navControls.className = 'custom-nav-controls';
        
        // CSS لحاوية أزرار التنقل
        var navStyle = document.createElement('style');
        navStyle.textContent = `
          .custom-nav-controls {
            position: absolute;
            top: 50%;
            width: 100%;
            transform: translateY(-50%);
            display: flex;
            justify-content: space-between;
            padding: 0 20px;
            box-sizing: border-box;
            pointer-events: none;
            z-index: 2;
          }
          
          .nav-button {
            width: 50px;
            height: 50px;
            background-color: rgba(0, 0, 0, 0.6);
            color: white;
            border: none;
            border-radius: 50%;
            font-size: 20px;
            display: flex;
            align-items: center;
            justify-content: center;
            cursor: pointer;
            transition: transform 0.2s, background-color 0.2s;
            pointer-events: auto;
            opacity: 0;
            transition: opacity 0.3s ease-in-out, transform 0.2s;
          }
          
          .nav-button:hover {
            background-color: rgba(0, 128, 255, 0.8);
            transform: scale(1.1);
          }
          
          .video-js:hover .nav-button {
            opacity: 0.7;
          }
          
          .nav-button:hover {
            opacity: 1 !important;
          }
          
          .nav-button svg {
            width: 24px;
            height: 24px;
            fill: currentColor;
          }

          .nav-button-prev {
            left: 20px;
          }
          
          .nav-button-next {
            right: 20px;
          }
        `;
        
        document.head.appendChild(navStyle);
        
        // إنشاء زر السابق
        if (${widget.hasPreviousVideo ? 'true' : 'false'}) {
          var prevButton = document.createElement('button');
          prevButton.className = 'nav-button nav-button-prev';
          prevButton.innerHTML = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><path d="M15.41 7.41L14 6l-6 6 6 6 1.41-1.41L10.83 12z"/></svg>';
          prevButton.setAttribute('title', 'الفيديو السابق');
          prevButton.onclick = function(e) {
            e.preventDefault();
            e.stopPropagation();
            console.log("FLUTTER_NAVIGATE_PREVIOUS");
          };
          navControls.appendChild(prevButton);
        } else {
          // إضافة زر غير مفعل كعنصر نائب للمحافظة على التوازن
          var dummyPrev = document.createElement('div');
          dummyPrev.style.width = '50px';
          navControls.appendChild(dummyPrev);
        }
        
        // إنشاء زر التالي
        if (${widget.hasNextVideo ? 'true' : 'false'}) {
          var nextButton = document.createElement('button');
          nextButton.className = 'nav-button nav-button-next';
          nextButton.innerHTML = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><path d="M10 6L8.59 7.41 13.17 12l-4.58 4.59L10 18l6-6z"/></svg>';
          nextButton.setAttribute('title', 'الفيديو التالي');
          nextButton.onclick = function(e) {
            e.preventDefault(); 
            e.stopPropagation();
            console.log("FLUTTER_NAVIGATE_NEXT");
          };
          navControls.appendChild(nextButton);
        } else {
          // إضافة زر غير مفعل كعنصر نائب
          var dummyNext = document.createElement('div');
          dummyNext.style.width = '50px';
          navControls.appendChild(dummyNext);
        }
        
        // إضافة الأزرار إلى حاوية الفيديو
        videoContainer.appendChild(navControls);
        
        console.log("Custom navigation buttons setup complete");
      }
      
      // إضافة الأزرار فور تحميل الصفحة وبعد فترة للتأكد
      setupCustomNavigationButtons();
      setTimeout(setupCustomNavigationButtons, 1000);
      setTimeout(setupCustomNavigationButtons, 3000);
      
      // حفظ موقع التشغيل بشكل دوري - بطريقة آمنة
      var positionUpdateInterval = setInterval(function() {
        if (window.videoPlayerStopped) {
          clearInterval(positionUpdateInterval);
          return;
        }
        
        safeVideoJs(function() {
          var player = videojs(document.querySelector('video'));
          if (player) {
            var currentTime = player.currentTime();
            if (currentTime > 0) {
              console.log("FLUTTER_POSITION_UPDATE:" + currentTime);
            }
          }
        });
      }, 3000);
    ''');

    // إعداد مستمع لرسائل وحدة التحكم
    _setupConsoleMessageListener();
  }

  void _injectVideoJsCheck() {
    if (_disposed) return;

    _videoJsCheckAttempts++;

    _controller.runJavaScript('''
      try {
        if (typeof videojs === 'undefined') {
          console.log('videojs is not available yet, will retry later');
          
          // تعيين متغير عام للتحكم في استدعاءات setupCustomNavigationButtons
          window._flutterVideoJsChecksComplete = false;
          
          // تقليل عدد مرات التكرار لتجنب استمرار المحاولات للأبد
          if ($_videoJsCheckAttempts < $_maxVideoJsCheckAttempts) {
            setTimeout(function() {
              if (typeof videojs !== 'undefined') {
                console.log('videojs is now available');
                window._flutterVideoJsChecksComplete = true;
                setupCustomNavigationButtons();
              } else {
                console.log('videojs is still not available after delay');
              }
            }, 3000);
          } else {
            console.log('محاولات البحث عن videojs استنفدت - توقف عن المحاولة');
            window._flutterVideoJsChecksComplete = true;
          }
        } else {
          console.log('videojs is available, setting up controls');
          window._flutterVideoJsChecksComplete = true;
          setupCustomNavigationButtons();
        }
      } catch(e) {
        console.error('Error checking videojs:', e);
        window._flutterVideoJsChecksComplete = true;
      }
    ''');

    // توقف عن محاولات إعداد أزرار التنقل بعد عدد محدد من المحاولات
    _clearSetupNavButtonsTimer();
    if (_videoJsCheckAttempts < _maxVideoJsCheckAttempts) {
      _setupNavButtonsTimer =
          Timer.periodic(const Duration(seconds: 5), (timer) {
        if (_disposed || _videoJsCheckAttempts >= _maxVideoJsCheckAttempts) {
          timer.cancel();
          return;
        }

        // التحقق من أن محاولات videojs انتهت قبل بدء محاولة جديدة
        _controller.runJavaScript('''
          if (!window._flutterVideoJsChecksComplete) {
            console.log("ما زالت محاولات التحقق من videojs قيد التنفيذ");
          } else {
            setupCustomNavigationButtons();
          }
        ''');
      });
    }

    // Then inject the rest of the controls after the check
    _injectSimpleControls();
  }

  void _clearSetupNavButtonsTimer() {
    if (_setupNavButtonsTimer != null) {
      _setupNavButtonsTimer!.cancel();
      _setupNavButtonsTimer = null;
    }
  }

  void _setupConsoleMessageListener() {
    // استخدام واجهة برمجة التطبيقات الصحيحة لإعداد معالجة رسائل وحدة التحكم
    _controller = _controller
      ..setOnConsoleMessage((JavaScriptConsoleMessage consoleMessage) {
        final message = consoleMessage.message;

        // Debug each console message to see what's happening
        debugPrint("WebView Console: $message");

        // فحص الرسائل لإشعارات ملء الشاشة
        if (message.contains('FLUTTER_FULLSCREEN_ENTER')) {
          _handleFullscreenChange(true);
        } else if (message.contains('FLUTTER_FULLSCREEN_EXIT')) {
          _handleFullscreenChange(false);
        }
        // إضافة التعامل مع رسائل التنقل بين الفيديوهات
        else if (message.contains('FLUTTER_NAVIGATE_NEXT')) {
          debugPrint("Navigation: Next video requested");
          if (widget.onNextVideo != null && widget.hasNextVideo) {
            widget.onNextVideo!();
          }
        } else if (message.contains('FLUTTER_NAVIGATE_PREVIOUS')) {
          debugPrint("Navigation: Previous video requested");
          if (widget.onPreviousVideo != null && widget.hasPreviousVideo) {
            widget.onPreviousVideo!();
          }
        }
        // إضافة استماع لتحديثات موقع التشغيل
        else if (message.contains('FLUTTER_POSITION_UPDATE:')) {
          try {
            final parts = message.split(':');
            if (parts.length > 1) {
              final seconds = double.parse(parts[1]);
              if (seconds > 0) {
                _currentPosition = Duration(seconds: seconds.toInt());
                if (widget.onPositionChanged != null) {
                  widget.onPositionChanged!(_currentPosition);
                }
              }
            }
          } catch (e) {
            debugPrint('Error parsing position update: $e');
          }
        }
        // التحقق من وجود عنصر الفيديو
        else if (message.contains('VIDEO_ELEMENT_FOUND')) {
          _isVideoElementFound = true;
          // يمكن إيقاف مؤقت فحص عنصر الفيديو إذا تم العثور عليه
          if (_videoElementCheckTimer != null) {
            _videoElementCheckTimer!.cancel();
            _videoElementCheckTimer = null;
          }
        }
      });
  }

  void _handleFullscreenChange(bool isEntering) {
    debugPrint('تغيير حالة ملء الشاشة: ${isEntering ? 'دخول' : 'خروج'}');

    if (isEntering) {
      // حالة الدخول إلى ملء الشاشة - تعيين الاتجاه الأفقي
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

      // تحديث الحالة
      if (!_isFullScreen && mounted) {
        setState(() {
          _isFullScreen = true;
        });
      }
    } else {
      // حالة الخروج من ملء الشاشة - العودة إلى الاتجاه العمودي
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

      // تحديث الحالة
      if (_isFullScreen && mounted) {
        setState(() {
          _isFullScreen = false;
        });
      }
    }
  }

  Future<void> _toggleFullScreen() async {
    try {
      if (_isFullScreen) {
        await SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
        ]);
        await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

        _controller.runJavaScript('''
          if (document.exitFullscreen) {
            document.exitFullscreen();
          } else if (document.webkitExitFullscreen) {
            document.webkitExitFullscreen();
          } else if (document.msExitFullscreen) {
            document.msExitFullscreen();
          }
          
          var player = videojs(document.querySelector('video'));
          if (player && player.isFullscreen()) {
            player.exitFullscreen();
          }
        ''');
      } else {
        await SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
        await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

        _controller.runJavaScript('''
          var player = videojs(document.querySelector('video'));
          if (player && !player.isFullscreen()) {
            player.requestFullscreen();
          }
        ''');
      }

      await Future.delayed(const Duration(milliseconds: 300));

      setState(() {
        _isFullScreen = !_isFullScreen;
      });
    } catch (e) {
      debugPrint('Error toggling fullscreen: $e');
      setState(() {
        _isFullScreen = !_isFullScreen;
      });
    }
  }

  @override
  void dispose() {
    _disposed = true;

    // إلغاء المؤقتات
    _positionTimer?.cancel();
    _videoElementCheckTimer?.cancel();
    _clearSetupNavButtonsTimer();

    // حفظ موقع التشغيل النهائي قبل إغلاق المشغل
    if (widget.onPositionChanged != null) {
      debugPrint(
          '📱 حفظ موقع التشغيل النهائي عند إغلاق المشغل: ${_currentPosition.inSeconds}s');
      widget.onPositionChanged!(_currentPosition);
    }

    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    // إيقاف جميع محاولات JavaScript المستمرة
    try {
      _controller.runJavaScript('''
        try {
          // إعلام أي مؤقتات JavaScript بأن المشغل قد توقف
          window.videoPlayerStopped = true;
          
          // إلغاء أي مؤقتات معروفة
          if (window.positionUpdateInterval) {
            clearInterval(window.positionUpdateInterval);
          }
          
          // التحقق من وجود videojs أولاً
          if (typeof videojs !== 'undefined') {
            var player = videojs(document.querySelector('video'));
            if (player) {
              player.pause();
              if (player.dispose) {
                player.dispose();
              }
            }
          } else {
            console.log('videojs not available, skipping dispose');
          }
          
          // إيقاف أي عناصر فيديو أصلية
          var videoElements = document.querySelectorAll('video');
          videoElements.forEach(function(video) {
            if (video.pause) {
              video.pause();
              video.src = '';
              video.load();
            }
          });
        } catch(e) {
          console.error('Error in safe dispose:', e);
        }
      ''');
    } catch (e) {
      debugPrint('خطأ عند محاولة تنظيف WebView: $e');
    }

    // إعادة تعيين WebViewController
    try {
      _controller.loadRequest(Uri.parse('about:blank'));
    } catch (e) {
      debugPrint('خطأ عند محاولة إعادة تعيين WebView: $e');
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // If WebView is not available, show fallback player or error message
    if (!_isWebViewAvailable) {
      return _buildWebViewFallback();
    }

    // الحفاظ على مفتاح فريد للشاشة بناءً على معرف الفيديو لإعادة إنشاء المكون
    final videoKey = ValueKey('webplayer_${widget.video.videoId}');

    if (widget.embedded) {
      return KeyedSubtree(
        key: videoKey,
        child: WebViewWidget(controller: _controller),
      );
    }

    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final isSmallScreen = ResponsiveHelper.isSmallScreen(context);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: isLandscape
          ? null
          : AppBar(
              backgroundColor: Colors.black,
              elevation: 0,
              systemOverlayStyle: SystemUiOverlayStyle.light,
              title: Text(
                widget.video.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  overflow: TextOverflow.ellipsis,
                ),
                maxLines: 1,
              ),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.fullscreen, color: Colors.white),
                  onPressed: _toggleFullScreen,
                ),
              ],
            ),
      body: SafeArea(
        maintainBottomViewPadding: !isLandscape,
        child: Column(
          children: [
            Expanded(
              flex: isLandscape ? 1 : 0,
              child: Container(
                height: isLandscape
                    ? null
                    : MediaQuery.of(context).size.width * 9 / 16,
                width: MediaQuery.of(context).size.width,
                color: Colors.black,
                child: ClipRect(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: WebViewWidget(
                          controller: _controller,
                        ),
                      ),
                      if (_isLoading)
                        const Positioned.fill(
                          child: Center(
                            child: CircularProgressIndicator(
                              color: AppColors.buttonPrimary,
                            ),
                          ),
                        ),
                      if (isLandscape)
                        Positioned(
                          top: 12,
                          left: 12,
                          child: GestureDetector(
                            onTap: _toggleFullScreen,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.6),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.fullscreen_exit,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            if (!isLandscape)
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.video.title,
                        style: AppTextStyles.titleMedium.copyWith(
                          fontSize: isSmallScreen ? 16 : 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'المدة: ${widget.video.formattedDuration}',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: Colors.white70,
                          fontSize: isSmallScreen ? 12 : 14,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (widget.video.description != null &&
                          widget.video.description!.isNotEmpty)
                        Text(
                          widget.video.description!,
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: Colors.white70,
                            fontSize: isSmallScreen ? 12 : 14,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Add fallback widget when WebView is not available
  Widget _buildWebViewFallback() {
    return widget.embedded
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 32),
                const SizedBox(height: 16),
                const Text(
                  'مشغل الويب غير متاح على هذا الجهاز',
                  style: TextStyle(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DirectVideoPlayerScreen(
                          video: widget.video,
                          startPosition: _currentPosition,
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.buttonPrimary,
                  ),
                  child: const Text('استخدام مشغل Chewie بدلاً من ذلك'),
                ),
              ],
            ),
          )
        : Scaffold(
            backgroundColor: Colors.black,
            appBar: AppBar(
              backgroundColor: Colors.black,
              title: Text(widget.video.title,
                  style: const TextStyle(color: Colors.white)),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 48),
                  const SizedBox(height: 16),
                  const Text(
                    'مشغل الويب غير متاح على هذا الجهاز',
                    style: TextStyle(color: Colors.white, fontSize: 18),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DirectVideoPlayerScreen(
                            video: widget.video,
                            startPosition: _currentPosition,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.play_circle_filled),
                    label: const Text('استخدام مشغل Chewie بدلاً من ذلك'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.buttonPrimary,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                    ),
                  ),
                ],
              ),
            ),
          );
  }
}
