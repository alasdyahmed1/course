import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:mycourses/core/config/bunny_config.dart';
import 'package:mycourses/core/services/course_videos_service.dart';
import 'package:mycourses/core/services/video_proxy_service.dart';

/// Utility for diagnosing video playback issues
class VideoDiagnostics {
  /// Test various video URLs to check which ones are accessible
  static Future<Map<String, Map<String, dynamic>>> checkVideoAccessibility(
      String videoId) async {
    final results = <String, Map<String, dynamic>>{};

    // Safety check for empty videoId
    if (videoId.isEmpty) {
      results['Error'] = {
        'accessible': false,
        'error': 'Video ID is empty',
      };
      return results;
    }

    // Check if video has DRM protection - with better error handling
    bool isDrmProtected = false;
    try {
      isDrmProtected = await CourseVideosService.isVideoDrmProtected(videoId);
      results['DRM Protection'] = {
        'accessible': true,
        'status': isDrmProtected ? 'Enabled' : 'Disabled',
        'info': isDrmProtected
            ? 'هذا الفيديو محمي بنظام MediaCage Basic DRM، استخدم المشغل المدمج بدلاً من الروابط المباشرة'
            : 'هذا الفيديو غير محمي بنظام DRM'
      };
    } catch (e) {
      results['DRM Protection'] = {
        'accessible': false,
        'error': e.toString(),
      };
    }

    // طباعة معلومات التكوين الحالية
    debugPrint('===== معلومات تكوين Bunny.net =====');
    debugPrint('LIBRARY_ID: ${BunnyConfig.libraryId}');
    debugPrint('STREAM_HOSTNAME: ${BunnyConfig.streamHostname}');
    debugPrint('PULL_ZONE: ${BunnyConfig.pullZone}');
    debugPrint(
        'API_KEY: ${BunnyConfig.streamApiKey != null ? "[موجود]" : "[غير موجود]"}');

    // Check all URLs
    final urlsToCheck = {
      'HLS': BunnyConfig.getDirectVideoUrl(videoId),
      'MP4': BunnyConfig.getDirectMp4Url(videoId),
      'MP4 (مباشر)': 'https://${BunnyConfig.streamHostname}/$videoId/720p.mp4',
      'Thumbnail': BunnyConfig.getThumbnailUrl(videoId),
      'Mobile MP4': VideoProxyService.getMobileVideoUrl(videoId),
    };

    // Test each URL
    for (final entry in urlsToCheck.entries) {
      try {
        final url = entry.value;
        debugPrint('اختبار الوصول إلى ${entry.key}: $url');

        final response = await http.head(
          Uri.parse(url),
          headers: {
            'User-Agent': 'Mozilla/5.0 Flutter App',
            'Referer': 'https://bunny.net/',
            'Origin': 'https://bunny.net/',
          },
        );

        final statusCode = response.statusCode;
        final isAccessible = statusCode >= 200 && statusCode < 400;

        results[entry.key] = {
          'accessible': isAccessible,
          'url': url,
          'statusCode': statusCode,
          'headers': response.headers.toString(),
        };

        debugPrint(
            '${entry.key}: كود الاستجابة $statusCode (${isAccessible ? "متاح" : "غير متاح"})');
      } catch (e) {
        debugPrint('خطأ في اختبار ${entry.key}: $e');
        results[entry.key] = {
          'accessible': false,
          'url': entry.value,
          'error': e.toString(),
        };
      }
    }

    // Add embed player URL if DRM is detected
    if (isDrmProtected) {
      results['Embed Player'] = {
        'accessible': true,
        'url': BunnyConfig.getEmbedUrl(videoId),
        'note': 'يجب استخدام هذا المشغل للفيديوهات المحمية',
      };
    }

    return results;
  }

  /// Show diagnostics in UI with more details
  static Future<void> showDiagnosticsDialog(
      BuildContext context, String videoId) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تشخيص مشكلة الفيديو'),
        content: FutureBuilder<Map<String, Map<String, dynamic>>>(
          future: checkVideoAccessibility(videoId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Container(
                height: 100,
                alignment: Alignment.center,
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('جاري فحص الروابط...'),
                  ],
                ),
              );
            }

            if (!snapshot.hasData) {
              return const Text('فشل في تشخيص المشكلة');
            }

            final results = snapshot.data!;
            final accessibleCount = results.values
                .where((result) => result['accessible'] == true)
                .length;

            return SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('حالة الوصول لمصادر الفيديو:',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ...results.entries.map((entry) =>
                        _buildUrlResultRow(context, entry.key, entry.value)),
                    const Divider(),
                    if (accessibleCount == 0)
                      _buildDiagnosticMessage(
                        title: 'تنبيه: جميع المصادر غير متاحة',
                        message:
                            'قد تكون هناك مشكلة في اتصالك بالإنترنت أو إعدادات الخادم',
                        icon: Icons.error,
                        color: Colors.red,
                      ),
                    if (accessibleCount > 0 &&
                        results['HLS']?['accessible'] == false &&
                        results['MP4']?['accessible'] == true)
                      _buildDiagnosticMessage(
                        title: 'MP4 متاح وHLS غير متاح',
                        message: 'استخدم صيغة MP4 للتشغيل',
                        icon: Icons.info,
                        color: Colors.blue,
                      ),
                    _buildDrmWarningIfNeeded(results),
                    const SizedBox(height: 8),
                    const Text('نصائح لحل المشكلة:',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    _buildTroubleshootingTip(
                      '1. تأكد من صحة رابط الفيديو ومعرف الفيديو',
                      'تحقق من أن معرّف الفيديو صحيح وأن الفيديو موجود في مكتبتك',
                    ),
                    _buildTroubleshootingTip(
                      '2. تحقق من صحة مفاتيح API',
                      'تأكد من أن المفاتيح صحيحة في ملف .env',
                    ),
                    _buildTroubleshootingTip(
                      '3. تحقق من إعدادات CORS',
                      'تأكد من إعدادات CORS في لوحة تحكم Bunny.net',
                    ),
                    _buildTroubleshootingTip(
                      '4. استخدم MP4 بدلاً من HLS',
                      'صيغة MP4 أكثر توافقاً في بعض الأجهزة',
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () {
              final testInfo = BunnyConfig.getSampleVideoInfo();
              _showTestVideoDialog(context, testInfo);
            },
            child: const Text('استخدام فيديو اختباري'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  static Widget _buildUrlResultRow(
      BuildContext context, String key, Map<String, dynamic> result) {
    final isAccessible = result['accessible'] == true;
    // Handle possible null URL - add null check
    final url = result['url'] as String? ?? 'URL not available';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            isAccessible ? Icons.check_circle : Icons.error,
            color: isAccessible ? Colors.green : Colors.red,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  key,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13),
                ),
                Text(
                  result['statusCode'] != null
                      ? 'كود الاستجابة: ${result['statusCode']}'
                      : result['error'] != null
                          ? 'خطأ: ${result['error']}'
                          : 'غير متوفر',
                  style: TextStyle(
                    fontSize: 11,
                    color: isAccessible
                        ? Colors.green.shade700
                        : Colors.red.shade700,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.content_copy, size: 16),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: url)).then((_) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('تم نسخ الرابط')),
                );
              });
            },
          ),
        ],
      ),
    );
  }

  static Widget _buildDiagnosticMessage({
    required String title,
    required String message,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: color,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: TextStyle(
                    color: color.withOpacity(0.8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Add a new helper for DRM detection
  static Widget _buildDrmWarningIfNeeded(
      Map<String, Map<String, dynamic>> results) {
    final drmInfo = results['DRM Protection'];
    if (drmInfo != null && drmInfo['status'] == 'Enabled') {
      return _buildDiagnosticMessage(
        title: 'تم اكتشاف حماية MediaCage DRM',
        message: 'هذا الفيديو محمي بنظام MediaCage Basic DRM من Bunny.net. '
            'وفقًا لتوثيق Bunny.net، سيكون الفيديو قابلاً للتشغيل فقط من خلال مشغل Embed. '
            'لن تعمل روابط MP4 أو HLS المباشرة مع هذا الفيديو.',
        icon: Icons.security,
        color: Colors.orange,
      );
    }
    return const SizedBox.shrink();
  }

  static Widget _buildTroubleshootingTip(String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          Text(
            description,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  static void _showTestVideoDialog(
      BuildContext context, Map<String, String> testInfo) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('استخدام فيديو اختباري'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'يمكنك استخدام هذا الفيديو الاختباري للتأكد من عمل المشغل بشكل صحيح:',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTestInfoItem('معرف الفيديو', testInfo['videoId'] ?? ''),
                  const SizedBox(height: 8),
                  _buildTestInfoItem('رابط HLS', testInfo['hlsUrl'] ?? ''),
                  const SizedBox(height: 8),
                  _buildTestInfoItem('رابط MP4', testInfo['mp4Url'] ?? ''),
                  const SizedBox(height: 8),
                  _buildTestInfoItem(
                      'رابط الصورة المصغرة', testInfo['thumbnailUrl'] ?? ''),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: testInfo['videoId'] ?? ''))
                  .then((_) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('تم نسخ معرف الفيديو')),
                );
              });
            },
            child: const Text('نسخ المعرف'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  static Widget _buildTestInfoItem(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 12,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (value.isNotEmpty)
                InkWell(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: value));
                  },
                  child: const Text(
                    'نسخ',
                    style: TextStyle(
                      color: Colors.blue,
                      fontSize: 11,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
