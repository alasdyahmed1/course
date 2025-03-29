import 'package:flutter_dotenv/flutter_dotenv.dart';

class CourseVideo {
  final String id;
  final String courseId;
  final String title;
  final String? description;
  final String videoId;
  final int duration;
  final int orderNumber;
  final DateTime createdAt;
  final String? sectionId; // Add section_id field
  final List<CourseFile>? attachments;

  const CourseVideo({
    required this.id,
    required this.courseId,
    required this.title,
    this.description,
    required this.videoId,
    required this.duration,
    required this.orderNumber,
    required this.createdAt,
    this.sectionId, // Add section_id parameter
    this.attachments,
  });

  // Get formatted duration as string
  String get formattedDuration {
    final hours = duration ~/ 3600;
    final minutes = (duration % 3600) ~/ 60;
    final seconds = duration % 60;

    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
  }

  // Create from JSON data
  factory CourseVideo.fromJson(Map<String, dynamic> json) {
    List<CourseFile>? attachments;
    if (json['attachments'] != null) {
      attachments = (json['attachments'] as List)
          .map((fileJson) => CourseFile.fromJson(fileJson))
          .toList();
    }

    return CourseVideo(
      id: json['id'] ?? '',
      courseId: json['course_id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'],
      videoId: json['video_id'] ?? '',
      duration: json['duration'] ?? 0,
      orderNumber: json['order_number'] ?? 0,
      createdAt: DateTime.parse(
          json['created_at'] ?? DateTime.now().toIso8601String()),
      sectionId: json['section_id'], // Parse section_id
      attachments: attachments,
    );
  }

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'course_id': courseId,
      'title': title,
      'description': description,
      'video_id': videoId,
      'duration': duration,
      'order_number': orderNumber,
      'created_at': createdAt.toIso8601String(),
      'section_id': sectionId, // Include section_id in JSON
    };
  }

  // Create a copy with changes
  CourseVideo copyWith({
    String? id,
    String? courseId,
    String? title,
    String? description,
    String? videoId,
    int? duration,
    int? orderNumber,
    DateTime? createdAt,
    String? sectionId, // Add sectionId parameter
    List<CourseFile>? attachments,
  }) {
    return CourseVideo(
      id: id ?? this.id,
      courseId: courseId ?? this.courseId,
      title: title ?? this.title,
      description: description ?? this.description,
      videoId: videoId ?? this.videoId,
      duration: duration ?? this.duration,
      orderNumber: orderNumber ?? this.orderNumber,
      createdAt: createdAt ?? this.createdAt,
      sectionId: sectionId ?? this.sectionId, // Copy sectionId
      attachments: attachments ?? this.attachments,
    );
  }

  // Método para obtener la URL de reproducción de Bunny.net
  String getBunnyStreamUrl() {
    final String? pullZone = dotenv.env['BUNNY_PULL_ZONE'];
    if (pullZone == null) return '';

    // Construir la URL según la documentación de Bunny.net
    return 'https://iframe.mediadelivery.net/embed/$pullZone/$videoId';
  }

  // Método para obtener la URL de miniatura de Bunny.net
  String getBunnyThumbnailUrl() {
    final String? streamHostname = dotenv.env['BUNNY_STREAM_HOSTNAME'];
    if (streamHostname == null) return '';

    // Construir la URL según la documentación de Bunny.net
    return 'https://$streamHostname/$videoId/thumbnail.jpg';
  }

  // Método para obtener la URL directa del video
  String getDirectVideoUrl() {
    final String? streamHostname = dotenv.env['BUNNY_STREAM_HOSTNAME'];
    if (streamHostname == null) return '';

    // Construir la URL directa
    return 'https://$streamHostname/$videoId/playlist.m3u8';
  }
}

class CourseFile {
  final String id;
  final String videoId;
  final String title;
  final String? description;
  final String fileId;
  final String fileType;
  final int fileSize;
  final int downloadCount;
  final int orderNumber;
  final DateTime createdAt;
  final DateTime updatedAt;

  CourseFile({
    required this.id,
    required this.videoId,
    required this.title,
    this.description,
    required this.fileId,
    required this.fileType,
    required this.fileSize,
    required this.downloadCount,
    required this.orderNumber,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CourseFile.fromJson(Map<String, dynamic> json) {
    return CourseFile(
      id: json['id'],
      videoId: json['video_id'],
      title: json['title'],
      description: json['description'],
      fileId: json['file_id'],
      fileType: json['file_type'],
      fileSize: json['file_size'],
      downloadCount: json['download_count'] ?? 0,
      orderNumber: json['order_number'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'video_id': videoId,
      'title': title,
      'description': description,
      'file_id': fileId,
      'file_type': fileType,
      'file_size': fileSize,
      'order_number': orderNumber,
    };
  }

  // Método para formatear el tamaño del archivo
  String get formattedSize {
    if (fileSize < 1024) {
      return '$fileSize B';
    } else if (fileSize < 1024 * 1024) {
      return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    } else if (fileSize < 1024 * 1024 * 1024) {
      return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(fileSize / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }
}
