import 'package:flutter/material.dart';
import 'package:mycourses/core/services/course_videos_service.dart';

/// Helper class for DRM-related functionality
class DrmHelper {
  /// Safely check if a video has DRM protection enabled
  static Future<bool> isVideoDrmProtected(String videoId) async {
    if (videoId.isEmpty) {
      debugPrint('Empty videoId provided to DrmHelper.isVideoDrmProtected');
      return false;
    }

    try {
      final details = await CourseVideosService.getVideoDetails(videoId);
      debugPrint('DRM check - API response: $details');

      // For MediaCage Basic DRM, specifically check for the mediaCage property
      final encodeProgress = details['encodeProgress'] ?? 0;
      final mediaCage = details['mediaCage'];

      final isDrmEnabled =
          encodeProgress == 100 && (mediaCage == true || mediaCage == 'Basic');

      debugPrint(
          'Video $videoId DRM status: ${isDrmEnabled ? "Enabled" : "Disabled"}');
      debugPrint('  encodeProgress: $encodeProgress');
      debugPrint(
          '  mediaCage: $mediaCage (${mediaCage?.runtimeType ?? "null"})');

      return isDrmEnabled;
    } catch (e) {
      debugPrint('Error in DrmHelper.isVideoDrmProtected: $e');
      // Return false instead of throwing to avoid errors in UI
      return false;
    }
  }

  /// Check if a video is playable using direct links and determine best format
  static Future<PlaybackRequirement> getPlaybackRequirement(
      String videoId) async {
    try {
      // First check if it's DRM protected
      final isDrmProtected = await isVideoDrmProtected(videoId);

      if (isDrmProtected) {
        return PlaybackRequirement(
            method: PlaybackMethod.webEmbed,
            format: VideoFormat.embed,
            reason:
                "فيديو محمي بتقنية MediaCage Basic DRM يتطلب استخدام مشغل Embed",
            isDrmProtected: true);
      }

      // For test video 989b0866-b522-4c56-b7c3-487d858943ed, we know HLS works but MP4 doesn't
      if (videoId == '989b0866-b522-4c56-b7c3-487d858943ed') {
        return PlaybackRequirement(
            method: PlaybackMethod.native,
            format: VideoFormat.hls,
            reason: "صيغة HLS هي المتاحة لهذا الفيديو",
            isDrmProtected: false);
      }

      // For regular videos, prefer HLS first but allow fallback to MP4
      return PlaybackRequirement(
          method: PlaybackMethod.native,
          format: VideoFormat.hls,
          reason: "فيديو غير محمي",
          isDrmProtected: false);
    } catch (e) {
      // In case of errors, default to HLS for native playback
      return PlaybackRequirement(
          method: PlaybackMethod.native,
          format: VideoFormat.hls,
          reason: "تعذر التحقق من حماية الفيديو: $e",
          isDrmProtected: false);
    }
  }

  /// Get informative message about MediaCage DRM
  static String getDrmInfoMessage() {
    return "هذا الفيديو محمي بنظام MediaCage Basic DRM من Bunny.net، وهو متاح فقط من خلال مشغل Embed (iframe). "
        "لا يمكن الوصول إلى هذا الفيديو عبر روابط MP4 أو HLS المباشرة وفقاً لوثائق Bunny.net.";
  }

  /// Get the recommended player type for DRM videos
  static String getDrmPlayerRecommendation() {
    return "للفيديوهات المحمية بتقنية DRM، يجب استخدام مشغل iframe المدمج لعرض المحتوى بشكل صحيح.";
  }

  /// Get message about unavailable MP4 format
  static String getMp4UnavailableMessage() {
    return "صيغة MP4 غير متاحة لهذا الفيديو. يرجى استخدام صيغة HLS بدلاً من ذلك.";
  }
}

/// Enum for different playback methods
enum PlaybackMethod {
  native, // Direct player (MP4 or HLS)
  webEmbed, // WebView embedded player for DRM
}

/// Enum for video formats
enum VideoFormat {
  hls, // HLS streaming format (m3u8)
  mp4, // MP4 direct format
  embed // Embed player (iframe)
}

/// Class to hold playback requirement details
class PlaybackRequirement {
  final PlaybackMethod method;
  final VideoFormat format;
  final String reason;
  final bool isDrmProtected;

  PlaybackRequirement(
      {required this.method,
      required this.format,
      required this.reason,
      required this.isDrmProtected});
}
