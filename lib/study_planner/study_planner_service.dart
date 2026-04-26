// lib/study_planner/study_planner_service.dart

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'study_event_model.dart';
import '../class_schedule/notification_service.dart';
import '../services/onesignal_service.dart';

class StudyPlannerService {
  static final StudyPlannerService _instance = StudyPlannerService._internal();
  factory StudyPlannerService() => _instance;
  StudyPlannerService._internal();

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
      debugPrint('StudyPlannerService: error getting pairId: $e');
      return null;
    }
  }

  Future<String?> _getDisplayName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 'Me';
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      return doc.data()?['displayName'] as String? ??
          user.displayName ??
          'Me';
    } catch (_) {
      return user.displayName ?? 'Me';
    }
  }

  CollectionReference _eventsCollection(String pairId) {
    return FirebaseFirestore.instance
        .collection('couples')
        .doc(pairId)
        .collection('study_events');
  }

  /// Real-time stream of all study events for the couple.
  Stream<List<StudyEvent>> eventsStream() async* {
    final pairId = await _getPairId();
    if (pairId == null) {
      yield [];
      return;
    }
    yield* _eventsCollection(pairId)
        .orderBy('date')
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => StudyEvent.fromFirestore(doc))
            .toList());
  }

  Future<void> addEvent(StudyEvent event) async {
    final uid = _myUid;
    final pairId = await _getPairId();
    final name = await _getDisplayName();
    if (uid == null || pairId == null) return;
    try {
      final withOwner = event.copyWith(ownerUid: uid, ownerName: name ?? 'Me');
      final docRef = await _eventsCollection(pairId).add(withOwner.toFirestore());
      
      // Schedule notifications
      await NotificationService().scheduleStudyEventNotifications(
        withOwner.copyWith(firestoreId: docRef.id),
      );

      // NEW: Trigger OneSignal Notification to partner
      _triggerOneSignalNotification('New Study Task: ${event.title}', pairId);

      debugPrint('StudyPlannerService: event added');
    } catch (e) {
      debugPrint('StudyPlannerService: addEvent failed: $e');
    }
  }

  /// Anyone in the pair can toggle isDone.
  Future<void> toggleDone(StudyEvent event) async {
    final pairId = await _getPairId();
    if (pairId == null || event.firestoreId == null) return;
    try {
      final newDoneStatus = !event.isDone;
      await _eventsCollection(pairId)
          .doc(event.firestoreId)
          .update({'isDone': newDoneStatus});
      
      // Update notifications based on new status
      final updatedEvent = event.copyWith(isDone: newDoneStatus);
      await NotificationService().scheduleStudyEventNotifications(updatedEvent);

      debugPrint('StudyPlannerService: event isDone toggled ${event.firestoreId}');
    } catch (e) {
      debugPrint('StudyPlannerService: toggleDone failed: $e');
    }
  }

  /// Only callable if event.ownerUid == current user's uid.
  Future<void> updateEvent(StudyEvent event) async {

    final uid = _myUid;
    final pairId = await _getPairId();
    if (uid == null || pairId == null || event.firestoreId == null) return;
    if (event.ownerUid != uid) {
      debugPrint('StudyPlannerService: updateEvent blocked — not owner');
      return;
    }
    try {
      await _eventsCollection(pairId)
          .doc(event.firestoreId)
          .update(event.toFirestore());
      
      // Update notifications
      await NotificationService().scheduleStudyEventNotifications(event);

      debugPrint('StudyPlannerService: event updated ${event.firestoreId}');
    } catch (e) {
      debugPrint('StudyPlannerService: updateEvent failed: $e');
    }
  }

  /// Only callable if event.ownerUid == current user's uid.
  Future<void> deleteEvent(StudyEvent event) async {
    final uid = _myUid;
    final pairId = await _getPairId();
    if (uid == null || pairId == null || event.firestoreId == null) return;
    if (event.ownerUid != uid) {
      debugPrint('StudyPlannerService: deleteEvent blocked — not owner');
      return;
    }
    try {
      await _eventsCollection(pairId).doc(event.firestoreId).delete();
      
      // Cancel notifications
      await NotificationService().cancelStudyEventNotifications(event);

      debugPrint('StudyPlannerService: event deleted ${event.firestoreId}');
    } catch (e) {
      debugPrint('StudyPlannerService: deleteEvent failed: $e');
    }
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
            title: 'Study Planner',
            content: text,
            data: {'type': 'study_planner'},
          );
        }
      }
    } catch (e) {
      debugPrint('Error triggering OneSignal notification: $e');
    }
  }
}
