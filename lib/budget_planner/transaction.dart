class Transaction {
  final int? id;
  final String? name;
  final double amount;
  final String type; // 'income', 'expense', or 'savings'
  final int categoryId;
  final DateTime date;
  final String? notes;
  final int? recurringTransactionId;
  final int? goalId;
  final DateTime createdAt;
  // Joint savings/goal Firestore back-link (null for regular transactions)
  final String? jointPairId;
  final String? jointTargetId;   // potId or goalId in Firestore
  final String? jointFirestoreTxId; // Firestore transaction doc ID

  Transaction({
    this.id,
    this.name,
    required this.amount,
    required this.type,
    required this.categoryId,
    required this.date,
    this.notes,
    this.recurringTransactionId,
    this.goalId,
    DateTime? createdAt,
    this.jointPairId,
    this.jointTargetId,
    this.jointFirestoreTxId,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'amount': amount,
      'type': type,
      'categoryId': categoryId,
      'date': date.toIso8601String(),
      'notes': notes,
      'recurringTransactionId': recurringTransactionId,
      'goalId': goalId,
      'createdAt': createdAt.toIso8601String(),
      'jointPairId': jointPairId,
      'jointTargetId': jointTargetId,
      'jointFirestoreTxId': jointFirestoreTxId,
    };
  }

  factory Transaction.fromMap(Map<String, dynamic> map) {
    return Transaction(
      id: map['id'] as int?,
      name: map['name'] as String?,
      amount: map['amount'] as double,
      type: map['type'] as String,
      categoryId: map['categoryId'] as int,
      date: DateTime.parse(map['date'] as String),
      notes: map['notes'] as String?,
      recurringTransactionId: map['recurringTransactionId'] as int?,
      goalId: map['goalId'] as int?,
      createdAt: DateTime.parse(map['createdAt'] as String),
      jointPairId: map['jointPairId'] as String?,
      jointTargetId: map['jointTargetId'] as String?,
      jointFirestoreTxId: map['jointFirestoreTxId'] as String?,
    );
  }

  Transaction copyWith({
    int? id,
    String? name,
    double? amount,
    String? type,
    int? categoryId,
    DateTime? date,
    String? notes,
    int? recurringTransactionId,
    int? goalId,
    DateTime? createdAt,
    String? jointPairId,
    String? jointTargetId,
    String? jointFirestoreTxId,
  }) {
    return Transaction(
      id: id ?? this.id,
      name: name ?? this.name,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      categoryId: categoryId ?? this.categoryId,
      date: date ?? this.date,
      notes: notes ?? this.notes,
      recurringTransactionId: recurringTransactionId ?? this.recurringTransactionId,
      goalId: goalId ?? this.goalId,
      createdAt: createdAt ?? this.createdAt,
      jointPairId: jointPairId ?? this.jointPairId,
      jointTargetId: jointTargetId ?? this.jointTargetId,
      jointFirestoreTxId: jointFirestoreTxId ?? this.jointFirestoreTxId,
    );
  }
}