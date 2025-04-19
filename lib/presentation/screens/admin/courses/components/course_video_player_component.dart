import 'package:flutter/material.dart';
import 'package:mycourses/models/course_video.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

/// Component responsible for rendering different types of video players
class CourseVideoPlayerComponent {
  static final Map<String, dynamic> _cachedControllers = {};
  static bool _webViewPlatformInitialized = false;

  /// Builds a video player based on the specified type
  static Widget buildPlayerByType({
    required BuildContext context,
    required CourseVideo? selectedVideo,
    required String playerType,
    required Duration startPosition,
    required bool isNavigating,
    required Map<String, Duration> videoPositions,
    required CourseVideo? Function() findPreviousVideo,
    required CourseVideo? Function() findNextVideo,
    required VoidCallback navigateToPreviousVideo,
    required VoidCallback navigateToNextVideo,
    required Function(dynamic) onPlayerCreated,
    required Function(Duration) onPositionChanged,
  }) {
    if (selectedVideo == null) {
      return const Center(child: Text('لم يتم تحديد الفيديو'));
    }

    // Initialize WebView platform if needed
    if (!_webViewPlatformInitialized) {
      WebViewPlatform.instance = AndroidWebViewPlatform();
      _webViewPlatformInitialized = true;
    }

    debugPrint(
        '🎬 بناء مشغل فيديو جديد للفيديو: ${selectedVideo.id}, نوع المشغل: $playerType');

    // For simplicity, in this fix we'll focus on the iframe player
    // as it's causing the most issues
    if (playerType == 'iframe') {
      return _buildIframePlayer(
        context: context,
        selectedVideo: selectedVideo,
        startPosition: startPosition,
        onPlayerCreated: onPlayerCreated,
        onPositionChanged: onPositionChanged,
      );
    }

    // Placeholder for other player types
    return Center(
      child: Text('مشغل غير مدعوم: $playerType'),
    );
  }

  /// Builds an iframe-based player using WebView
  static Widget _buildIframePlayer({
    required BuildContext context,
    required CourseVideo selectedVideo,
    required Duration startPosition,
    required Function(dynamic) onPlayerCreated,
    required Function(Duration) onPositionChanged,
  }) {
    debugPrint('🎬 Building iframe player for video: ${selectedVideo.title}');
    debugPrint('⏱️ Start position: ${startPosition.inSeconds}s');

    final cacheKey = 'iframe_${selectedVideo.id}';
    final embedUrl = _getEmbedUrl(selectedVideo, startPosition);

    debugPrint('🔗 Generated URL: $embedUrl');

    final controller = _initializeWebViewController(
      cacheKey,
      embedUrl,
      onPlayerCreated,
    );

    debugPrint('🎮 WebView controller initialized');

    return WebViewWidget(
      key: ValueKey(
          'webview_${selectedVideo.id}_${DateTime.now().millisecondsSinceEpoch}'),
      controller: controller,
    );
  }

  /// Initialize or reuse a WebViewController for better memory management
  static WebViewController _initializeWebViewController(
    String cacheKey,
    String url,
    Function(dynamic) onControllerCreated,
  ) {
    // Clear old controllers if too many are cached (prevent memory leaks)
    if (_cachedControllers.length > 3) {
      final oldestKey = _cachedControllers.keys.first;
      _cachedControllers.remove(oldestKey);
    }

    // Create new controller with proper settings
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (url) {
            debugPrint('📄 Finished loading: $url');
          },
          onWebResourceError: (error) {
            debugPrint('🚨 WebView error: ${error.description}');
          },
        ),
      )
      ..loadRequest(Uri.parse(url));

    // Cache the controller
    _cachedControllers[cacheKey] = controller;

    // Notify listener about controller creation
    onControllerCreated(controller);

    return controller;
  }

  /// Generate proper embed URL for video
  static String _getEmbedUrl(CourseVideo video, Duration startPosition) {
    // Sample URL generation - replace with your actual embed URL logic
    final baseUrl =
        'https://iframe.mediadelivery.net/embed/399973/${video.videoId}';
    final params =
        'autoplay=true&muted=false&loop=false&preload=true&responsive=true'
        '&background=000000&startTime=${startPosition.inSeconds}'
        '&backward=true&forward=true&fullscreenButton=true&controls=true'
        '&t=${DateTime.now().millisecondsSinceEpoch}';

    return '$baseUrl?$params';
  }
}
