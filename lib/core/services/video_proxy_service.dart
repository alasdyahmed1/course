import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

/// A service that acts as a proxy for Bunny.net video access
class VideoProxyService {
  static final String? _streamApiKey = dotenv.env['BUNNY_API_KEY'];
  static final String? _libraryId = dotenv.env['BUNNY_LIBRARY_ID'];
  static final String? _streamHostname = dotenv.env['BUNNY_STREAM_HOSTNAME'];
  static final String? _pullZone = dotenv.env['BUNNY_PULL_ZONE'];

  // Add debug printouts for configuration
  static void debugPrintConfig() {
    debugPrint('BUNNY_API_KEY: ${_streamApiKey?.substring(0, 5)}...');
    debugPrint('BUNNY_LIBRARY_ID: $_libraryId');
    debugPrint('BUNNY_STREAM_HOSTNAME: $_streamHostname');
    debugPrint('BUNNY_PULL_ZONE: $_pullZone');
  }

  /// Get direct URLs for a test video ID
  static Map<String, String> getTestVideoUrls() {
    const testVideoId = '989b0866-b522-4c56-b7c3-487d858943ed';

    return {
      'videoId': testVideoId,
      'hlsUrl': 'https://vz-00908cfa-8cc.b-cdn.net/$testVideoId/playlist.m3u8',
      'thumbnailUrl':
          'https://vz-00908cfa-8cc.b-cdn.net/$testVideoId/thumbnail.jpg',
      'mp4Url': 'https://vz-00908cfa-8cc.b-cdn.net/$testVideoId/720p.mp4',
      'previewUrl':
          'https://vz-00908cfa-8cc.b-cdn.net/$testVideoId/preview.webp'
    };
  }

  /// Get debug info for sample video that works for testing
  static Map<String, String> getSampleVideoInfo() {
    return {
      'videoId': '989b0866-b522-4c56-b7c3-487d858943ed',
      'hlsUrl':
          'https://vz-00908cfa-8cc.b-cdn.net/989b0866-b522-4c56-b7c3-487d858943ed/playlist.m3u8',
      'mp4Url':
          'https://vz-00908cfa-8cc.b-cdn.net/989b0866-b522-4c56-b7c3-487d858943ed/720p.mp4',
      'thumbnailUrl':
          'https://vz-00908cfa-8cc.b-cdn.net/989b0866-b522-4c56-b7c3-487d858943ed/thumbnail.jpg',
      'previewUrl':
          'https://vz-00908cfa-8cc.b-cdn.net/989b0866-b522-4c56-b7c3-487d858943ed/preview.webp',
      'title': 'نموذج فيديو اختبار',
    };
  }

  /// Create an authenticated URL for Bunny.net resources
  static String getAuthenticatedUrl(String videoId, String resourcePath) {
    if (_streamApiKey == null || _pullZone == null || _streamHostname == null) {
      return '';
    }

    final timestamp = (DateTime.now().millisecondsSinceEpoch ~/ 1000) +
        3600; // 1 hour validity
    final tokenPath = "/$videoId/$resourcePath";
    final hashableBase = _streamApiKey! + tokenPath + timestamp.toString();
    final token = sha256.convert(utf8.encode(hashableBase)).toString();

    return "https://$_streamHostname$tokenPath?token=$token&expires=$timestamp";
  }

  /// Get direct video data stream through a proxy request
  static Future<http.Response> getVideoData(
      String videoId, String resourcePath) async {
    try {
      if (_streamApiKey == null || _libraryId == null) {
        throw Exception('API configuration is missing');
      }

      // Make authenticated request directly to Bunny.net
      final url =
          'https://video.bunnycdn.com/library/$_libraryId/videos/$videoId';
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'AccessKey': _streamApiKey!,
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to access video: ${response.statusCode}');
      }

      return response;
    } catch (e) {
      debugPrint('Error in video proxy: $e');
      throw Exception('Failed to proxy video request: $e');
    }
  }

  /// Get direct video playlist with authentication
  static Future<http.Response> getVideoPlaylist(String videoId) async {
    final url = getAuthenticatedUrl(videoId, 'playlist.m3u8');
    try {
      final response = await http.get(Uri.parse(url));
      return response;
    } catch (e) {
      debugPrint('Error fetching playlist: $e');
      throw Exception('Failed to fetch playlist: $e');
    }
  }

  /// Get a signed URL that will work for a limited time
  static String getSignedUrl(String videoId, String type) {
    final resourcePath = type == 'thumbnail'
        ? 'thumbnail.jpg'
        : (type == 'mp4' ? 'playlist.mp4' : 'playlist.m3u8');

    return getAuthenticatedUrl(videoId, resourcePath);
  }

  /// Get mobile-friendly direct video URL
  static String getMobileVideoUrl(String videoId) {
    // Test if we're dealing with the sample video
    if (videoId == '989b0866-b522-4c56-b7c3-487d858943ed') {
      return 'https://vz-00908cfa-8cc.b-cdn.net/989b0866-b522-4c56-b7c3-487d858943ed/720p.mp4';
    }

    if (_streamHostname == null) return '';

    // Mobile devices typically prefer MP4 over HLS
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final url = 'https://$_streamHostname/$videoId/720p.mp4?t=$timestamp';

    // Add pull zone if available
    return _pullZone != null ? '$url&cdn=$_pullZone' : url;
  }

  /// Verify if the given URL is accessible
  static Future<bool> isUrlAccessible(String url) async {
    try {
      // طباعة الرابط المختبر للتشخيص
      debugPrint('فحص الوصول إلى: $url');

      final response = await http.head(
        Uri.parse(url),
        headers: {
          'User-Agent': 'Mozilla/5.0 Flutter Video App',
          'Referer': 'https://bunny.net/',
          'Origin': 'https://bunny.net/',
          'Accept': '*/*', // Accept any content type
          // إضافة مفتاح الوصول إذا كان مطلوبًا
          if (_streamApiKey != null) 'AccessKey': _streamApiKey!,
        },
      ).timeout(const Duration(seconds: 5)); // Add timeout to avoid hanging

      // طباعة كود الاستجابة للتشخيص
      final statusCode = response.statusCode;
      debugPrint('كود الاستجابة: $statusCode لـ $url');
      debugPrint('رؤوس الاستجابة: ${response.headers}');

      return statusCode >= 200 && statusCode < 400;
    } catch (e) {
      debugPrint('خطأ في التحقق من إمكانية الوصول إلى: $url');
      debugPrint('نوع الخطأ: ${e.runtimeType}, الرسالة: $e');
      return false;
    }
  }

  /// تصحيح رابط بواسطة إضافة accessKey مباشرة كمعامل في URL
  static String fixUrlWithQueryAuth(String url) {
    if (_streamApiKey == null) return url;

    // إضافة مفتاح الوصول كمعامل في الرابط
    final Uri uri = Uri.parse(url);
    final updatedUri = uri.replace(
      queryParameters: {
        ...uri.queryParameters,
        'token': _generateSimpleToken(videoId: _extractVideoId(url)),
        'accessKey': _streamApiKey!,
      },
    );

    return updatedUri.toString();
  }

  /// استخراج معرف الفيديو من رابط
  static String _extractVideoId(String url) {
    // مثال رابط: https://vz-00908cfa-8cc.b-cdn.net/989b0866-b522-4c56-b7c3-487d858943ed/720p.mp4
    final RegExp regex = RegExp(r'\/([0-9a-f-]{36})\/');
    final match = regex.firstMatch(url);
    return match?.group(1) ?? '';
  }

  /// إنشاء توكن بسيط للتوثيق
  static String _generateSimpleToken({required String videoId}) {
    if (_streamApiKey == null || videoId.isEmpty) return '';

    final timestamp = (DateTime.now().millisecondsSinceEpoch ~/ 1000) +
        3600; // صالح لمدة ساعة
    final hashData = '$_streamApiKey/$videoId:$timestamp';
    final token =
        sha256.convert(utf8.encode(hashData)).toString().substring(0, 32);

    return '$token:$timestamp';
  }
}
