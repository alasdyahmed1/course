import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mycourses/core/config/bunny_config.dart';

/// أداة لاختبار واستكشاف روابط Bunny.net
class BunnyUrlTester {
  /// اختبار API Bunny.net للحصول على قائمة الفيديوهات
  static Future<Map<String, dynamic>> testBunnyApi() async {
    try {
      final apiKey = BunnyConfig.streamApiKey;
      final libraryId = BunnyConfig.libraryId;

      if (apiKey == null || libraryId == null) {
        return {
          'success': false,
          'message': 'مفتاح API أو معرف المكتبة غير متوفر'
        };
      }

      // محاولة قراءة قائمة الفيديوهات من Bunny.net
      final url = 'https://video.bunnycdn.com/library/$libraryId/videos';
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'AccessKey': apiKey,
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'videos': data['items'],
          'totalCount': data['totalItems'],
        };
      } else {
        return {
          'success': false,
          'statusCode': response.statusCode,
          'message': 'فشل الاتصال بـ Bunny.net: ${response.body}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'خطأ أثناء الاتصال: $e',
      };
    }
  }

  /// عرض نافذة اختبار الروابط
  static Future<void> showUrlTester(BuildContext context) async {
    showDialog(
      context: context,
      builder: (_) => const BunnyUrlTesterDialog(),
    );
  }
}

/// شاشة اختبار روابط Bunny.net
class BunnyUrlTesterDialog extends StatefulWidget {
  const BunnyUrlTesterDialog({super.key});

  @override
  State<BunnyUrlTesterDialog> createState() => _BunnyUrlTesterDialogState();
}

class _BunnyUrlTesterDialogState extends State<BunnyUrlTesterDialog> {
  bool _isLoading = true;
  bool _hasApiAccess = false;
  String _message = 'جاري الاختبار...';
  List<dynamic> _videos = [];

  @override
  void initState() {
    super.initState();
    _testConnection();
  }

  Future<void> _testConnection() async {
    setState(() {
      _isLoading = true;
      _message = 'جاري اختبار الاتصال بـ Bunny.net...';
    });

    final result = await BunnyUrlTester.testBunnyApi();

    setState(() {
      _isLoading = false;
      _hasApiAccess = result['success'] == true;

      if (_hasApiAccess) {
        _videos = result['videos'] ?? [];
        _message = 'تم العثور على ${_videos.length} فيديو';
      } else {
        _message = result['message'] ?? 'فشل الاتصال بـ Bunny.net';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('اختبار Bunny.net'),
      content: SizedBox(
        width: double.maxFinite,
        child: _isLoading
            ? const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('جاري الاختبار...'),
                  ],
                ),
              )
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildConnectionStatus(),
                    const Divider(),
                    if (_hasApiAccess) ...[
                      const Text('الفيديوهات المتاحة:',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      ..._videos.map((video) => _buildVideoItem(video)),
                    ] else ...[
                      _buildConnectionHelp(),
                    ],
                  ],
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: _testConnection,
          child: const Text('إعادة الاختبار'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('إغلاق'),
        ),
      ],
    );
  }

  Widget _buildConnectionStatus() {
    return Row(
      children: [
        Icon(
          _hasApiAccess ? Icons.check_circle : Icons.error,
          color: _hasApiAccess ? Colors.green : Colors.red,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _hasApiAccess
                    ? 'متصل بنجاح بـ Bunny.net'
                    : 'فشل الاتصال بـ Bunny.net',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: _hasApiAccess ? Colors.green : Colors.red,
                ),
              ),
              Text(_message),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVideoItem(dynamic video) {
    final videoId = video['guid'] ?? '';
    final title = video['title'] ?? 'بدون عنوان';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(title),
        subtitle: Text('معرف: $videoId'),
        trailing: IconButton(
          icon: const Icon(Icons.content_copy),
          onPressed: () {
            // نسخ معرف الفيديو
          },
        ),
        onTap: () {
          // عرض تفاصيل الفيديو
        },
      ),
    );
  }

  Widget _buildConnectionHelp() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('نصائح لإصلاح مشكلة الاتصال:',
            style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        _buildHelpItem(
            '1. تحقق من مفتاح API', 'تأكد من صحة مفتاح API في ملف .env'),
        _buildHelpItem(
            '2. تحقق من معرف المكتبة', 'تأكد من صحة معرف المكتبة في ملف .env'),
        _buildHelpItem(
            '3. تحقق من اتصال الإنترنت', 'تأكد من أن جهازك متصل بالإنترنت'),
        _buildHelpItem('4. تحقق من صلاحيات API',
            'تأكد من أن مفتاح API لديه صلاحيات القراءة'),
      ],
    );
  }

  Widget _buildHelpItem(String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          Text(description, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}
