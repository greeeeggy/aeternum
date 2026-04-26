class Category {
  final int? id;
  final String name;
  final String type; // 'income', 'expense', or 'savings'
  final String icon;
  final int color;
  final bool isDefault;
  final DateTime createdAt;

  Category({
    this.id,
    required this.name,
    required this.type,
    required this.icon,
    required this.color,
    this.isDefault = false,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'icon': icon,
      'color': color,
      'isDefault': isDefault ? 1 : 0,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id'] as int?,
      name: map['name'] as String,
      type: map['type'] as String,
      icon: map['icon'] as String,
      color: map['color'] as int,
      isDefault: map['isDefault'] == 1,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }

  Category copyWith({
    int? id,
    String? name,
    String? type,
    String? icon,
    int? color,
    bool? isDefault,
    DateTime? createdAt,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}