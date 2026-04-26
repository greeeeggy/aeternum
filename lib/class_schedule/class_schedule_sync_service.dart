// lib/class_schedule/class_schedule_sync_service.dart
//
// Syncs class schedules to/from Firestore under the shared couple document.
// Collection path: couples/{pairId}/class_schedules
//
// Pattern mirrors PartnerSyncService used by the period tracker.

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'class_model.dart';
import 'class_schedule_database.dart';
import 'schedule_group_model.dart';
import '../services/onesignal_service.dart';

class ClassScheduleSyncService {
  static final ClassScheduleSyncService _instance =
      ClassScheduleSyncService._internal();
  factory ClassScheduleSyncService() => _instance;
  ClassScheduleSyncService._internal();

  final _db = ClassScheduleDatabase();

  /// Broadcasts whenever a Firestore sync completes so the scheduler can reload.
  final _syncDoneController = StreamController<void>.broadcast();
  Stream<void> get onSyncDone => _syncDoneController.stream;

  StreamSubscription<QuerySnapshot>? _listener;
  bool _listenerPaused = false;

  void dispose() {
    _listener?.cancel();
    _listener = null;
  }

  /// Temporarily suppress listener callbacks (e.g. during local insert).
  void pauseListener() => _listenerPaused = true;

  /// Re-enable listener callbacks.
  void resumeListener() => _listenerPaused = false;

  // ── Helpers ──────────────────────────────────────────────────────────────

  String? get _myUid => FirebaseAuth.instance.currentUser?.uid;

  Future<String?> _getPairId() async {
    final uid = _myUid;
    if (uid == null) return null;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      return doc.data()?['pairId'] as String?;
    } catch (e) {
      debugPrint('ClassScheduleSyncService: error getting pairId: $e');
      return null;
    }
  }

  CollectionReference? _schedulesCollection(String pairId) {
    return FirebaseFirestore.instance
        .collection('couples')
        .doc(pairId)
        .collection('class_schedules');
  }

  CollectionReference? _groupsCollection(String pairId) {
    return FirebaseFirestore.instance
        .collection('couples')
        .doc(pairId)
        .collection('schedule_groups');
  }

  // ── Group Write ──────────────────────────────────────────────────────────

  /// Push a new schedule group to Firestore. Returns doc ID or null.
  Future<String?> pushGroup(ScheduleGroup group) async {
    final pairId = await _getPairId();
    if (pairId == null) return null;
    try {
      final ref = await _groupsCollection(pairId)!.add(group.toFirestore());
      debugPrint('ClassScheduleSyncService: pushed group ${ref.id}');
      
      // NEW: Trigger OneSignal Notification to partner
      _triggerOneSignalNotification('New Schedule Group: ${group.name}', pairId);

      return ref.id;
    } catch (e) {
      debugPrint('ClassScheduleSyncService: pushGroup failed: $e');
      return null;
    }
  }

  // ── Write (called after local insert) ────────────────────────────────────

  /// Push a newly added class to Firestore.
  /// Returns the Firestore doc ID, or null on failure.
  Future<String?> pushClass(ClassSchedule classSchedule) async {
    final uid = _myUid;
    final pairId = await _getPairId();
    if (uid == null || pairId == null) {
      debugPrint('ClassScheduleSyncService: not logged in or not paired → skip push');
      return null;
    }

    try {
      final ref = await _schedulesCollection(pairId)!
          .add(classSchedule.toFirestore(ownerUid: uid));
      debugPrint('ClassScheduleSyncService: pushed class ${ref.id}');
      
      // NEW: Trigger OneSignal Notification to partner
      _triggerOneSignalNotification('New Class Added: ${classSchedule.subjectName}', pairId);

      return ref.id;
    } catch (e) {
      debugPrint('ClassScheduleSyncService: push failed: $e');
      return null;
    }
  }

  /// Update an existing Firestore document for a class.
  Future<void> updateClass(ClassSchedule classSchedule) async {
    final uid = _myUid;
    final pairId = await _getPairId();
    if (uid == null || pairId == null || classSchedule.firestoreId == null) return;

    try {
      await _schedulesCollection(pairId)!
          .doc(classSchedule.firestoreId)
          .set(classSchedule.toFirestore(ownerUid: uid));
      debugPrint('ClassScheduleSyncService: updated ${classSchedule.firestoreId}');
      
      // NEW: Trigger OneSignal Notification to partner
      _triggerOneSignalNotification('Class Updated: ${classSchedule.subjectName}', pairId);
    } catch (e) {
      debugPrint('ClassScheduleSyncService: update failed: $e');
    }
  }

  /// Delete a schedule group from Firestore.
  Future<void> deleteGroup(String firestoreId) async {
    final pairId = await _getPairId();
    if (pairId == null) return;
    try {
      await _groupsCollection(pairId)!.doc(firestoreId).delete();
      debugPrint('ClassScheduleSyncService: deleted group $firestoreId');
    } catch (e) {
      debugPrint('ClassScheduleSyncService: deleteGroup failed: $e');
    }
  }

  /// Delete a class from Firestore.
  Future<void> deleteClass(String firestoreId) async {
    final pairId = await _getPairId();
    if (pairId == null) return;

    try {
      await _schedulesCollection(pairId)!.doc(firestoreId).delete();
      debugPrint('ClassScheduleSyncService: deleted $firestoreId from Firestore');
    } catch (e) {
      debugPrint('ClassScheduleSyncService: delete failed: $e');
    }
  }

  // ── Read / Real-time listener ─────────────────────────────────────────────

  /// Pull all groups + schedules from Firestore and upsert into local SQLite.
  /// Called once on startup and also triggered by the real-time listener.
  Future<void> syncFromFirestore() async {
    final pairId = await _getPairId();
    if (pairId == null) {
      debugPrint('ClassScheduleSyncService: no pairId → skip sync');
      return;
    }

    try {
      // ── Sync groups ──────────────────────────────────────────────────────
      final groupSnapshot = await _groupsCollection(pairId)!.get();
      for (final doc in groupSnapshot.docs) {
        final group = ScheduleGroup.fromFirestore(
            doc.id, doc.data() as Map<String, dynamic>);
        await _db.upsertGroupByFirestoreId(group);
      }
      // Remove stale local groups
      final remoteGroupIds = groupSnapshot.docs.map((d) => d.id).toSet();
      final localGroups = await _db.getAllGroups();
      for (final local in localGroups) {
        if (local.firestoreId != null &&
            !remoteGroupIds.contains(local.firestoreId)) {
          await _db.deleteGroupByFirestoreId(local.firestoreId!);
        }
      }

      // ── Sync class schedules ─────────────────────────────────────────────
      final snapshot = await _schedulesCollection(pairId)!.get();
      for (final doc in snapshot.docs) {
        final schedule = ClassSchedule.fromFirestore(doc);
        await _db.upsertByFirestoreId(schedule);
      }
      final remoteIds = snapshot.docs.map((d) => d.id).toSet();
      final localAll = await _db.getAllClasses();
      for (final local in localAll) {
        if (local.firestoreId != null &&
            !remoteIds.contains(local.firestoreId)) {
          await _db.deleteByFirestoreId(local.firestoreId!);
        }
      }

      debugPrint(
          'ClassScheduleSyncService: synced ${groupSnapshot.docs.length} groups + ${snapshot.docs.length} classes');
      _syncDoneController.add(null);
    } catch (e) {
      debugPrint('ClassScheduleSyncService: syncFromFirestore failed: $e');
    }
  }

  /// Attaches a real-time Firestore listener so both partners see live updates.
  /// Call this once when the ClassScheduler page mounts.
  Future<void> startListening() async {
    final pairId = await _getPairId();
    if (pairId == null) {
      debugPrint('ClassScheduleSyncService: no pairId → listener not started');
      return;
    }

    await _listener?.cancel();

    _listener = _groupsCollection(pairId)!
        .snapshots()
        .listen((snapshot) async {
      if (_listenerPaused) {
        debugPrint('ClassScheduleSyncService: listener paused, skipping sync');
        return;
      }
      debugPrint(
          'ClassScheduleSyncService: Firestore change detected, re-syncing...');
      await syncFromFirestore();
    }, onError: (e) {
      debugPrint('ClassScheduleSyncService listener error: $e');
    });

    debugPrint('ClassScheduleSyncService: real-time listener started for pair $pairId');
  }

  Future<void> _triggerOneSignalNotification(String text, String pairId) async {
    try {
      final coupleDoc = await FirebaseFirestore.instance.collection('couples').doc(pairId).get();
      if (coupleDoc.exists) {
        final members = List<String>.from(coupleDoc.data()?['members'] ?? []);
        final partnerUid = members.firstWhere((uid) => uid != _myUid, orElse: () => '');
        if (partnerUid.isNotEmpty) {
          await OneSignalService().sendNotification(
            targetExternalIds: [partnerUid],
            title: 'Class Schedule',
            content: text,
            data: {'type': 'class_schedule'},
          );
        }
      }
    } catch (e) {
      debugPrint('Error triggering OneSignal notification: $e');
    }
  }
}
