import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mycourses/core/config/bunny_config.dart';
import 'package:mycourses/core/constants/app_colors.dart';
import 'package:mycourses/core/constants/app_text_styles.dart';
import 'package:mycourses/core/services/course_videos_service.dart';
import 'package:mycourses/models/course_video.dart';
import 'package:mycourses/presentation/widgets/custom_progress_indicator.dart';
import 'package:webview_flutter/webview_flutter.dart';

class VideoPlayerScreen extends StatefulWidget {
  final CourseVideo video;

  const VideoPlayerScreen({
    super.key,
    required this.video,
  });

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  bool _isLoading = true;
  late WebViewController _webViewController;
  String? _errorMessage;
  final bool _usingDirectVideo = true; // استخدام مشغل الفيديو المباشر كافتراضي
  Map<String, dynamic>? _videoDetails;

  @override
  void initState() {
    super.initState();
    _loadVideoDetails();
  }

  Future<void> _loadVideoDetails() async {
    try {
      // محاولة الحصول على تفاصيل إضافية عن الفيديو
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
      _initializeWebView();
    }
  }

  void _initializeWebView() {
    try {
      final videoId = widget.video.videoId;
      final libraryId = BunnyConfig.libraryId;

      if (videoId.isEmpty || libraryId == null) {
        setState(() {
          _errorMessage = 'معرف الفيديو أو المكتبة غير موجود';
          _isLoading = false;
        });
        return;
      }

      // تعديل نوع المحتوى لمنع مشكلة CORS وخطأ ERR_BLOCKED_BY_ORB
      final htmlContent = _getDirectPlayerHtml(videoId);

      _webViewController = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.black)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageStarted: (_) {
              debugPrint('بدأ تحميل الصفحة...');
            },
            onPageFinished: (_) {
              if (mounted) {
                setState(() {
                  _isLoading = false;
                });
              }
              debugPrint('اكتمل تحميل الصفحة');
            },
            onWebResourceError: (error) {
              debugPrint(
                  'خطأ في تحميل المورد: ${error.description}, كود الخطأ: ${error.errorCode}');

              if (mounted) {
                setState(() {
                  _isLoading = false;
                  _errorMessage = 'فشل في تحميل الفيديو: ${error.description}';
                });
              }
            },
          ),
        )
        // استخدام الملف المحلي للمشغل بدلاً من الاعتماد على محتوى الويب
        ..loadHtmlString(htmlContent, baseUrl: 'https://localhost');
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  // إنشاء HTML لمشغل HLS مباشر - تحديث لمعالجة مشكلة CORS
  String _getDirectPlayerHtml(String videoId) {
    final directUrl = BunnyConfig.getDirectVideoUrl(videoId);
    final thumbnailUrl = BunnyConfig.getThumbnailUrl(videoId);
    final mp4Url = BunnyConfig.getDirectMp4Url(videoId); // Add MP4 fallback
    final cacheBuster = DateTime.now().millisecondsSinceEpoch;
    final videoTitle = _videoDetails != null && _videoDetails!['title'] != null
        ? _videoDetails!['title']
        : widget.video.title;

    // استخدام مشغل Plyr الأبسط بدلاً من VideoJS لتقليل مشاكل التوافق
    return '''
      <!DOCTYPE html>
      <html>
      <head>
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <meta http-equiv="Content-Security-Policy" content="default-src * 'self' 'unsafe-inline' 'unsafe-eval' data: blob: filesystem: ws: gap: https://*.${BunnyConfig.streamHostname} https://${BunnyConfig.streamHostname}">
        <style>
          body { margin: 0; padding: 0; overflow: hidden; background-color: #000; height: 100vh; }
          #player { width: 100%; height: 100%; }
          video { width: 100%; height: 100%; outline: none; }
          .error-container {
            display: flex;
            flex-direction: column;
            align-items: center;
            justify-content: center;
            height: 100vh;
            color: white;
            text-align: center;
            padding: 0 20px;
          }
          .retry-button {
            margin-top: 20px;
            padding: 10px 20px;
            background-color: #0567FF;
            border: none;
            border-radius: 4px;
            color: white;
            font-weight: bold;
            cursor: pointer;
          }
          #fallbackBtn {
            margin-top: 10px;
            padding: 8px 16px;
            background-color: transparent;
            border: 1px solid #0567FF;
            border-radius: 4px;
            color: white;
            font-weight: bold;
            cursor: pointer;
          }
        </style>
      </head>
      <body>
        <div id="player">
          <video id="video" controls autoplay poster="$thumbnailUrl">
            <source id="hlsSource" src="$directUrl" type="application/x-mpegURL">
            <source id="mp4Source" src="$mp4Url" type="video/mp4">
            لا يمكن تشغيل الفيديو على متصفحك
          </video>
        </div>

        <script>
          // تعامل مع أخطاء تحميل الفيديو
          const video = document.getElementById('video');
          let usingHls = true;
          
          video.addEventListener('error', function(e) {
            console.error('Video error:', e);
            tryFallbackSource();
          });
          
          function tryFallbackSource() {
            if (usingHls) {
              console.log('Trying MP4 fallback');
              usingHls = false;
              document.getElementById('hlsSource').remove();
              video.load();
              video.play().catch(err => {
                console.error('Failed to play MP4:', err);
                showErrorMessage('حدث خطأ أثناء تشغيل الفيديو، يرجى المحاولة لاحقاً');
              });
            } else {
              showErrorMessage('حدث خطأ أثناء تحميل الفيديو');
            }
          }
          
          function showErrorMessage(errorMessage) {
            const player = document.getElementById('player');
            player.innerHTML = `
              <div class="error-container">
                <div style="font-size: 48px; margin-bottom: 20px;">❌</div>
                <h2>\${errorMessage}</h2>
                <p>فشل في تشغيل: $videoTitle</p>
                <button class="retry-button" onclick="location.reload()">إعادة المحاولة</button>
                <button id="fallbackBtn">تجربة طريقة أخرى</button>
              </div>
            `;
            
            // Add event listener to the fallback button
            document.getElementById('fallbackBtn').addEventListener('click', function() {
              window.flutter_inappwebview.callHandler('switchPlayer');
            });
          }
        </script>
      </body>
      </html>
    ''';
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
          _videoDetails != null && _videoDetails!['title'] != null
              ? _videoDetails!['title']
              : widget.video.title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              setState(() {
                _isLoading = true;
                _errorMessage = null;
              });
              _initializeWebView();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CustomProgressIndicator())
                : _errorMessage != null
                    ? _buildErrorState()
                    : WebViewWidget(controller: _webViewController),
          ),
          _buildVideoInfo(),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              'فشل في تشغيل الفيديو',
              style: AppTextStyles.titleMedium.copyWith(
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'حاول مرة أخرى',
              style: AppTextStyles.bodyMedium.copyWith(
                color: Colors.white70,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _errorMessage = null;
                });
                _initializeWebView();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('إعادة المحاولة'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.buttonPrimary,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoInfo() {
    // استخدام معلومات الفيديو المحملة من API إذا كانت متوفرة
    final title = _videoDetails != null && _videoDetails!['title'] != null
        ? _videoDetails!['title']
        : widget.video.title;

    final description =
        _videoDetails != null && _videoDetails!['description'] != null
            ? _videoDetails!['description']
            : widget.video.description;

    final duration = _videoDetails != null && _videoDetails!['length'] != null
        ? _formatDuration(_videoDetails!['length'])
        : widget.video.formattedDuration;

    return Container(
      color: Colors.black,
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (description != null && description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                description,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(
                Icons.access_time,
                color: Colors.white70,
                size: 16,
              ),
              const SizedBox(width: 4),
              Text(
                duration,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final remainingSeconds = seconds % 60;

    if (hours > 0) {
      return '$hours ساعة ${minutes > 0 ? 'و $minutes دقيقة' : ''}';
    } else if (minutes > 0) {
      return '$minutes دقيقة ${remainingSeconds > 0 ? 'و $remainingSeconds ثانية' : ''}';
    } else {
      return '$remainingSeconds ثانية';
    }
  }
}
