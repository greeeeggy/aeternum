// lib/class_schedule/class_model.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ClassSchedule {
  final String? id;
  final String? firestoreId; // Firestore document ID for sync
  final String? groupId;    // which ScheduleGroup this belongs to (firestoreId of group)
  final String? ownerUid;  // who created this class (for read-only enforcement)
  final int dayOfWeek; // 0 = Sunday, 1 = Monday, ..., 6 = Saturday
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final String subjectName;
  final String professorName;
  final Color color;

  ClassSchedule({
    this.id,
    this.firestoreId,
    this.groupId,
    this.ownerUid,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    required this.subjectName,
    required this.professorName,
    required this.color,
  });

  // Convert TimeOfDay to minutes since midnight for easy comparison
  int get startMinutes => startTime.hour * 60 + startTime.minute;
  int get endMinutes => endTime.hour * 60 + endTime.minute;

  // Check if this class conflicts with lunch (12:00 PM - 1:00 PM)
  bool get conflictsWithLunch {
    const lunchStart = 12 * 60; // 12:00 PM in minutes
    const lunchEnd = 13 * 60; // 1:00 PM in minutes

    return (startMinutes < lunchEnd && endMinutes > lunchStart);
  }

  String getTimeRange() {
    return '${_formatTime(startTime)} - ${_formatTime(endTime)}';
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  /// Used when writing to Firestore (includes owner uid for filtering)
  Map<String, dynamic> toFirestore({required String ownerUid}) {
    return {
      'dayOfWeek': dayOfWeek,
      'startHour': startTime.hour,
      'startMinute': startTime.minute,
      'endHour': endTime.hour,
      'endMinute': endTime.minute,
      'subjectName': subjectName,
      'professorName': professorName,
      'colorValue': color.value,
      'ownerUid': ownerUid,
      'groupId': groupId,
      'updatedAt': DateTime.now().toIso8601String(),
    };
  }

  Map<String, dynamic> toMap() {
    return {
      'dayOfWeek': dayOfWeek,
      'startHour': startTime.hour,
      'startMinute': startTime.minute,
      'endHour': endTime.hour,
      'endMinute': endTime.minute,
      'subjectName': subjectName,
      'professorName': professorName,
      'colorValue': color.value,
      if (groupId != null) 'groupId': groupId,
      if (ownerUid != null) 'ownerUid': ownerUid,
    };
  }

  /// Reconstruct from a plain map (e.g. from SQLite row)
  factory ClassSchedule.fromMap(Map<String, dynamic> map) {
    return ClassSchedule(
      id: map['id']?.toString(),
      dayOfWeek: map['dayOfWeek'] ?? 0,
      startTime: TimeOfDay(
        hour: map['startHour'] ?? 0,
        minute: map['startMinute'] ?? 0,
      ),
      endTime: TimeOfDay(
        hour: map['endHour'] ?? 0,
        minute: map['endMinute'] ?? 0,
      ),
      subjectName: map['subjectName'] ?? '',
      professorName: map['professorName'] ?? '',
      color: Color(map['colorValue'] ?? Colors.blue.value),
      firestoreId: map['firestoreId'] as String?,
      groupId: map['groupId'] as String?,
      ownerUid: map['ownerUid'] as String?,
    );
  }

  factory ClassSchedule.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ClassSchedule(
      id: doc.id,
      firestoreId: doc.id,
      groupId: data['groupId'] as String?,
      ownerUid: data['ownerUid'] as String?,
      dayOfWeek: data['dayOfWeek'] ?? 0,
      startTime: TimeOfDay(
        hour: data['startHour'] ?? 0,
        minute: data['startMinute'] ?? 0,
      ),
      endTime: TimeOfDay(
        hour: data['endHour'] ?? 0,
        minute: data['endMinute'] ?? 0,
      ),
      subjectName: data['subjectName'] ?? '',
      professorName: data['professorName'] ?? '',
      color: Color(data['colorValue'] ?? Colors.blue.value),
    );
  }

  ClassSchedule copyWith({
    String? id,
    String? firestoreId,
    String? groupId,
    String? ownerUid,
    int? dayOfWeek,
    TimeOfDay? startTime,
    TimeOfDay? endTime,
    String? subjectName,
    String? professorName,
    Color? color,
  }) {
    return ClassSchedule(
      id: id ?? this.id,
      firestoreId: firestoreId ?? this.firestoreId,
      groupId: groupId ?? this.groupId,
      ownerUid: ownerUid ?? this.ownerUid,
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      subjectName: subjectName ?? this.subjectName,
      professorName: professorName ?? this.professorName,
      color: color ?? this.color,
    );
  }
}