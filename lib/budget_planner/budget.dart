class Budget {
  final int? id;
  final int? categoryId; // null means overall budget
  final double amount;
  final String periodType; // 'weekly', 'monthly', 'custom'
  final DateTime startDate;
  final DateTime endDate;
  final bool isEnabled;
  final DateTime createdAt;

  Budget({
    this.id,
    this.categoryId,
    required this.amount,
    required this.periodType,
    required this.startDate,
    required this.endDate,
    this.isEnabled = true,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'categoryId': categoryId,
      'amount': amount,
      'periodType': periodType,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'isEnabled': isEnabled ? 1 : 0,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Budget.fromMap(Map<String, dynamic> map) {
    return Budget(
      id: map['id'] as int?,
      categoryId: map['categoryId'] as int?,
      amount: map['amount'] as double,
      periodType: map['periodType'] as String,
      startDate: DateTime.parse(map['startDate'] as String),
      endDate: DateTime.parse(map['endDate'] as String),
      isEnabled: map['isEnabled'] == 1,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }

  Budget copyWith({
    int? id,
    int? categoryId,
    double? amount,
    String? periodType,
    DateTime? startDate,
    DateTime? endDate,
    bool? isEnabled,
    DateTime? createdAt,
  }) {
    return Budget(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      amount: amount ?? this.amount,
      periodType: periodType ?? this.periodType,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      isEnabled: isEnabled ?? this.isEnabled,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}