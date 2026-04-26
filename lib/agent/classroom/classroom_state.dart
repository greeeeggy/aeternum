// lib/agent/classroom/classroom_state.dart
import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import 'models/classroom_assignment.dart';

/// Persists last-seen assignment/announcement IDs per course using Hive.
/// This is how the monitor knows what is "new" on the next poll.
/// Box name: 'agent_classroom_state' — kept separate from all other app boxes.
class ClassroomState {
  ClassroomState._();

  static const _boxName = 'agent_classroom_state';

  static Future<void> ensureOpen() async {
    if (!Hive.isBoxOpen(_boxName)) {
      await Hive.openBox<String>(_boxName);
    }
  }

  static Box<String> get _box => Hive.box<String>(_boxName);

  // ── Assignment IDs ────────────────────────────────────────────────────────

  static Set<String> getSeenAssignmentIds(String courseId) {
    final raw = _box.get('assign_$courseId') ?? '';
    if (raw.isEmpty) return {};
    return raw.split(',').toSet();
  }

  static Future<void> markAssignmentsSeen(
      String courseId, Set<String> ids) async {
    await _box.put('assign_$courseId', ids.join(','));
  }

  // ── Announcement IDs ──────────────────────────────────────────────────────

  static Set<String> getSeenAnnouncementIds(String courseId) {
    final raw = _box.get('ann_$courseId') ?? '';
    if (raw.isEmpty) return {};
    return raw.split(',').toSet();
  }

  static Future<void> markAnnouncementsSeen(
      String courseId, Set<String> ids) async {
    await _box.put('ann_$courseId', ids.join(','));
  }

  // ── Last sync timestamp ───────────────────────────────────────────────────

  static String? getLastSyncTime() => _box.get('last_sync_time');

  static Future<void> setLastSyncTime(String iso) =>
      _box.put('last_sync_time', iso);

  // ── Cached course names (courseId → name) for UI display ─────────────────

  static Map<String, String> getCourseNames() {
    final raw = _box.get('course_names') ?? '';
    if (raw.isEmpty) return {};
    final pairs = raw.split('|');
    final map = <String, String>{};
    for (final pair in pairs) {
      final parts = pair.split(':');
      if (parts.length == 2) map[parts[0]] = parts[1];
    }
    return map;
  }

  static Future<void> setCourseNames(Map<String, String> names) async {
    final encoded = names.entries.map((e) => '${e.key}:${e.value}').join('|');
    await _box.put('course_names', encoded);
  }

  // ── Cached assignments (courseId → List<Assignment>) ─────────────────────

  static Map<String, List<ClassroomAssignment>> getAssignments() {
    final raw = _box.get('cached_assignments') ?? '';
    if (raw.isEmpty) return {};
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final result = <String, List<ClassroomAssignment>>{};
      data.forEach((courseId, list) {
        if (list is List) {
          result[courseId] = list
              .map((json) => ClassroomAssignment.fromJson(json))
              .toList();
        }
      });
      return result;
    } catch (e) {
      return {};
    }
  }

  static Future<void> setAssignments(
      Map<String, List<ClassroomAssignment>> assignments) async {
    final map = <String, dynamic>{};
    assignments.forEach((courseId, list) {
      map[courseId] = list.map((a) => a.toJson()).toList();
    });
    await _box.put('cached_assignments', jsonEncode(map));
  }
}
