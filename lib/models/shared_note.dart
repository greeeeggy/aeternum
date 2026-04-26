// lib/models/shared_note.dart
class SharedNote {
  final int? id;
  final String? docId;
  final String title;
  final String content;
  final int color;
  final bool isPinned;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String createdBy;
  final bool isSynced;
  final bool isDeleted;

  SharedNote({
    this.id,
    this.docId,
    required this.title,
    required this.content,
    this.color = 0xFFFFFFFF,
    this.isPinned = false,
    required this.createdAt,
    required this.updatedAt,
    required this.createdBy,
    this.isSynced = false,
    this.isDeleted = false,
  });

  SharedNote copyWith({int? id}) {
    return SharedNote(
      id: id ?? this.id,
      docId: docId,
      title: title,
      content: content,
      color: color,
      isPinned: isPinned,
      createdAt: createdAt,
      updatedAt: updatedAt,
      createdBy: createdBy,
      isSynced: isSynced,
      isDeleted: isDeleted,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'docId': docId,
      'title': title,
      'content': content,
      'color': color,
      'isPinned': isPinned ? 1 : 0,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
      'createdBy': createdBy,
      'isSynced': isSynced ? 1 : 0,
      'isDeleted': isDeleted ? 1 : 0,
    };
  }

  factory SharedNote.fromMap(Map<String, dynamic> map) {
    return SharedNote(
      id: map['id'],
      docId: map['docId'],
      title: map['title'] ?? '',
      content: map['content'] ?? '',
      color: map['color'] ?? 0xFFFFFFFF,
      isPinned: map['isPinned'] == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt']),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updatedAt']),
      createdBy: map['createdBy'] ?? '',
      isSynced: map['isSynced'] == 1,
      isDeleted: map['isDeleted'] == 1,
    );
  }

  Map<String, dynamic> toFirestoreMap() {
    return {
      'title': title,
      'content': content,
      'color': color,
      'isPinned': isPinned,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'createdBy': createdBy,
      'isDeleted': isDeleted,
    };
  }
}