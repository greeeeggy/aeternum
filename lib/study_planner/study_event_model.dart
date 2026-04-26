// lib/study_planner/study_event_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

enum StudyEventType { exam, deadline, submission, busy }

extension StudyEventTypeExt on StudyEventType {
  String get label {
    switch (this) {
      case StudyEventType.exam:
        return 'Exam';
      case StudyEventType.deadline:
        return 'Deadline';
      case StudyEventType.submission:
        return 'Submission';
      case StudyEventType.busy:
        return 'Busy';
    }
  }

  IconData get icon {
    switch (this) {
      case StudyEventType.exam:
        return Icons.assignment_rounded;
      case StudyEventType.deadline:
        return Icons.flag_rounded;
      case StudyEventType.submission:
        return Icons.upload_file_rounded;
      case StudyEventType.busy:
        return Icons.do_not_disturb_rounded;
    }
  }

  Color get color {
    switch (this) {
      case StudyEventType.exam:
        return const Color(0xFFE57373);
      case StudyEventType.deadline:
        return const Color(0xFFFFB74D);
      case StudyEventType.submission:
        return const Color(0xFF64B5F6);
      case StudyEventType.busy:
        return const Color(0xFFB0BEC5);
    }
  }

  Color get lightColor {
    switch (this) {
      case StudyEventType.exam:
        return const Color(0xFFFFF0F0);
      case StudyEventType.deadline:
        return const Color(0xFFFFF8EE);
      case StudyEventType.submission:
        return const Color(0xFFF0F7FF);
      case StudyEventType.busy:
        return const Color(0xFFF5F5F5);
    }
  }
}

class StudyEvent {
  final String? firestoreId;
  final String ownerUid;
  final String ownerName;
  final String title;
  final String? description;
  final DateTime date;
  final StudyEventType type;
  final bool isDone;

  const StudyEvent({
    this.firestoreId,
    required this.ownerUid,
    required this.ownerName,
    required this.title,
    this.description,
    required this.date,
    required this.type,
    this.isDone = false,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'ownerUid': ownerUid,
      'ownerName': ownerName,
      'title': title,
      'description': description ?? '',
      'date': Timestamp.fromDate(date),
      'type': type.name,
      'isDone': isDone,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  factory StudyEvent.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return StudyEvent(
      firestoreId: doc.id,
      ownerUid: data['ownerUid'] as String? ?? '',
      ownerName: data['ownerName'] as String? ?? 'Partner',
      title: data['title'] as String? ?? '',
      description: (data['description'] as String?)?.isNotEmpty == true
          ? data['description'] as String
          : null,
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      type: StudyEventType.values.firstWhere(
        (e) => e.name == (data['type'] as String?),
        orElse: () => StudyEventType.deadline,
      ),
      isDone: data['isDone'] as bool? ?? false,
    );
  }

  StudyEvent copyWith({
    String? firestoreId,
    String? ownerUid,
    String? ownerName,
    String? title,
    String? description,
    DateTime? date,
    StudyEventType? type,
    bool? isDone,
  }) {
    return StudyEvent(
      firestoreId: firestoreId ?? this.firestoreId,
      ownerUid: ownerUid ?? this.ownerUid,
      ownerName: ownerName ?? this.ownerName,
      title: title ?? this.title,
      description: description ?? this.description,
      date: date ?? this.date,
      type: type ?? this.type,
      isDone: isDone ?? this.isDone,
    );
  }
}

