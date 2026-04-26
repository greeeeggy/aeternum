// lib/class_schedule/schedule_group_model.dart
// Represents a named group/tab of class schedules (e.g. "BSIE 2-E")

class ScheduleGroup {
  final String? id;           // local SQLite int id as string
  final String? firestoreId;  // Firestore doc ID
  final String name;          // canonical name — synced to Firebase
  final String? localName;    // local rename override — NOT synced, display only
  final String ownerUid;      // who created this group

  const ScheduleGroup({
    this.id,
    this.firestoreId,
    required this.name,
    this.localName,
    required this.ownerUid,
  });

  /// The display name: local override wins, else canonical name
  String get displayName => (localName != null && localName!.trim().isNotEmpty)
      ? localName!
      : name;

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'localName': localName,
      'ownerUid': ownerUid,
      'firestoreId': firestoreId,
    };
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'ownerUid': ownerUid,
      'updatedAt': DateTime.now().toIso8601String(),
    };
  }

  factory ScheduleGroup.fromMap(Map<String, dynamic> map) {
    return ScheduleGroup(
      id: map['id']?.toString(),
      firestoreId: map['firestoreId'] as String?,
      name: map['name'] as String? ?? '',
      localName: map['localName'] as String?,
      ownerUid: map['ownerUid'] as String? ?? '',
    );
  }

  factory ScheduleGroup.fromFirestore(String docId, Map<String, dynamic> data) {
    return ScheduleGroup(
      firestoreId: docId,
      name: data['name'] as String? ?? '',
      ownerUid: data['ownerUid'] as String? ?? '',
    );
  }

  ScheduleGroup copyWith({
    String? id,
    String? firestoreId,
    String? name,
    String? localName,
    String? ownerUid,
  }) {
    return ScheduleGroup(
      id: id ?? this.id,
      firestoreId: firestoreId ?? this.firestoreId,
      name: name ?? this.name,
      localName: localName ?? this.localName,
      ownerUid: ownerUid ?? this.ownerUid,
    );
  }
}
