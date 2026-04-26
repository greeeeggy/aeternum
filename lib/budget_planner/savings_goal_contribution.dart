class SavingsGoalContribution {
  final int? id;
  final int goalId;
  final double amount;
  final DateTime date;
  final String? notes;
  final DateTime createdAt;

  SavingsGoalContribution({
    this.id,
    required this.goalId,
    required this.amount,
    required this.date,
    this.notes,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'goalId': goalId,
      'amount': amount,
      'date': date.toIso8601String(),
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory SavingsGoalContribution.fromMap(Map<String, dynamic> map) {
    return SavingsGoalContribution(
      id: map['id'] as int?,
      goalId: map['goalId'] as int,
      amount: (map['amount'] as num).toDouble(),
      date: DateTime.parse(map['date'] as String),
      notes: map['notes'] as String?,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }

  SavingsGoalContribution copyWith({
    int? id,
    int? goalId,
    double? amount,
    DateTime? date,
    String? notes,
    DateTime? createdAt,
  }) {
    return SavingsGoalContribution(
      id: id ?? this.id,
      goalId: goalId ?? this.goalId,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
