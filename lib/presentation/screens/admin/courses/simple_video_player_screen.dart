import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mycourses/core/config/bunny_config.dart';
import 'package:mycourses/core/constants/app_colors.dart';
import 'package:mycourses/core/constants/app_text_styles.dart';
import 'package:mycourses/core/services/course_videos_service.dart';
import 'package:mycourses/core/utils/drm_helper.dart' as drm;
import 'package:mycourses/models/course_video.dart';
import 'package:video_player/video_player.dart';
import 'package:webview_flutter/webview_flutter.dart';

class SimpleVideoPlayerScreen extends StatefulWidget {
  final CourseVideo video;
  final bool embedded;
  final Duration startPosition;
  final Function(dynamic controller)? onPlayerCreated;
  final Function(Duration position)? onPositionChanged;

  const SimpleVideoPlayerScreen({
    super.key,
    required this.video,
    this.embedded = false,
    this.startPosition = Duration.zero,
    this.onPlayerCreated,
    this.onPositionChanged,
  });

  @override
  State<SimpleVideoPlayerScreen> createState() =>
      _SimpleVideoPlayerScreenState();
}

class _SimpleVideoPlayerScreenState extends State<SimpleVideoPlayerScreen> {
  // Make controller nullable to avoid LateInitializationError
  VideoPlayerController? _controller;
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;
  Map<String, dynamic>? _videoDetails;
  int _retryCount = 0;
  bool _useMp4Fallback = false;
  String? _videoUrl;
  bool _isDrmProtected = false;
  bool _useWebViewPlayer = false;
  WebViewController? _webViewController;

  // Change platform detection to avoid Theme dependency in initState
  bool _isMobilePlatform = false;

  @override
  void initState() {
    super.initState();
    _isMobilePlatform =
        true; // Assume mobile by default, will update in didChangeDependencies
    _loadVideoDetailsAndInitialize();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Detect platform here after dependencies are available
    _isMobilePlatform = Theme.of(context).platform == TargetPlatform.android ||
        Theme.of(context).platform == TargetPlatform.iOS;

    // Update fallback setting based on platform if not already loading
    if (!_isLoading && _retryCount == 0) {
      _useMp4Fallback = _isMobilePlatform;
    }
  }

  Future<void> _loadVideoDetailsAndInitialize() async {
    try {
      // Check playback requirements using the helper
      final requirement =
          await drm.DrmHelper.getPlaybackRequirement(widget.video.videoId);

      setState(() {
        _isDrmProtected = requirement.isDrmProtected;
        _useWebViewPlayer = requirement.method == drm.PlaybackMethod.webEmbed;
        // Force HLS format for the test video ID since MP4 doesn't work for it
        _useMp4Fallback = requirement.format == drm.VideoFormat.mp4;
      });

      debugPrint('Playback method: ${requirement.method}');
      debugPrint('Video format: ${requirement.format}');
      debugPrint('DRM Protection: ${_isDrmProtected ? "Enabled" : "Disabled"}');
      debugPrint('Reason: ${requirement.reason}');

      // Get video details for additional info
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
      if (_useWebViewPlayer) {
        _initializeWebViewPlayer();
      } else {
        _initializeNativePlayer();
      }
    }
  }

  void _initializeWebViewPlayer() {
    try {
      final embedUrl = BunnyConfig.getEmbedUrl(widget.video.videoId);
      debugPrint('استخدام مشغل embed للفيديو المحمي: $embedUrl');

      final htmlContent = '''
      <!DOCTYPE html>
      <html>
      <head>
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <style>
          body, html { margin: 0; padding: 0; overflow: hidden; background-color: #000; height: 100vh; }
          iframe { width: 100%; height: 100%; border: none; }
        </style>
      </head>
      <body>
        <iframe 
          src="$embedUrl" 
          width="100%" 
          height="100%" 
          frameborder="0" 
          scrolling="no" 
          allow="autoplay; encrypted-media; accelerometer; gyroscope; picture-in-picture" 
          allowfullscreen>
        </iframe>
      </body>
      </html>
      ''';

      _webViewController = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.black)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageFinished: (_) {
              if (mounted) {
                setState(() {
                  _isLoading = false;
                });
              }
            },
            onWebResourceError: (error) {
              if (mounted) {
                setState(() {
                  _hasError = true;
                  _errorMessage =
                      'خطأ في تحميل مشغل الفيديو: ${error.description}';
                  _isLoading = false;
                });
              }
            },
          ),
        )
        ..loadHtmlString(htmlContent);
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = 'فشل في تهيئة مشغل الويب: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _initializeNativePlayer() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = null;
    });

    try {
      // For our test video, ALWAYS use HLS format since MP4 fails with 404
      String videoUrl;
      if (widget.video.videoId == '989b0866-b522-4c56-b7c3-487d858943ed') {
        // Force HLS for the test video
        videoUrl = BunnyConfig.getDirectVideoUrl(widget.video.videoId);
        _useMp4Fallback = false; // Ensure we use HLS
      } else {
        // For other videos, use format based on user preference
        videoUrl = _useMp4Fallback
            ? BunnyConfig.getDirectMp4Url(widget.video.videoId)
            : BunnyConfig.getDirectVideoUrl(widget.video.videoId);
      }

      if (videoUrl.isEmpty) {
        throw Exception('لم يتم العثور على رابط الفيديو الصحيح');
      }

      _videoUrl = videoUrl;
      debugPrint('استخدام عنوان URL للفيديو: $_videoUrl');

      // Add format hint for Android - ALWAYS use HLS for the test video
      final videoFormat = videoUrl.contains('m3u8') ||
              widget.video.videoId == '989b0866-b522-4c56-b7c3-487d858943ed'
          ? VideoFormat.hls
          : null;

      // Dispose previous controller if exists
      _controller?.dispose();

      // Enhanced HTTP headers to help with CORS and access issues
      final headers = {
        'Referer': 'https://bunny.net/',
        'Origin': 'https://bunny.net/',
        'User-Agent':
            'Mozilla/5.0 (Linux; Android 10; SM-G973F) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.120 Mobile Safari/537.36',
        'Content-Type':
            videoUrl.contains('m3u8') ? 'application/x-mpegURL' : 'video/mp4',
        'Access-Control-Allow-Origin': '*',
        'Accept': '*/*',
        'Connection': 'keep-alive',
      };

      // Add custom headers to bypass potential CORS and security issues
      _controller = VideoPlayerController.networkUrl(
        Uri.parse(videoUrl),
        formatHint: videoFormat,
        httpHeaders: headers,
      );

      // Add error listener before initialization
      _controller!.addListener(_onPlayerEvent);

      await _controller!.initialize();
      await _controller!.play();

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('خطأ في تهيئة مشغل الفيديو: $e');

      // Check if it's a 403/404 error for the test video - try WebView as fallback
      if ((e.toString().contains('403') || e.toString().contains('404')) &&
          widget.video.videoId == '989b0866-b522-4c56-b7c3-487d858943ed') {
        debugPrint('تم اكتشاف خطأ في الوصول للفيديو، التبديل إلى مشغل الويب');
        setState(() {
          _useWebViewPlayer = true;
        });
        _initializeWebViewPlayer();
        return;
      }

      // If we encounter other access issues, try the WebView player
      if (e.toString().contains('DRM') ||
          e.toString().contains('protected') ||
          e.toString().contains('encrypted') ||
          e.toString().contains('403') ||
          e.toString().contains('404')) {
        debugPrint('تم اكتشاف مشكلة في الوصول، التبديل إلى مشغل الويب');
        setState(() {
          _useWebViewPlayer = true;
        });
        _initializeWebViewPlayer();
        return;
      }

      // Automatic fallback strategy - don't try MP4 for the test video
      if (_retryCount < 2 &&
          widget.video.videoId != '989b0866-b522-4c56-b7c3-487d858943ed') {
        _retryCount++;

        // Toggle between HLS and MP4
        setState(() {
          _useMp4Fallback = !_useMp4Fallback;
        });

        await _retryWithDelay();
        return;
      }

      // As last resort for the test video, switch to WebView player
      if (widget.video.videoId == '989b0866-b522-4c56-b7c3-487d858943ed') {
        debugPrint('تعذر تشغيل الفيديو، التبديل إلى مشغل الويب');
        setState(() {
          _useWebViewPlayer = true;
        });
        _initializeWebViewPlayer();
        return;
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = 'فشل في تحميل الفيديو: $e';
        });
      }
    }
  }

  void _onPlayerEvent() {
    // Avoid null reference exceptions
    if (_controller == null) return;

    final error = _controller!.value.errorDescription;
    if (error != null && error.isNotEmpty) {
      debugPrint('خطأ في مشغل الفيديو: $error');

      // Only attempt fallback if we haven't exhausted retries
      if (_retryCount < 2 && mounted) {
        _retryCount++;
        setState(() {
          _useMp4Fallback = !_useMp4Fallback;
          _hasError = true;
          _errorMessage = 'فشل المشغل: $error';
        });

        _retryWithDelay();
      }
    }
  }

  Future<void> _retryWithDelay() async {
    await Future.delayed(const Duration(seconds: 1));
    if (mounted) {
      _initializeNativePlayer();
    }
  }

  String _getFormattedDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  void dispose() {
    if (_controller != null) {
      _controller!.removeListener(_onPlayerEvent);
      _controller!.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.black,
          statusBarIconBrightness: Brightness.light,
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          widget.video.title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
          ),
        ),
        actions: [
          if (_isDrmProtected)
            IconButton(
              icon: const Icon(Icons.lock, color: Colors.yellow),
              onPressed: null,
              tooltip: 'فيديو محمي بتقنية DRM',
            ),
          if (!_useWebViewPlayer)
            IconButton(
              icon: Icon(
                _useMp4Fallback ? Icons.high_quality : Icons.hd,
                color: Colors.white,
              ),
              onPressed: () {
                setState(() {
                  _useMp4Fallback = !_useMp4Fallback;
                });
                _retryCount = 0;
                _initializeNativePlayer();
              },
              tooltip: _useMp4Fallback ? 'تبديل إلى HLS' : 'تبديل إلى MP4',
            ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              setState(() {
                _isLoading = true;
                _hasError = false;
              });
              if (_useWebViewPlayer) {
                _initializeWebViewPlayer();
              } else {
                _initializeNativePlayer();
              }
            },
            tooltip: 'إعادة تحميل',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: _isLoading
                  ? const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.buttonPrimary),
                    )
                  : _hasError
                      ? _buildErrorWidget()
                      : _useWebViewPlayer
                          ? _buildWebViewPlayer()
                          : _buildVideoPlayerWidget(),
            ),
          ),
          if (!_useWebViewPlayer) _buildBasicControls(),
        ],
      ),
    );
  }

  Widget _buildWebViewPlayer() {
    if (_webViewController == null) {
      return const Center(
        child: Text(
          'خطأ في تهيئة مشغل الويب',
          style: TextStyle(color: Colors.white),
        ),
      );
    }

    return WebViewWidget(controller: _webViewController!);
  }

  Widget _buildVideoPlayerWidget() {
    // Add null check to prevent crashes
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Center(
        child: Text(
          'جاري تهيئة المشغل...',
          style: TextStyle(color: Colors.white),
        ),
      );
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        AspectRatio(
          aspectRatio: _controller!.value.aspectRatio,
          child: VideoPlayer(_controller!),
        ),
        if (!_controller!.value.isPlaying)
          Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.4),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              iconSize: 64,
              icon: const Icon(Icons.play_arrow, color: Colors.white),
              onPressed: () {
                setState(() {
                  _controller!.play();
                });
              },
            ),
          ),
      ],
    );
  }

  Widget _buildBasicControls() {
    // Add null check to prevent crashes
    if (_controller == null || !_controller!.value.isInitialized) {
      return const SizedBox.shrink();
    }

    return Container(
      color: Colors.black,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            icon: Icon(
              _controller!.value.isPlaying ? Icons.pause : Icons.play_arrow,
              color: Colors.white,
            ),
            onPressed: () {
              setState(() {
                _controller!.value.isPlaying
                    ? _controller!.pause()
                    : _controller!.play();
              });
            },
          ),
          Expanded(
            child: VideoProgressIndicator(
              _controller!,
              allowScrubbing: true,
              colors: const VideoProgressColors(
                playedColor: AppColors.buttonPrimary,
                bufferedColor: Colors.grey,
                backgroundColor: Colors.grey,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
          ),
          Text(
            '${_getFormattedDuration(_controller!.value.position)} / ${_getFormattedDuration(_controller!.value.duration)}',
            style: const TextStyle(color: Colors.white),
          ),
          IconButton(
            icon: const Icon(Icons.fullscreen, color: Colors.white),
            onPressed: () {
              // تنفيذ منطق ملء الشاشة هنا
              SystemChrome.setPreferredOrientations([
                DeviceOrientation.landscapeLeft,
                DeviceOrientation.landscapeRight,
              ]);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 48),
          const SizedBox(height: 16),
          Text(
            'فشل في تشغيل الفيديو',
            style: AppTextStyles.titleMedium.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 8),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              _errorMessage ?? 'حدث خطأ غير معروف',
              style: AppTextStyles.bodyMedium.copyWith(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),

          // Special message for test video regarding MP4 format
          if (widget.video.videoId == '989b0866-b522-4c56-b7c3-487d858943ed' &&
              _useMp4Fallback) ...[
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withOpacity(0.5)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.warning, color: Colors.orange, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'صيغة MP4 غير متاحة لهذا الفيديو',
                          style: const TextStyle(
                            color: Colors.orange,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'هذا الفيديو يدعم صيغة HLS فقط. يرجى استخدام صيغة HLS بدلاً من MP4.',
                    style:
                        TextStyle(color: Colors.orange.shade800, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // For DRM videos
          if (_isDrmProtected) ...[
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withOpacity(0.5)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.security,
                          color: Colors.orange, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'فيديو محمي بتقنية MediaCage DRM',
                          style: const TextStyle(
                            color: Colors.orange,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    drm.DrmHelper.getDrmInfoMessage(),
                    style:
                        TextStyle(color: Colors.orange.shade800, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _useWebViewPlayer = true;
                  _isLoading = true;
                  _hasError = false;
                });
                _initializeWebViewPlayer();
              },
              icon: const Icon(Icons.featured_play_list),
              label: const Text('استخدام مشغل Embed'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
            ),
          ] else if (widget.video.videoId ==
              '989b0866-b522-4c56-b7c3-487d858943ed') ...[
            // For test video, provide options to use WebView or try HLS
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _useMp4Fallback = false; // Force HLS
                      _retryCount = 0;
                      _isLoading = true;
                      _hasError = false;
                    });
                    _initializeNativePlayer();
                  },
                  icon: const Icon(Icons.video_library),
                  label: const Text('جرب صيغة HLS'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.buttonPrimary,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _useWebViewPlayer = true;
                      _isLoading = true;
                      _hasError = false;
                    });
                    _initializeWebViewPlayer();
                  },
                  icon: const Icon(Icons.web),
                  label: const Text('جرب مشغل الويب'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber.shade700,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                  ),
                ),
              ],
            ),
          ] else ...[
            // Standard toggle between HLS and MP4
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _useMp4Fallback = !_useMp4Fallback;
                  _retryCount = 0;
                  _isLoading = true;
                  _hasError = false;
                });
                _initializeNativePlayer();
              },
              icon: const Icon(Icons.refresh),
              label: Text(_useMp4Fallback
                  ? 'تجربة تشغيل بصيغة HLS'
                  : 'تجربة تشغيل بصيغة MP4'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.buttonPrimary,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'الصيغة الحالية: ${_useMp4Fallback ? 'MP4' : 'HLS'}',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],

          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('العودة للخلف'),
          ),
        ],
      ),
    );
  }
}
