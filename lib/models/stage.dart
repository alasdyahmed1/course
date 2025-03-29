class Stage {
  final String id;
  final String name;
  final int level; // تم تغيير description إلى level
  final DateTime createdAt;

  Stage({
    required this.id,
    required this.name,
    required this.level,
    required this.createdAt,
  });

  factory Stage.fromJson(Map<String, dynamic> json) {
    return Stage(
      id: json['id'] as String,
      name: json['name'] as String,
      level: json['level'] as int, // تحديث
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'level': level, // تحديث
      };
}
