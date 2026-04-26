class SavingsGoal {
  final int? id;
  final String name;
  final double targetAmount;
  final DateTime deadline;
  final String icon;
  final int color;
  final DateTime createdAt;
  final DateTime? completedAt;

  SavingsGoal({
    this.id,
    required this.name,
    required this.targetAmount,
    required this.deadline,
    required this.icon,
    required this.color,
    required this.createdAt,
    this.completedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'targetAmount': targetAmount,
      'deadline': deadline.toIso8601String(),
      'icon': icon,
      'color': color,
      'createdAt': createdAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
    };
  }

  factory SavingsGoal.fromMap(Map<String, dynamic> map) {
    return SavingsGoal(
      id: map['id'] as int?,
      name: map['name'] as String,
      targetAmount: (map['targetAmount'] as num).toDouble(),
      deadline: DateTime.parse(map['deadline'] as String),
      icon: map['icon'] as String,
      color: map['color'] as int,
      createdAt: DateTime.parse(map['createdAt'] as String),
      completedAt: map['completedAt'] != null
          ? DateTime.parse(map['completedAt'] as String)
          : null,
    );
  }

  SavingsGoal copyWith({
    int? id,
    String? name,
    double? targetAmount,
    DateTime? deadline,
    String? icon,
    int? color,
    DateTime? createdAt,
    DateTime? completedAt,
    bool clearCompletedAt = false,
  }) {
    return SavingsGoal(
      id: id ?? this.id,
      name: name ?? this.name,
      targetAmount: targetAmount ?? this.targetAmount,
      deadline: deadline ?? this.deadline,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      createdAt: createdAt ?? this.createdAt,
      completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
    );
  }
}
