// lib/agent/classroom/classroom_service.dart
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/classroom/v1.dart' as classroom;
import 'models/classroom_assignment.dart';
import 'models/classroom_announcement.dart';

/// Wraps all Google Classroom REST API calls.
/// Uses extension_google_sign_in_as_googleapis_auth to silently obtain
/// a valid OAuth2 HTTP client from the already-signed-in GoogleSignIn account.
class ClassroomService {
  static const List<String> requiredScopes = [
    classroom.ClassroomApi.classroomCoursesReadonlyScope,
    classroom.ClassroomApi.classroomCourseworkMeReadonlyScope,
    classroom.ClassroomApi.classroomAnnouncementsReadonlyScope,
    classroom.ClassroomApi.classroomPushNotificationsScope,
  ];

  final GoogleSignIn _googleSignIn;

  ClassroomService({GoogleSignIn? googleSignIn})
      : _googleSignIn = googleSignIn ??
            GoogleSignIn(scopes: requiredScopes);

  // ── Internal: get an authenticated Classroom API client ───────────────────

  Future<classroom.ClassroomApi?> _getApi() async {
    try {
      // Ensure we are signed in (especially important in background isolates)
      if (_googleSignIn.currentUser == null) {
        debugPrint('ClassroomService: Attempting silent sign-in...');
        await _googleSignIn.signInSilently();
      }

      if (_googleSignIn.currentUser == null) {
        debugPrint('ClassroomService: No user signed in after silent check.');
        return null;
      }

      final client = await _googleSignIn.authenticatedClient();
      if (client == null) {
        debugPrint('ClassroomService: Failed to get authenticated HTTP client.');
        return null;
      }
      return classroom.ClassroomApi(client);
    } catch (e) {
      debugPrint('ClassroomService._getApi error: $e');
      return null;
    }
  }

  // ── Public API ────────────────────────────────────────────────────────────

  /// Returns all ACTIVE courses the signed-in user is enrolled in as a student.
  Future<List<classroom.Course>> fetchCourses() async {
    try {
      final api = await _getApi();
      if (api == null) return [];
      final response = await api.courses.list(studentId: 'me');
      final all = response.courses ?? [];
      return all.where((c) => c.courseState == 'ACTIVE').toList();
    } catch (e) {
      debugPrint('ClassroomService.fetchCourses error: $e');
      return [];
    }
  }

  /// Returns all coursework (assignments) for a given course, including
  /// the current user's submission status and grade.
  Future<List<ClassroomAssignment>> fetchCoursework(String courseId) async {
    try {
      final api = await _getApi();
      if (api == null) return [];

      // 1. Fetch all work
      final workResponse = await api.courses.courseWork.list(courseId);
      final rawWork = workResponse.courseWork ?? [];

      // 2. Fetch all student submissions for this course (efficiently)
      // The '-' value for courseWorkId means "all coursework in this course".
      final subResponse = await api.courses.courseWork.studentSubmissions.list(
        courseId,
        '-',
        userId: 'me',
      );
      final rawSubs = subResponse.studentSubmissions ?? [];

      // Create a map for quick lookup by courseWorkId
      final subMap = {for (var s in rawSubs) s.courseWorkId: s};

      return rawWork.map((w) {
        DateTime? due;
        final d = w.dueDate;
        if (d != null) {
          due = DateTime(d.year ?? 2000, d.month ?? 1, d.day ?? 1);
        }

        final sub = subMap[w.id];

        // Convert double safely (API returns double? or int?)
        double? grade = sub?.assignedGrade?.toDouble();
        double? maxPts = w.maxPoints?.toDouble();

        return ClassroomAssignment(
          id: w.id ?? '',
          courseId: courseId,
          title: w.title ?? '(Untitled)',
          description: w.description,
          dueDate: due,
          alternateLink: w.alternateLink,
          state: sub?.state,
          assignedGrade: grade,
          maxPoints: maxPts,
        );
      }).where((a) => a.id.isNotEmpty).toList();
    } catch (e) {
      debugPrint('ClassroomService.fetchCoursework error: $e');
      return [];
    }
  }

  /// Returns all announcements for a given course.
  Future<List<ClassroomAnnouncement>> fetchAnnouncements(String courseId) async {
    try {
      final api = await _getApi();
      if (api == null) return [];
      final response = await api.courses.announcements.list(courseId);
      return (response.announcements ?? []).map((a) {
        return ClassroomAnnouncement(
          id: a.id ?? '',
          courseId: courseId,
          text: a.text ?? '',
          creationTime: DateTime.tryParse(a.creationTime ?? ''),
          alternateLink: a.alternateLink,
        );
      }).where((a) => a.id.isNotEmpty).toList();
    } catch (e) {
      debugPrint('ClassroomService.fetchAnnouncements error: $e');
      return [];
    }
  }

  /// Registers a course to send push notifications to our Cloud Pub/Sub topic.
  /// Registrations expire after 7 days, so this should be called periodically.
  Future<bool> registerForPushNotifications(String courseId) async {
    try {
      final api = await _getApi();
      if (api == null) return false;

      final registration = classroom.Registration()
        ..feed = (classroom.Feed()
          ..feedType = 'COURSE_WORK_CHANGES'
          ..courseWorkChangesInfo = (classroom.CourseWorkChangesInfo()..courseId = courseId))
        ..cloudPubsubTopic = (classroom.CloudPubsubTopic()
          ..topicName = 'projects/aeternum-4ca15/topics/classroom-notifications');

      await api.registrations.create(registration);
      debugPrint('✅ ClassroomService: Registered push notifications for course $courseId');
      return true;
    } catch (e) {
      debugPrint('❌ ClassroomService.registerForPushNotifications error: $e');
      if (e.toString().contains('403')) {
        debugPrint('👉 Hint: This is a permissions error. You must Sign Out and Sign In again to grant the new scope.');
      }
      return false;
    }
  }

  /// Triggers a manual Google Sign-In popup. 
  /// Required to resolve 'DEVELOPER_ERROR' and grant new permissions.
  Future<void> signIn() async => await _googleSignIn.signIn();

  /// Clears the current session so the user can re-auth with new scopes.
  Future<void> signOut() async => await _googleSignIn.signOut();
}
