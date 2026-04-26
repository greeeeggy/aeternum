class RecurringTransaction {
  final int? id;
  final String? name;
  final double amount;
  final String type; // 'income', 'expense', or 'savings'
  final int categoryId;
  final String frequency; // 'daily', 'weekly', or 'monthly'
  final DateTime startDate;
  final DateTime? endDate;
  final String? notes;
  final bool isActive;
  final DateTime? lastGeneratedDate;
  final DateTime createdAt;
  final List<int>? excludedDays; // For daily recurring: 1=Monday, 2=Tuesday, ..., 7=Sunday

  RecurringTransaction({
    this.id,
    this.name,
    required this.amount,
    required this.type,
    required this.categoryId,
    required this.frequency,
    required this.startDate,
    this.endDate,
    this.notes,
    this.isActive = true,
    this.lastGeneratedDate,
    required this.createdAt,
    this.excludedDays,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'amount': amount,
      'type': type,
      'categoryId': categoryId,
      'frequency': frequency,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'notes': notes,
      'isActive': isActive ? 1 : 0,
      'lastGeneratedDate': lastGeneratedDate?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'excludedDays': excludedDays?.join(','),
    };
  }

  factory RecurringTransaction.fromMap(Map<String, dynamic> map) {
    return RecurringTransaction(
      id: map['id'],
      name: map['name'] as String?,
      amount: map['amount'],
      type: map['type'],
      categoryId: map['categoryId'],
      frequency: map['frequency'],
      startDate: DateTime.parse(map['startDate']),
      endDate: map['endDate'] != null ? DateTime.parse(map['endDate']) : null,
      notes: map['notes'] as String?,
      isActive: map['isActive'] == 1,
      lastGeneratedDate: map['lastGeneratedDate'] != null
          ? DateTime.parse(map['lastGeneratedDate'])
          : null,
      createdAt: DateTime.parse(map['createdAt']),
      excludedDays: map['excludedDays'] != null && map['excludedDays'].toString().isNotEmpty
          ? map['excludedDays'].toString().split(',').map((e) => int.parse(e)).toList()
          : null,
    );
  }

  RecurringTransaction copyWith({
    int? id,
    String? name,
    double? amount,
    String? type,
    int? categoryId,
    String? frequency,
    DateTime? startDate,
    DateTime? endDate,
    String? notes,
    bool? isActive,
    DateTime? lastGeneratedDate,
    DateTime? createdAt,
    List<int>? excludedDays,
  }) {
    return RecurringTransaction(
      id: id ?? this.id,
      name: name ?? this.name,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      categoryId: categoryId ?? this.categoryId,
      frequency: frequency ?? this.frequency,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      notes: notes ?? this.notes,
      isActive: isActive ?? this.isActive,
      lastGeneratedDate: lastGeneratedDate ?? this.lastGeneratedDate,
      createdAt: createdAt ?? this.createdAt,
      excludedDays: excludedDays ?? this.excludedDays,
    );
  }
}