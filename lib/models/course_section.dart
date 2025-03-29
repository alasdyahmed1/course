class CourseSection {
  final String id;
  final String courseId;
  final String title;
  final String? description;
  final int orderNumber;
  final bool isPublished;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CourseSection({
    required this.id,
    required this.courseId,
    required this.title,
    this.description,
    required this.orderNumber,
    required this.isPublished,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CourseSection.fromJson(Map<String, dynamic> json) {
    return CourseSection(
      id: json['id'] ?? '',
      courseId: json['course_id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'],
      orderNumber: json['order_number'] ?? 0,
      isPublished: json['is_published'] ?? true,
      createdAt: DateTime.parse(
          json['created_at'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(
          json['updated_at'] ?? DateTime.now().toIso8601String()),
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
    };
  }

  // Add equals operator override to ensure proper comparison in dropdown
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CourseSection && other.id == id;
  }

  // Add hashCode override to go with equals override
  @override
  int get hashCode => id.hashCode;
}
