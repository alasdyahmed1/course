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
  bool _isWebViewAvailable = true;

  int _errorCount = 0;
  bool _isVideoElementFound = false;
  bool _isRecoveringFromError = false;
  Timer? _videoElementCheckTimer;

  bool _disposed = false;
  int _videoJsCheckAttempts = 0;
  final int _maxVideoJsCheckAttempts = 5;
  Timer? _setupNavButtonsTimer;

  @override
  void initState() {
    super.initState();
    _positionTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (widget.onPositionChanged != null && !_disposed) {
        widget.onPositionChanged!(_currentPosition);
        _currentPosition = _currentPosition + const Duration(seconds: 1);
      }
    });

    _initializeController();
  }

  void _initializeController() {
    try {
// //debugPrint(
      //     '🎬 Initializing WebVideoPlayer for ${widget.video.title} at position: ${widget.startPosition.inSeconds}s');

      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.black)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageStarted: (String url) {
              if (mounted) {
                setState(() {
                  _isLoading = true;
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

                _startVideoElementCheck();
                _injectVideoJsCheck();

                Future.delayed(const Duration(milliseconds: 1000), () {
                  if (widget.startPosition.inSeconds > 0 && mounted) {
// //debugPrint(
                    //     '🎯 محاولة الانتقال إلى موقع التشغيل: ${widget.startPosition.inSeconds}s');
                    // _seekToPosition(widget.startPosition.inSeconds);

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
// //debugPrint('WebView error: ${error.description}');
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

      _controller.runJavaScript('''
        // Suppress most console messages
        window._suppressLogging = true;
        window.console = {
          log: function(msg) {
            if (!window._suppressLogging || 
                msg.includes('FLUTTER_POSITION_UPDATE') ||
                msg.includes('FLUTTER_NAVIGATE')) {
              console._log(msg);
            }
          },
          _log: console.log,
          warn: console.warn,
          error: console.error
        };
      ''');

      if (widget.onPlayerCreated != null) {
        Future.delayed(
            Duration.zero, () => widget.onPlayerCreated!(_controller));
      }
    } catch (e) {
// //debugPrint('WebView initialization error: $e');
      setState(() {
        _isWebViewAvailable = false;
        _isLoading = false;
      });
    }
  }

  void _handleWebViewError(WebResourceError error) {
    _errorCount++;

    bool isIgnorableError = error.description.contains('ERR_FAILED') &&
        !_isVideoElementFound &&
        _errorCount < 5;

    if (isIgnorableError) {
// //debugPrint('⚠️ خطأ غير مؤثر في WebView: ${error.description}');
    } else if (_errorCount >= 5 && !_isRecoveringFromError) {
      _isRecoveringFromError = true;
// //debugPrint('🔄 محاولة إعادة تحميل صفحة الفيديو بعد خطأ متكرر');

      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          _controller.reload();

          Future.delayed(const Duration(seconds: 1), () {
            _errorCount = 0;
            _isRecoveringFromError = false;
          });
        }
      });
    } else if (_errorCount >= 10) {
      if (mounted) {
        setState(() {
          _isWebViewAvailable = false;
          _isLoading = false;
        });
      }
    }
  }

  void _startVideoElementCheck() {
    _videoElementCheckTimer?.cancel();

    if (_disposed) return;

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
        if (typeof videojs !== 'undefined') {
          var player = videojs(document.querySelector('video'));
          if (player) {
            player.currentTime($seconds);
            console.log("تم الانتقال إلى الموقع: $seconds ثانية");
          }
        } else {
          console.log('Cannot seek: videojs not available yet');
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
    final videoId = widget.video.videoId;
    final libraryId = '399973';

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

  void _injectVideoJsCheck() {
    if (_disposed) return;

    _videoJsCheckAttempts++;

    _controller.runJavaScript('''
      window._suppressVideoJsLogs = true;
      
      try {
        if (typeof videojs === 'undefined') {
          if (!window._suppressVideoJsLogs) {
            console.log('videojs is not available yet, will retry later');
          }
          
          window._flutterVideoJsChecksComplete = false;
          
          if ($_videoJsCheckAttempts < $_maxVideoJsCheckAttempts) {
            setTimeout(function() {
              if (typeof videojs !== 'undefined') {
                console.log('videojs is now available');
                window._flutterVideoJsChecksComplete = true;
                setupCustomNavigationButtons();
              } else {
                if (!window._suppressVideoJsLogs) {
                  console.log('videojs is still not available after delay');
                }
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

    _clearSetupNavButtonsTimer();
    if (_videoJsCheckAttempts < _maxVideoJsCheckAttempts) {
      _setupNavButtonsTimer =
          Timer.periodic(const Duration(seconds: 8), (timer) {
        if (_disposed || _videoJsCheckAttempts >= _maxVideoJsCheckAttempts) {
          timer.cancel();
          return;
        }

        _controller.runJavaScript('''
          if (!window._flutterVideoJsChecksComplete) {
            if (!window._suppressVideoJsLogs) {
              console.log("ما زالت محاولات التحقق من videojs قيد التنفيذ");
            }
          } else {
            setupCustomNavigationButtons();
          }
        ''');
      });
    }

    _injectSimpleControls();
  }

  void _injectSimpleControls() {
    if (_disposed) return;

    _controller.runJavaScript('''
      window._suppressLogging = true;
      
      function safeVideoJs(callback) {
        if (typeof videojs !== 'undefined') {
          try {
            callback();
          } catch(e) {
            if (!window._suppressLogging) {
              console.error("Error in videojs callback:", e);
            }
          }
        } else {
          if (!window._suppressLogging) {
            console.log("videojs not available for operation");
          }
        }
      }
      
      document.addEventListener('fullscreenchange', function() {
        if (document.fullscreenElement) {
          console.log("FLUTTER_FULLSCREEN_ENTER");
        } else {
          console.log("FLUTTER_FULLSCREEN_EXIT");
        }
      });
      
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

      if (typeof window.setupNavButtonsAttempts === 'undefined') {
        window.setupNavButtonsAttempts = 0;
      }
      
      window.setupCustomNavigationButtons = function() {
        window.setupNavButtonsAttempts++;
        
        if (!window._suppressLogging) {
          console.log("Setting up CUSTOM navigation buttons: hasPrevious=${widget.hasPreviousVideo}, hasNext=${widget.hasNextVideo}, attempt " + window.setupNavButtonsAttempts);
        }
        
        if (window.setupNavButtonsAttempts > 10) {
          console.log("تم الوصول للحد الأقصى من محاولات إعداد أزرار التنقل");
          return;
        }
        
        var player = document.querySelector('video');
        if (!player) {
          if (!window._suppressLogging) {
            console.log("Video element not found, retrying in 1s...");
          }
          setTimeout(setupCustomNavigationButtons, 1000);
          return;
        }
        
        var videoContainer = document.querySelector('.video-js');
        if (!videoContainer) {
          if (!window._suppressLogging) {
            console.log("Video container not found, retrying in 1s...");
          }
          setTimeout(setupCustomNavigationButtons, 1000);
          return;
        }
        
        var existingNavControls = document.querySelector('.custom-nav-controls');
        if (existingNavControls) {
          existingNavControls.remove();
        }
        
        var navControls = document.createElement('div');
        navControls.className = 'custom-nav-controls';
        
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
          var dummyPrev = document.createElement('div');
          dummyPrev.style.width = '50px';
          navControls.appendChild(dummyPrev);
        }
        
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
          var dummyNext = document.createElement('div');
          dummyNext.style.width = '50px';
          navControls.appendChild(dummyNext);
        }
        
        videoContainer.appendChild(navControls);
        
        if (!window._suppressLogging) {
          console.log("Custom navigation buttons setup complete");
        }
      }
      
      setupCustomNavigationButtons();
      setTimeout(setupCustomNavigationButtons, 2000);
      setTimeout(setupCustomNavigationButtons, 5000);
      
      if (typeof window.positionUpdateInterval !== 'undefined') {
        clearInterval(window.positionUpdateInterval);
      }
      
      window.positionUpdateInterval = setInterval(function() {
        if (window.videoPlayerStopped) {
          clearInterval(window.positionUpdateInterval);
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
      }, 5000);
    ''');

    _setupConsoleMessageListener();

    _injectNavigationButtons();
  }

  void _injectNavigationButtons() {
    final hasPreviousJS = widget.hasPreviousVideo ? 'true' : 'false';
    final hasNextJS = widget.hasNextVideo ? 'true' : 'false';

    final jsCode = '''
      var styleElement = document.createElement('style');
      styleElement.textContent = `
        .bunny-nav-controls {
          position: absolute;
          top: 50%;
          width: 100%;
          z-index: 10;
          pointer-events: none;
          display: flex;
          justify-content: space-between;
          padding: 0 20px;
          box-sizing: border-box;
          opacity: 0;
          transition: opacity 0.3s ease-in-out;
          transform: translateY(-50%);
        }

        .video-js:hover .bunny-nav-controls {
          opacity: 1;
        }

        .bunny-nav-button {
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
        }

        .bunny-nav-button:hover {
          background-color: rgba(0, 128, 255, 0.8);
          transform: scale(1.1);
        }

        .bunny-nav-button svg {
          width: 24px;
          height: 24px;
          fill: currentColor;
        }
      `;
      document.head.appendChild(styleElement);

      function createNavigationButtons() {
        var videoContainer = document.querySelector('.video-js');
        if (!videoContainer) return;

        if (document.querySelector('.bunny-nav-controls')) return;

        var navControls = document.createElement('div');
        navControls.className = 'bunny-nav-controls';

        if ($hasPreviousJS) {
          var prevButton = document.createElement('button');
          prevButton.className = 'bunny-nav-button bunny-prev-button';
          prevButton.innerHTML = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><path d="M15.41 7.41L14 6l-6 6 6 6 1.41-1.41L10.83 12z"/></svg>';
          prevButton.setAttribute('title', 'الفيديو السابق');
          prevButton.onclick = function() {
            console.log("FLUTTER_NAVIGATE_PREVIOUS");
          };
          navControls.appendChild(prevButton);
        } else {
          var dummyPrev = document.createElement('div');
          dummyPrev.style.width = '50px';
          navControls.appendChild(dummyPrev);
        }

        if ($hasNextJS) {
          var nextButton = document.createElement('button');
          nextButton.className = 'bunny-nav-button bunny-next-button';
          nextButton.innerHTML = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><path d="M10 6L8.59 7.41 13.17 12l-4.58 4.59L10 18l6-6z"/></svg>';
          nextButton.setAttribute('title', 'الفيديو التالي');
          nextButton.onclick = function() {
            console.log("FLUTTER_NAVIGATE_NEXT");
          };
          navControls.appendChild(nextButton);
        } else {
          var dummyNext = document.createElement('div');
          dummyNext.style.width = '50px';
          navControls.appendChild(dummyNext);
        }

        videoContainer.appendChild(navControls);
      }

      createNavigationButtons();
      setTimeout(createNavigationButtons, 1000);
      setTimeout(createNavigationButtons, 3000);
    ''';

    _controller.runJavaScript(jsCode);
  }

  void _setupConsoleMessageListener() {
    _controller = _controller
      ..setOnConsoleMessage((JavaScriptConsoleMessage consoleMessage) {
        final message = consoleMessage.message;

        if (message.contains('videojs not available') ||
            message.contains('Video container not found') ||
            message.contains('videojs is not available') ||
            message.contains('Setting up CUSTOM navigation buttons')) {
          return;
        }

        if (message.contains('FLUTTER_FULLSCREEN_ENTER')) {
          _handleFullscreenChange(true);
        } else if (message.contains('FLUTTER_FULLSCREEN_EXIT')) {
          _handleFullscreenChange(false);
        } else if (message.contains('FLUTTER_NAVIGATE_NEXT')) {
          if (widget.onNextVideo != null && widget.hasNextVideo) {
            widget.onNextVideo!();
          }
        } else if (message.contains('FLUTTER_NAVIGATE_PREVIOUS')) {
          if (widget.onPreviousVideo != null && widget.hasPreviousVideo) {
            widget.onPreviousVideo!();
          }
        } else if (message.contains('FLUTTER_POSITION_UPDATE:')) {
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
          } catch (e) {}
        } else if (message.contains('VIDEO_ELEMENT_FOUND')) {
          _isVideoElementFound = true;
          if (_videoElementCheckTimer != null) {
            _videoElementCheckTimer!.cancel();
            _videoElementCheckTimer = null;
          }
        }

        _setupMessageListener();
      });
  }

  void _setupMessageListener() {
    _controller.runJavaScript('''
      window.addEventListener('message', function(event) {
        if (event.data === 'BUNNY_PREV_VIDEO') {
          console.log("FLUTTER_NAVIGATE_PREVIOUS");
        } else if (event.data === 'BUNNY_NEXT_VIDEO') {
          console.log("FLUTTER_NAVIGATE_NEXT");
        }
      });
    ''');
  }

  void _handleFullscreenChange(bool isEntering) {
    if (isEntering) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

      if (!_isFullScreen && mounted) {
        setState(() {
          _isFullScreen = true;
        });
      }
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

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
      setState(() {
        _isFullScreen = !_isFullScreen;
      });
    }
  }

  void _clearSetupNavButtonsTimer() {
    if (_setupNavButtonsTimer != null) {
      _setupNavButtonsTimer!.cancel();
      _setupNavButtonsTimer = null;
    }
  }

  @override
  void dispose() {
    _disposed = true;

    _positionTimer?.cancel();
    _videoElementCheckTimer?.cancel();
    _clearSetupNavButtonsTimer();

    if (widget.onPositionChanged != null) {
      widget.onPositionChanged!(_currentPosition);
    }

    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    try {
      _controller.runJavaScript('''
        try {
          window.videoPlayerStopped = true;
          window._suppressLogging = true;
          
          if (window.positionUpdateInterval) {
            clearInterval(window.positionUpdateInterval);
          }
          
          if (typeof videojs !== 'undefined') {
            var player = videojs(document.querySelector('video'));
            if (player) {
              player.pause();
              if (player.dispose) {
                player.dispose();
              }
            }
          }
          
          var videoElements = document.querySelectorAll('video');
          videoElements.forEach(function(video) {
            if (video.pause) {
              video.onplay = null;
              video.onpause = null;
              video.ontimeupdate = null;
              video.onerror = null;
              video.pause();
              video.src = '';
              video.load();
            }
          });
          
          var navControls = document.querySelector('.custom-nav-controls');
          if (navControls) {
            navControls.remove();
          }
        } catch(e) {
        }
      ''');
    } catch (e) {
//debugPrint('خطأ عند محاولة تنظيف WebView: $e');
    }

    try {
      _controller.loadRequest(Uri.parse('about:blank'));
    } catch (e) {
//debugPrint('خطأ عند محاولة إعادة تعيين WebView: $e');
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isWebViewAvailable) {
      return _buildWebViewFallback();
    }

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
                      if (widget.video.description.isNotEmpty)
                        Text(
                          widget.video.description,
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
