// lib/screens/tracker/period_tracker_service.dart

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:menstrual_cycle_widget/database_helper/menstrual_cycle_db_helper.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart'; // ← NEW: For tracking initial sync
import 'database_helper_extensions.dart';

class PeriodTrackerService {
  static final PeriodTrackerService _instance = PeriodTrackerService._internal();

  factory PeriodTrackerService() => _instance;
  PeriodTrackerService._internal();

  final MenstrualCycleDbHelper _localDb = MenstrualCycleDbHelper.instance;

  Timer? _syncDebounce;
  bool _isSyncing = false;
  bool _hasInitialized = false;

  String? get _userId => FirebaseAuth.instance.currentUser?.uid;

  // SharedPreferences key to remember if we've ever done an initial sync
  static const String _kHasSyncedBefore = 'has_initial_sync_completed';

  /// Detect if this is a "new device" – no local data AND no previous sync flag
  Future<bool> _isNewDevice() async {
    final localDates = await _localDb.getPastPeriodDates();
    final bool hasLocalData = localDates.isNotEmpty;

    final prefs = await SharedPreferences.getInstance();
    final bool hasSyncedBefore = prefs.getBool(_kHasSyncedBefore) ?? false;

    return !hasLocalData && !hasSyncedBefore;
  }

  /// Mark that we've completed the initial setup (whether new or existing device)
  Future<void> _markInitialSyncComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kHasSyncedBefore, true);
    _hasInitialized = true;
  }

  /// Allows a manual refresh to re-run the full sync even if already initialized.
  void resetForRefresh() {
    _hasInitialized = false;
  }

  /// Main entry point – call this once after login / app start
  Future<void> initializeSync() async {
    if (_hasInitialized) {
      print('🔄 Already initialized — skipping');
      return;
    }

    print('🔄 Starting initial sync...');

    final connectivityResult = await Connectivity().checkConnectivity();
    final bool isOnline = connectivityResult != ConnectivityResult.none;

    if (isOnline) {
      final bool isNewDevice = await _isNewDevice();

      if (isNewDevice) {
        print('🆕 New device detected — pulling data from Firebase');
        bool success = await syncFirebaseToLocal(initialSetup: true);
        if (success) {
          await _markInitialSyncComplete();
          print('✅ New device setup complete');
        } else {
          print('❌ New device setup FAILED (download error) — will retry next time');
        }
      } else {
        print('📱 Existing device — pushing local data to Firebase');
        await syncLocalToFirebase();
        await _markInitialSyncComplete();
        print('✅ Existing device sync complete');
      }
    } else {
      print('📴 Offline — using local data only');
      final localDates = await _localDb.getPastPeriodDates();
      if (localDates.isNotEmpty) {
        // If we have local data, we're "initialized" enough to work offline,
        // but we don't mark _kHasSyncedBefore yet because we still want to
        // run the online sync branch (either pull or push) when next online.
        _hasInitialized = true; 
      } else {
        print('⚠️ New device AND offline — sync deferred until online');
      }
    }
  }

  /// Called whenever the user modifies period dates locally
  void onLocalDataChanged() {
    print('📅 Local data changed — debouncing sync...');
    _syncDebounce?.cancel();
    _syncDebounce = Timer(const Duration(milliseconds: 1000), () async {
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult != ConnectivityResult.none) {
        await syncLocalToFirebase();
        print('☁️ Synced local changes to Firebase (local is source of truth)');
      } else {
        print('📴 Offline — changes saved locally, will sync when online');
      }
    });
  }

  void dispose() {
    _syncDebounce?.cancel();
  }

  /// Push local state to Firebase – LOCAL IS THE SOURCE OF TRUTH.
  ///
  /// Each period cycle is stored as exactly ONE document whose ID is the
  /// startDate string (e.g. "2025-01-15"). Using startDate as the doc ID
  /// makes every sync fully idempotent: the same period always maps to the
  /// same document, so re-running this method can never create duplicates.
  ///
  /// On every run:
  ///   • Desired docs (derived from local dates) are set via batch.set → create or overwrite.
  ///   • Any Firebase doc whose ID is NOT in the desired set is deleted.
  ///
  /// This also auto-cleans any leftover random-UUID docs from the old
  /// two-pointer algorithm – they don’t match any startDate key so they
  /// get deleted on the first run of the new code.
  Future<void> syncLocalToFirebase() async {
    if (_userId == null) {
      print('🔴 No user — skip upload');
      return;
    }
    if (_isSyncing) {
      print('⏳ Already syncing — skip');
      return;
    }
    _isSyncing = true;

    try {
      final List<String> localDates = await _localDb.getPastPeriodDates();

      // Deduplicate dates — the SQLite table has no UNIQUE constraint so the
      // old onDataChanged loop could insert the same date multiple times.
      // The calendar widget deduplicates visually, but the graph widgets
      // (MenstrualCycleHistoryGraph, MenstrualCyclePeriodsGraph) count raw
      // rows, so they show double/triple the real bleeding days.
      // If duplicates are found, clear and re-insert the clean unique set
      // so the DB heals itself on the very next sync.
      final uniqueDates = localDates.toSet().toList()..sort();
      if (uniqueDates.length != localDates.length) {
        print('🧹 Duplicate dates detected (${localDates.length} rows, ${uniqueDates.length} unique) — cleaning local DB...');
        await _localDb.clearAllPeriodData();
        if (uniqueDates.isNotEmpty) {
          await _localDb.insertPeriodLog(
            uniqueDates.map((d) => DateTime.parse(d)).toList(),
          );
        }
        print('✅ Local DB deduplicated: ${uniqueDates.length} dates restored');
      }
      print('📅 Local dates (${uniqueDates.length}): $uniqueDates');

      final collection = FirebaseFirestore.instance
          .collection('users')
          .doc(_userId)
          .collection('period_cycles');

      // ── Build consecutive period ranges ──────────────────────────────────
      final List<Map<String, dynamic>> desiredRanges = [];

      if (uniqueDates.isNotEmpty) {
        String rangeStart = uniqueDates[0];
        String rangeEnd   = uniqueDates[0];

        for (int i = 1; i < uniqueDates.length; i++) {
          final prev = DateTime.parse(uniqueDates[i - 1]);
          final curr = DateTime.parse(uniqueDates[i]);
          if (curr.difference(prev).inDays == 1) {
            rangeEnd = uniqueDates[i]; // extend current range
          } else {
            desiredRanges.add({'startDate': rangeStart, 'endDate': rangeEnd});
            rangeStart = rangeEnd = uniqueDates[i]; // start new range
          }
        }
        desiredRanges.add({'startDate': rangeStart, 'endDate': rangeEnd});

        // Attach cycleLength = days between this start and next start
        for (int i = 0; i < desiredRanges.length; i++) {
          if (i < desiredRanges.length - 1) {
            final thisStart = DateTime.parse(desiredRanges[i]['startDate'] as String);
            final nextStart = DateTime.parse(desiredRanges[i + 1]['startDate'] as String);
            desiredRanges[i]['cycleLength'] = nextStart.difference(thisStart).inDays;
          } else {
            desiredRanges[i]['cycleLength'] = null; // last (or only) cycle
          }
        }
      }

      // ── Build a map keyed by startDate ────────────────────────────────────
      // doc ID = startDate string  (e.g. "2025-01-15")
      final Map<String, Map<String, dynamic>> desired = {
        for (final r in desiredRanges) r['startDate'] as String: r,
      };

      // ── Fetch existing Firebase docs ──────────────────────────────────────
      final snapshot = await collection.get();

      final batch = FirebaseFirestore.instance.batch();

      // ── Delete Stale Docs ──────────────────────────────────────────────────
      // Safety Guard & Auto-Healing: If local is empty but Firebase has data,
      // it means the user likely lost local data (reinstall/cache clear) 
      // but the initial sync pull was skipped or failed. 
      // Instead of wiping Firestore, we PULL the data to heal the local DB.
      if (desired.isEmpty && snapshot.docs.isNotEmpty) {
        print('⚠️ Safety Trigger: Local DB is empty but Firebase has docs. Wiping BLOCKED.');
        print('🔄 Auto-healing: Pulling data from Firebase to restore local state...');
        await syncFirebaseToLocal(initialSetup: true);
        return; // Stop here; the next sync or local change will handle uploads
      } else {
        for (final doc in snapshot.docs) {
          if (!desired.containsKey(doc.id)) {
            batch.delete(doc.reference);
            print('🗑️ Deleted stale/orphan doc: ${doc.id}');
          }
        }
      }

      // Create or overwrite each desired range (startDate = doc ID)
      for (final entry in desired.entries) {
        final ref = collection.doc(entry.key);
        batch.set(ref, entry.value); // set() = create if missing, overwrite if present
        print('✅ Set [${entry.key}]: ${entry.value}');
      }

      await batch.commit();
      print('✅ Local → Firebase sync complete (${desired.length} cycle docs)');

    } catch (e, stack) {
      print('🔥 Sync upload FAILED: $e');
      print(stack);
    } finally {
      _isSyncing = false;
    }
  }

  /// Pull from Firebase → local ONLY during initial setup on new devices
  Future<bool> syncFirebaseToLocal({required bool initialSetup}) async {
    if (_userId == null) return false;

    if (!initialSetup) {
      print('⚠️ syncFirebaseToLocal called outside initial setup — ignored');
      return false;
    }

    try {
      final collection = FirebaseFirestore.instance
          .collection('users')
          .doc(_userId)
          .collection('period_cycles');

      final snapshot = await collection.get();
      print('☁️ Downloaded ${snapshot.docs.length} cycle ranges from Firebase (initial setup)');

      // For new device, we can safely clear local (should be empty anyway)
      await _localDb.clearAllPeriodData();
      print('🗑️ Cleared local DB for fresh import');

      final List<DateTime> toInsert = [];

      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final String? startStr = data['startDate'] as String?;
        final String? endStr = data['endDate'] as String?;

        if (startStr == null || endStr == null) continue;

        DateTime start = DateTime.parse(startStr);
        DateTime end = DateTime.parse(endStr);

        DateTime current = start;
        while (!current.isAfter(end)) {
          toInsert.add(current);
          current = current.add(const Duration(days: 1));
        }
      }

      if (toInsert.isNotEmpty) {
        await _localDb.insertPeriodLog(toInsert);
        print('📲 Inserted ${toInsert.length} dates from Firebase into local DB');
      } else {
        print('✅ Firebase was empty — nothing to import');
      }
      return true;
    } catch (e) {
      print('🔥 Initial download failed: $e');
      return false;
    }
  }

  /// Optional: Manual trigger for new devices that were offline during first launch
  Future<void> manualInitialSyncFromFirebase() async {
    final bool isNew = await _isNewDevice();
    if (!isNew) {
      print('⚠️ Manual sync blocked — local already has data');
      return;
    }

    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity == ConnectivityResult.none) {
      print('📴 Offline — cannot perform manual sync');
      return;
    }

    print('🔄 Manual initial sync from Firebase...');
    await syncFirebaseToLocal(initialSetup: true);
    await _markInitialSyncComplete();
  }
}