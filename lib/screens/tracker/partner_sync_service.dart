import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart'; // for debugPrint
import 'package:menstrual_cycle_widget/database_helper/menstrual_cycle_db_helper.dart';
import 'package:menstrual_cycle_widget/database_helper/encryption_file.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'symptom_database_helper.dart';

class PartnerSyncService {
  static final PartnerSyncService _instance = PartnerSyncService._internal();
  factory PartnerSyncService() => _instance;
  PartnerSyncService._internal();

  // ── Cached sync state ──────────────────────────────────────────────────────
  /// True after the first successful sync. Used to skip the loading spinner
  /// on repeat visits — the calendar already has data in SQLite.
  bool hasSyncedOnce = false;

  /// Broadcasts whenever a fresh sync completes so the page can bump its
  /// calendar key without showing a full-screen spinner.
  final _syncDoneController = StreamController<void>.broadcast();
  Stream<void> get onSyncDone => _syncDoneController.stream;

  /// Active Firestore listener — cancelled when the page disposes.
  StreamSubscription<QuerySnapshot>? _periodListener;

  /// Guard against concurrent sync calls (e.g. _syncData + listener firing simultaneously)
  bool _isSyncing = false;

  void dispose() {
    _periodListener?.cancel();
    _periodListener = null;
  }

  /// Returns true only if the current user is 'boyfriend'
  Future<bool> _isBoyfriend() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      final role = doc.data()?['role'] as String?;
      return role == 'boyfriend';
    } catch (e) {
      debugPrint("Error checking role: $e");
      return false;
    }
  }

  /// Gets the partner's UID (the other member in the couple/pair)
  Future<String?> _getPartnerUid() async {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null) return null;

    final myDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(myUid)
        .get();

    final pairId = myDoc.data()?['pairId'] as String?;
    if (pairId == null) return null;

    final coupleDoc = await FirebaseFirestore.instance
        .collection('couples')
        .doc(pairId)
        .get();

    if (!coupleDoc.exists) return null;

    final members = (coupleDoc.data()?['members'] as List<dynamic>?)?.cast<String>() ?? [];
    final partnerUid = members.firstWhere(
          (uid) => uid != myUid,
      orElse: () => '',
    );

    return partnerUid.isNotEmpty ? partnerUid : null;
  }

  /// Attaches a real-time Firestore listener on the girlfriend's period_cycles
  /// collection. Each time data changes it re-syncs to local SQLite and emits
  /// on [onSyncDone] so the calendar key can be bumped silently.
  Future<void> startListening() async {
    if (!await _isBoyfriend()) return;
    final girlfriendUid = await _getPartnerUid();
    if (girlfriendUid == null) return;

    // Cancel any existing listener before attaching a new one
    await _periodListener?.cancel();

    _periodListener = FirebaseFirestore.instance
        .collection('users')
        .doc(girlfriendUid)
        .collection('period_cycles')
        .snapshots()
        .listen((snapshot) async {
      debugPrint('PartnerSyncService: period_cycles changed, re-syncing...');
      await syncGirlfriendPeriodsToLocal();
    }, onError: (e) {
      debugPrint('PartnerSyncService listener error: $e');
    });
  }

  /// Pulls the girlfriend's period data from Firestore and injects it into the local database.
  /// Only executes if the current user is 'boyfriend'.
  /// Clears existing local period logs first (so boyfriend only sees girlfriend's data).
  Future<void> syncGirlfriendPeriodsToLocal() async {
    if (_isSyncing) {
      debugPrint("syncGirlfriendPeriodsToLocal: Already syncing — skipped to prevent duplicate rows");
      return;
    }
    if (!await _isBoyfriend()) {
      debugPrint("syncGirlfriendPeriodsToLocal: Called on non-boyfriend device → skipped");
      return;
    }
    _isSyncing = true;

    debugPrint("Starting partner sync (boyfriend mode)");

    final girlfriendUid = await _getPartnerUid();
    if (girlfriendUid == null || girlfriendUid.isEmpty) {
      debugPrint("No partner UID found → cannot sync");
      return;
    }

    // Add to PartnerSyncService class

    try {
      // Fetch girlfriend's cycle ranges from Firestore
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(girlfriendUid)
          .collection('period_cycles')
          .get();

      if (snapshot.docs.isEmpty) {
        debugPrint("Girlfriend has no period cycles in Firestore yet");
        hasSyncedOnce = true;
        _syncDoneController.add(null);
        return;
      }

      final List<DateTime> allPeriodDays = [];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final startStr = data['startDate'] as String?;
        final endStr = data['endDate'] as String?;
        if (startStr == null || endStr == null) continue;

        final start = DateTime.tryParse(startStr);
        final end = DateTime.tryParse(endStr);
        if (start == null || end == null) continue;

        DateTime current = start;
        while (!current.isAfter(end)) {
          allPeriodDays.add(current);
          current = current.add(const Duration(days: 1));
        }
      }

      if (allPeriodDays.isEmpty) {
        debugPrint("No period days found after expanding ranges");
        hasSyncedOnce = true;
        _syncDoneController.add(null);
        return;
      }

      // Write directly to SQLite using the encrypted UID as customerId.
      // We bypass insertPeriodLog() because it internally calls
      // MenstrualCycleWidget.instance!.getCustomerId() which is unreliable
      // before updateConfiguration() has fully completed (it's async void).
      // By encrypting the UID ourselves we always use the correct bucket.
      final myUid = FirebaseAuth.instance.currentUser?.uid ?? '0';
      final encryptedCustomerId = Encryption.instance.encrypt(myUid);
      final db = await MenstrualCycleDbHelper.instance.database;

      // Clear existing rows for this user so removed dates don't linger
      await db!.delete(
        MenstrualCycleDbHelper.tableUserPeriodsLogsData,
        where: '${MenstrualCycleDbHelper.columnCustomerId} = ?',
        whereArgs: [encryptedCustomerId],
      );

      // Insert each day directly with the correct encrypted customerId
      for (final day in allPeriodDays) {
        final encryptedDate = Encryption.instance.encrypt(
          '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}',
        );
        await db.insert(
          MenstrualCycleDbHelper.tableUserPeriodsLogsData,
          {
            MenstrualCycleDbHelper.columnCustomerId: encryptedCustomerId,
            MenstrualCycleDbHelper.columnPeriodEncryptDate: encryptedDate,
          },
          conflictAlgorithm: sqflite.ConflictAlgorithm.ignore,
        );
      }

      debugPrint("Synced ${allPeriodDays.length} period days for uid: $myUid");

      // Mark as synced and notify listeners
      hasSyncedOnce = true;
      _syncDoneController.add(null);
    } catch (e, stack) {
      debugPrint("Partner sync failed: $e");
      debugPrint(stack.toString());
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> syncGirlfriendSymptomsToLocal({int limit = 60}) async {
    if (!await _isBoyfriend()) {
      debugPrint("syncGirlfriendSymptomsToLocal: Called on non-boyfriend → skipped");
      return;
    }

    final girlfriendUid = await _getPartnerUid();
    if (girlfriendUid == null || girlfriendUid.isEmpty) {
      debugPrint("No partner UID → cannot sync symptoms");
      return;
    }

    try {
      // Fetch last N days of symptoms (ordered by date DESC)
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(girlfriendUid)
          .collection('daily_symptom_logs')
          .orderBy('date', descending: true)
          .limit(limit)
          .get();

      if (snapshot.docs.isEmpty) {
        debugPrint("Girlfriend has no symptom logs in Firestore yet");
        return;
      }

      debugPrint("Downloaded ${snapshot.docs.length} symptom logs from girlfriend");

      // Save each log to local DB
      for (var doc in snapshot.docs) {
        final data = Map<String, dynamic>.from(doc.data());
        data['date'] = doc.id; // ensure 'date' key is present (matches your DB schema)
        await SymptomDatabaseHelper.instance.saveDailyLog(data);
      }

      debugPrint("Successfully saved ${snapshot.docs.length} symptom logs locally");
    } catch (e, stack) {
      debugPrint("Symptoms sync failed: $e");
      debugPrint(stack.toString());
    }
  }

  /// Optional: call this when leaving the boyfriend view page
  /// (to reset or clean up if needed)
  Future<void> cleanup() async {
    if (await _isBoyfriend()) {
      debugPrint("PartnerSyncService cleanup called (boyfriend mode)");
      // You could re-clear or leave as is — data persists until next sync
    }
  }
}