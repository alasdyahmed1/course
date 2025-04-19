import 'package:flutter/foundation.dart';

class CourseSection {
  final String id;
  final String courseId;
  final String title;
  final String? description;
  final int orderNumber;
  final bool isPublished;
  final DateTime createdAt;
  final DateTime updatedAt;
  int videoCount;

  CourseSection({
    required this.id,
    required this.courseId,
    required this.title,
    this.description,
    required this.orderNumber,
    required this.isPublished,
    required this.createdAt,
    required this.updatedAt,
    this.videoCount = 0,
  });

  factory CourseSection.fromJson(Map<String, dynamic> json) {
    final int orderNum = json['order_number'] ?? 1;
    final DateTime created = DateTime.parse(json['created_at']);
    final DateTime updated = DateTime.parse(json['updated_at']);

    debugPrint('📦 تحميل القسم: ${json['title']} [الترتيب: $orderNum]');

    return CourseSection(
      id: json['id'] ?? '',
      courseId: json['course_id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'],
      orderNumber: orderNum,
      isPublished: json['is_published'] ?? true,
      createdAt: created,
      updatedAt: updated,
      videoCount: json['video_count'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'course_id': courseId,
      'title': title,
      'description': description,
      'order_number': orderNumber,
      'is_published': isPublished,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'video_count': videoCount,
    };
  }

  CourseSection copyWith({
    String? id,
    String? courseId,
    String? title,
    String? description,
    int? orderNumber,
    bool? isPublished,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? videoCount,
  }) {
    return CourseSection(
      id: id ?? this.id,
      courseId: courseId ?? this.courseId,
      title: title ?? this.title,
      description: description ?? this.description,
      orderNumber: orderNumber ?? this.orderNumber,
      isPublished: isPublished ?? this.isPublished,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      videoCount: videoCount ?? this.videoCount,
    );
  }

  @override
  String toString() {
    return 'CourseSection{id: $id, title: $title, orderNumber: $orderNumber}';
  }
}
