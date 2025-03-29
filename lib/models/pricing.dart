class Pricing {
  final String id;
  final String courseId;
  final double price; // تم تغيير originalPrice إلى price
  final double? discountPrice;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt; // إضافة جديدة

  Pricing({
    required this.id,
    required this.courseId,
    required this.price,
    this.discountPrice,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Pricing.fromJson(Map<String, dynamic> json) {
    return Pricing(
      id: json['id'] as String,
      courseId: json['course_id'] as String,
      price: (json['price'] as num).toDouble(),
      discountPrice: json['discount_price'] != null
          ? (json['discount_price'] as num).toDouble()
          : null,
      isActive: json['is_active'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'course_id': courseId,
        'price': price,
        'discount_price': discountPrice,
        'is_active': isActive,
      };
}
