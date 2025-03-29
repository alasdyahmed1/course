class Course {
  final String id;
  final String title;
  final String? description;
  final String? thumbnailUrl;
  final String semesterId;
  final int totalVideos;
  final int totalDuration;
  final double rating;
  final int ratingsCount;
  final DateTime createdAt;
  final List<DepartmentDetail> departmentDetails;
  final PricingDetail? pricing;

  Course({
    required this.id,
    required this.title,
    this.description,
    this.thumbnailUrl,
    required this.semesterId,
    this.totalVideos = 0,
    this.totalDuration = 0,
    this.rating = 0.0,
    this.ratingsCount = 0,
    required this.createdAt,
    this.departmentDetails = const [],
    this.pricing,
  });

  factory Course.fromJson(Map<String, dynamic> json) {
    return Course(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      thumbnailUrl: json['thumbnail_url'],
      semesterId: json['semester_id'],
      totalVideos: json['total_videos'] ?? 0,
      totalDuration: json['total_duration'] ?? 0,
      rating: (json['rating'] ?? 0.0).toDouble(),
      ratingsCount: json['ratings_count'] ?? 0,
      createdAt: DateTime.parse(json['created_at']),
      departmentDetails: (json['course_department_semesters'] as List?)
              ?.map((d) => DepartmentDetail.fromJson(d))
              .toList() ??
          [],
      pricing: json['pricing'] != null
          ? json['pricing'] is List
              ? (json['pricing'] as List).isNotEmpty
                  ? PricingDetail.fromJson((json['pricing'] as List).first)
                  : null
              : PricingDetail.fromJson(json['pricing'])
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'description': description,
        'thumbnail_url': thumbnailUrl,
        'semester_id': semesterId,
        'total_videos': totalVideos,
        'total_duration': totalDuration,
        'rating': rating,
        'ratings_count': ratingsCount,
      };
}

class DepartmentDetail {
  final String departmentId;
  final String stageId;
  final String semesterId;
  final String departmentName;
  final String stageName;
  final String semesterName;

  DepartmentDetail({
    required this.departmentId,
    required this.stageId,
    required this.semesterId,
    required this.departmentName,
    required this.stageName,
    required this.semesterName,
  });

  factory DepartmentDetail.fromJson(Map<String, dynamic> json) {
    return DepartmentDetail(
      departmentId: json['department']['id'] ?? '',
      stageId: json['stage']['id'] ?? '',
      semesterId: json['semester']['id'] ?? '',
      departmentName: json['department']['name'] ?? 'غير محدد',
      stageName: json['stage']['name'] ?? 'غير محدد',
      semesterName: json['semester']['name'] ?? 'غير محدد',
    );
  }
}

class PricingDetail {
  final String? id;
  final String? courseId;
  final double price;
  final double? discountPrice;
  final bool isActive;

  PricingDetail({
    this.id,
    this.courseId,
    required this.price,
    this.discountPrice,
    this.isActive = true,
  });

  factory PricingDetail.fromJson(Map<String, dynamic> json) {
    return PricingDetail(
      id: json['id'],
      courseId: json['course_id'],
      price: (json['price'] ?? 0.0).toDouble(),
      discountPrice: json['discount_price']?.toDouble(),
      isActive: json['is_active'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {
      'price': price,
      'discount_price': discountPrice,
      'is_active': isActive,
    };

    // إضافة courseId فقط إذا كان موجودًا
    if (courseId != null) {
      data['course_id'] = courseId;
    }

    return data;
  }
}
