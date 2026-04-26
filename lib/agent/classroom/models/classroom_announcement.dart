// lib/agent/classroom/models/classroom_announcement.dart

/// Local model for a Google Classroom announcement.
class ClassroomAnnouncement {
  final String id;
  final String courseId;
  final String text;
  final DateTime? creationTime;
  final String? alternateLink;

  const ClassroomAnnouncement({
    required this.id,
    required this.courseId,
    required this.text,
    this.creationTime,
    this.alternateLink,
  });

  @override
  String toString() => 'ClassroomAnnouncement(id: $id, text: ${text.length > 40 ? "${text.substring(0, 40)}…" : text})';
}
