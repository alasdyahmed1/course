class CourseSection {
  final String id;
  final String courseId;
  final String title;
  final String? description;
  final int orderNumber;
  final bool isPublished;
  final DateTime createdAt;
  final DateTime updatedAt;

  // This should be set when loading the section with its videos
  int _videoCount = 0;

  // Getter for the video count
  int get videoCount => _videoCount;

  // Setter for the video count (can be updated after loading videos)
  set videoCount(int count) {
    _videoCount = count;
  }

  CourseSection({
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
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : DateTime.now(),
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

  CourseSection copyWith({
    String? id,
    String? courseId,
    String? title,
    String? description,
    int? orderNumber,
    bool? isPublished,
    DateTime? createdAt,
    DateTime? updatedAt,
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
    );
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
