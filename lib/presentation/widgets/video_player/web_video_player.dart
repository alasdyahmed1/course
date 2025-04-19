import 'dart:async';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// إعدادات مشغل الفيديو على الويب
class WebVideoPlayerSettings {
  /// تمكين/تعطيل تسجيل التشخيص
  final bool debugLogging;

  /// الحد الأقصى لمحاولات التنقل بين الفيديوهات
  final int maxNavigationAttempts;

  /// تسجيل محاولات التنقل
  final bool logNavigationAttempts;

  /// الحد الأقصى لمحاولات التحقق من توفر videojs
  final int maxVideoJsCheckAttempts;

  /// الفترة الزمنية بين محاولات التحقق (بالثواني)
  final int videoJsCheckInterval;

  const WebVideoPlayerSettings({
    this.debugLogging = false,
    this.maxNavigationAttempts = 5,
    this.logNavigationAttempts = false,
    this.maxVideoJsCheckAttempts = 3, // تقليل عدد المحاولات
    this.videoJsCheckInterval = 8, // زيادة الفاصل الزمني
  });
}

/// مشغل الفيديو المستند إلى WebView
class WebVideoPlayer {
  /// وحدة التحكم في WebView
  final WebViewController controller;

  /// معرف الفيديو
  final String videoId;

  /// معرف المكتبة
  final String libraryId;

  /// الموقع الابتدائي للتشغيل
  final Duration startPosition;

  /// وظيفة ليتم استدعاؤها عند تغيير الموقع
  final Function(Duration)? onPositionChanged;

  /// إعدادات المشغل
  final WebVideoPlayerSettings? settings;

  /// هل للفيديو فيديو سابق
  final bool hasPreviousVideo;

  /// هل للفيديو فيديو تالي
  final bool hasNextVideo;

  /// وظيفة للانتقال للفيديو السابق
  final VoidCallback? onPreviousVideo;

  /// وظيفة للانتقال للفيديو التالي
  final VoidCallback? onNextVideo;

  bool _isDisposed = false;
  int _videoJsCheckAttempts = 0;
  Timer? _positionUpdateTimer;
  Timer? _navigationSetupTimer;
  Duration _currentPosition = Duration.zero;

  WebVideoPlayer({
    required this.controller,
    required this.videoId,
    this.libraryId = "399973",
    this.startPosition = Duration.zero,
    this.onPositionChanged,
    this.settings,
    this.hasPreviousVideo = false,
    this.hasNextVideo = false,
    this.onPreviousVideo,
    this.onNextVideo,
  }) {
    _currentPosition = startPosition;
    _setupPlayer();
  }

  /// إعداد المشغل وعناصر التحكم
  void _setupPlayer() {
    // التحقق من توفر videojs بشكل متكيف
    _checkVideoJsAvailability();

    // إعداد مؤقت لتحديث الموقع
    _positionUpdateTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!_isDisposed) {
        controller.runJavaScript('''
          try {
            if (typeof videojs !== 'undefined') {
              var player = videojs(document.querySelector('video'));
              if (player && !isNaN(player.currentTime()) && player.currentTime() > 0) {
                console.log("FLUTTER_POSITION_UPDATE:" + player.currentTime());
              }
            } else {
              var videoElement = document.querySelector('video');
              if (videoElement && !isNaN(videoElement.currentTime) && videoElement.currentTime > 0) {
                console.log("FLUTTER_POSITION_UPDATE:" + videoElement.currentTime);
              }
            }
          } catch(e) {
            // صامتة - تجنب طباعة الأخطاء
          }
        ''');
      }
    });
  }

  /// التحقق من توفر videojs بطريقة محسنة
  void _checkVideoJsAvailability() {
    if (_isDisposed) return;

    final maxAttempts =
        settings?.maxVideoJsCheckAttempts ?? 3; // تقليل المحاولات
    final debugLogging = settings?.debugLogging ?? false;

    _videoJsCheckAttempts++;

    if (_videoJsCheckAttempts > maxAttempts) {
      // التوقف عن المحاولات بعد الوصول إلى الحد الأقصى
      if (debugLogging) {
        debugPrint(
            '🎬 توقف عن محاولات التحقق من توفر videojs (تجاوز الحد الأقصى للمحاولات)');
      }
      return;
    }

    controller.runJavaScript('''
      // منع الرسائل المتكررة في وحدة التحكم
      window._videoJsDebugEnabled = false;
      
      try {
        if (typeof videojs === 'undefined') {
          // تعيين متغير عالمي ليتم استخدامه في التحقق
          window._flutterVideoJsAvailable = false;
          
          // محاولة إعداد الفيديو باستخدام عناصر HTML5 الأساسية
          var videoElement = document.querySelector('video');
          if (videoElement) {
            if (window._videoJsDebugEnabled) console.log('تم العثور على عنصر فيديو HTML5');
            
            // تسجيل أحداث التقدم للفيديو
            if (!videoElement._eventAdded) {
              videoElement._eventAdded = true;
              videoElement.ontimeupdate = function() {
                if (this.currentTime > 0) {
                  console.log("FLUTTER_POSITION_UPDATE:" + this.currentTime);
                }
              };
            }
            
            // إعداد أزرار التنقل البسيطة
            setupSimpleNavigationButtons();
          }
        } else {
          if (window._videoJsDebugEnabled) console.log('تم العثور على videojs، تكوين المشغل');
          window._flutterVideoJsAvailable = true;
          setupNavigationButtons();
        }
      } catch(e) {
        // تجاهل أخطاء التنفيذ لتجنب الرسائل المتكررة
      }
      
      // إضافة متغير عالمي للتحكم في عدد المحاولات
      if (!window._setupAttemptsCount) window._setupAttemptsCount = 0;
      
      // دالة بسيطة لإعداد أزرار التنقل مع عناصر HTML األصلية
      function setupSimpleNavigationButtons() {
        if (window._navigButtonsSetup) return;
        window._navigButtonsSetup = true;
        
        try {
          var container = document.querySelector('.vjs-control-bar') || 
                        document.querySelector('.video-js') || 
                        document.querySelector('video').parentElement;
          
          if (container) {
            var controls = document.createElement('div');
            controls.style.position = 'absolute';
            controls.style.top = '50%';
            controls.style.width = '100%';
            controls.style.zIndex = '10';
            
            // CSS للأزرار
            var style = document.createElement('style');
            style.textContent = '.nav-btn {opacity:0.7; background:rgba(0,0,0,0.5); color:white; border-radius:50%;}';
            document.head.appendChild(style);
            
            // إضافة الأزرار حسب الحاجة
            var hasButtons = false;
            
            if ($hasPreviousVideo) {
              var prevBtn = document.createElement('button');
              prevBtn.className = 'nav-btn';
              prevBtn.innerHTML = '←';
              prevBtn.onclick = function() {
                console.log("FLUTTER_NAVIGATE_PREVIOUS");
              };
              hasButtons = true;
            }
            
            if ($hasNextVideo) {
              var nextBtn = document.createElement('button');
              nextBtn.className = 'nav-btn';
              nextBtn.innerHTML = '→';
              nextBtn.onclick = function() {
                console.log("FLUTTER_NAVIGATE_NEXT");
              };
              hasButtons = true;
            }
            
            if (hasButtons) {
              container.appendChild(controls);
            }
          }
        } catch(e) {
          // تجاهل الأخطاء
        }
      }
      
      // تحسين دالة إعداد أزرار التنقل للحد من المحاولات
      function setupNavigationButtons() {
        window._setupAttemptsCount++;
        
        if (window._setupAttemptsCount > ${settings?.maxNavigationAttempts ?? 5} || window._navigButtonsSetup) {
          return;
        }
        
        try {
          var videoContainer = document.querySelector('.video-js');
          if (!videoContainer) {
            if (window._videoJsDebugEnabled) {
              console.log("Video container not found, will retry automatically");
            }
            window._navigButtonsSetup = false;
            return;
          }
          
          window._navigButtonsSetup = true;
          
          // إضافة أزرار التنقل
          if ($hasPreviousVideo || $hasNextVideo) {
            var navControls = document.createElement('div');
            navControls.className = 'custom-nav-controls';
            navControls.style.position = 'absolute';
            navControls.style.top = '50%';
            navControls.style.width = '100%';
            navControls.style.zIndex = '2';
            navControls.style.pointerEvents = 'none';
            
            // إضافة الأزرار للتنقل بين الفيديوهات
            // ...
          }
        } catch(e) {
          // تجاهل الأخطاء
        }
      }
    ''');

    // زيادة الفاصل الزمني بين المحاولات لتقليل عدد الرسائل
    final interval =
        settings?.videoJsCheckInterval ?? 8; // زيادة الفترة بين المحاولات

    Future.delayed(Duration(seconds: interval), () {
      if (!_isDisposed) {
        _checkVideoJsAvailability();
      }
    });
  }

  /// إعداد أزرار التنقل بين الفيديوهات
  void _setupNavigationControls() {
    if (_isDisposed) return;

    final maxAttempts = settings?.maxNavigationAttempts ?? 5;
    final shouldLog = settings?.logNavigationAttempts ?? false;

    // إلغاء المؤقت السابق إن وجد
    _navigationSetupTimer?.cancel();

    // إعداد مؤقت لمحاولات قليلة ومتباعدة
    int attempts = 0;
    _navigationSetupTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      // زيادة الفاصل الزمني
      attempts++;

      if (attempts > maxAttempts || _isDisposed) {
        timer.cancel();
        return;
      }

      controller.runJavaScript('''
        var shouldLog = $shouldLog;
        if (!window._navigButtonsSetup) {
          if (typeof setupSimpleNavigationButtons === 'function') {
            setupSimpleNavigationButtons();
          } else if (typeof setupNavigationButtons === 'function') {
            setupNavigationButtons();
          }
        }
      ''');
    });
  }

  /// الانتقال إلى موقع محدد في الفيديو
  void seekTo(Duration position) {
    if (_isDisposed) return;

    final seconds = position.inSeconds;
    if (seconds <= 0) return;

    controller.runJavaScript('''
      try {
        if (typeof videojs !== 'undefined') {
          var player = videojs(document.querySelector('video'));
          if (player) {
            player.currentTime($seconds);
          }
        } else {
          var videoElement = document.querySelector('video');
          if (videoElement) {
            videoElement.currentTime = $seconds;
          }
        }
      } catch(e) {
        // تجاهل الأخطاء
      }
    ''');
  }

  /// تشغيل الفيديو
  void play() {
    if (_isDisposed) return;

    controller.runJavaScript('''
      try {
        if (typeof videojs !== 'undefined') {
          var player = videojs(document.querySelector('video'));
          if (player) player.play();
        } else {
          var video = document.querySelector('video');
          if (video) video.play();
        }
      } catch(e) {
        // تجاهل الأخطاء
      }
    ''');
  }

  /// إيقاف الفيديو مؤقتًا
  void pause() {
    if (_isDisposed) return;

    controller.runJavaScript('''
      try {
        if (typeof videojs !== 'undefined') {
          var player = videojs(document.querySelector('video'));
          if (player) player.pause();
        } else {
          var video = document.querySelector('video');
          if (video) video.pause();
        }
      } catch(e) {
        // تجاهل الأخطاء
      }
    ''');
  }

  /// تنظيف الموارد
  void dispose() {
    _isDisposed = true;
    _positionUpdateTimer?.cancel();
    _navigationSetupTimer?.cancel();

    // تنظيف JavaScript بشكل أكثر فعالية
    controller.runJavaScript('''
      try {
        window._flutterVideoPlayerDisposed = true;
        window._navigButtonsSetup = false;
        window._setupAttemptsCount = 0;
        
        if (typeof videojs !== 'undefined') {
          var player = videojs(document.querySelector('video'));
          if (player) {
            player.pause();
            if (player.dispose) player.dispose();
          }
        }
        
        var videoElement = document.querySelector('video');
        if (videoElement) {
          videoElement.pause();
          videoElement.src = '';
          videoElement.load();
          if (videoElement.ontimeupdate) videoElement.ontimeupdate = null;
        }
      } catch(e) {
        // تجاهل الأخطاء عند التنظيف
      }
    ''');

    // إعلام المستمع بآخر موقع
    if (onPositionChanged != null) {
      onPositionChanged!(_currentPosition);
    }

    // إعادة تعيين المتصفح إلى صفحة فارغة
    controller.loadRequest(Uri.parse('about:blank'));
  }
}
