// lib/agent/classroom/models/classroom_assignment.dart

/// Local model for a Google Classroom assignment (CourseWork).
class ClassroomAssignment {
  final String id;
  final String courseId;
  final String title;
  final String? description;
  final DateTime? dueDate;
  final String? alternateLink;

  // Submission info
  final String? state; // e.g. 'TURNED_IN', 'RETURNED', 'NEW'
  final double? assignedGrade;
  final double? maxPoints;

  const ClassroomAssignment({
    required this.id,
    required this.courseId,
    required this.title,
    this.description,
    this.dueDate,
    this.alternateLink,
    this.state,
    this.assignedGrade,
    this.maxPoints,
  });

  bool get isSubmitted => state == 'TURNED_IN' || state == 'RETURNED';

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'courseId': courseId,
      'title': title,
      'description': description,
      'dueDate': dueDate?.toIso8601String(),
      'alternateLink': alternateLink,
      'state': state,
      'assignedGrade': assignedGrade,
      'maxPoints': maxPoints,
    };
  }

  factory ClassroomAssignment.fromJson(Map<String, dynamic> json) {
    return ClassroomAssignment(
      id: json['id'] as String,
      courseId: json['courseId'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      dueDate: json['dueDate'] != null ? DateTime.parse(json['dueDate'] as String) : null,
      alternateLink: json['alternateLink'] as String?,
      state: json['state'] as String?,
      assignedGrade: (json['assignedGrade'] as num?)?.toDouble(),
      maxPoints: (json['maxPoints'] as num?)?.toDouble(),
    );
  }

  @override
  String toString() => 'ClassroomAssignment(id: $id, title: $title, state: $state)';
}
