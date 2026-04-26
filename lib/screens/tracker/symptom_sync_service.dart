// lib/screens/tracker/symptom_sync_service.dart

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'symptom_database_helper.dart';
import 'symptom_firestore_service.dart';


/// Manages smart syncing of daily symptom logs.
/// LOCAL DATABASE IS ALWAYS THE SOURCE OF TRUTH.
///
/// Features:
/// • Full offline support
/// • Automatic push to Firebase when online (local overwrites cloud)
/// • One-time pull from Firebase only on brand new devices/installs
/// • Never overwrites local data on existing devices
/// • Efficient reconciliation (add / update / delete only what's needed)
class SymptomSyncService {
  static final SymptomSyncService _instance = SymptomSyncService._internal();
  factory SymptomSyncService() => _instance;
  SymptomSyncService._internal();

  final SymptomDatabaseHelper _localDb = SymptomDatabaseHelper.instance;
  final SymptomFirestoreService _firestoreService = SymptomFirestoreService.instance;

  Timer? _syncDebounceTimer;
  bool _isSyncing = false;
  bool _hasInitialized = false;

  String? get _userId => FirebaseAuth.instance.currentUser?.uid;

  // SharedPreferences flag to ensure we only ever pull from cloud once
  static const String _kHasCompletedInitialSync = 'symptom_initial_sync_completed';

  /// Returns true only if local DB is empty AND we have never synced before
  Future<bool> _isNewDevice() async {
    final logs = await _localDb.getAllLogs(limit: 1);
    final bool hasLocalData = logs.isNotEmpty;

    final prefs = await SharedPreferences.getInstance();
    final bool hasSyncedBefore = prefs.getBool(_kHasCompletedInitialSync) ?? false;

    return !hasLocalData && !hasSyncedBefore;
  }

  /// Mark that the one-time initial setup is done
  Future<void> _markInitialSyncComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kHasCompletedInitialSync, true);
    _hasInitialized = true;
  }

  /// Call this once at app startup (after FirebaseAuth is ready)
  Future<void> initialize() async {
    if (_hasInitialized) {
      print('🔄 SymptomSyncService already initialized');
      return;
    }

    print('🔄 Initializing SymptomSyncService...');

    await _firestoreService.initialize();

    final connectivity = await Connectivity().checkConnectivity();
    final bool isOnline = connectivity != ConnectivityResult.none;

    if (isOnline && _userId != null) {
      final bool newDevice = await _isNewDevice();

      if (newDevice) {
        print('🆕 New device – restoring logs from Firebase');
        await _pullFromFirebaseOnce();
        await _markInitialSyncComplete();
      } else {
        // AUTO-HEALING: If it's not a "new device" but local is empty, 
        // it means a previous sync was interrupted or the flag was set incorrectly.
        final logs = await _localDb.getAllLogs(limit: 1);
        if (logs.isEmpty) {
          print('🔄 Auto-healing: Local logs empty but not a new device. Checking Firebase...');
          await _pullFromFirebaseOnce();
        }
        print('📱 Existing device – waiting for changes to sync (delta sync active)');
        await _markInitialSyncComplete();
      }
    } else {
      print('📴 Offline or not logged in – will sync when possible');
      // If we have local data, we're "initialized" enough for this session.
      final logs = await _localDb.getAllLogs(limit: 1);
      if (logs.isNotEmpty) {
        _hasInitialized = true;
      } else {
        print('⚠️ New device AND offline — sync deferred until online');
      }
    }
  }

  /// Call this every time a log is saved or modified locally
  void onLocalLogChanged() {
    print('📝 Symptom log changed locally – scheduling sync');

    _syncDebounceTimer?.cancel();
    _syncDebounceTimer = Timer(const Duration(milliseconds: 1200), () async {
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity != ConnectivityResult.none && _userId != null) {
        await _pushLocalToFirebase();
      } else {
        print('📴 Still offline – changes saved locally');
      }
    });
  }

  /// Smart push: compare local and cloud, only write necessary changes
  Future<void> _pushLocalToFirebase() async {
    if (_userId == null) return;
    if (_isSyncing) {
      print('⏳ Sync already running');
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final List<String> dirtyDatesList = prefs.getStringList('symptom_dirty_dates') ?? [];

    if (dirtyDatesList.isEmpty) {
      print('✅ No changes detected – skipping Firebase sync');
      return;
    }

    final Set<String> dirtyDates = dirtyDatesList.toSet();
    print('🔄 Syncing ${dirtyDates.length} changed date(s): $dirtyDates');

    _isSyncing = true;
    try {
      // Load only the dirty logs from local DB
      final List<Map<String, dynamic>> dirtyLogs = [];
      for (final date in dirtyDates) {
        final log = await _localDb.getLogForDate(date);
        if (log != null) {
          dirtyLogs.add(log);
        }
      }

      // Filter meaningful logs (non-empty)
      final meaningfulLogs = dirtyLogs.where((log) => !_firestoreService.isLogEmpty(log)).toList();
      final Set<String> meaningfulDates = meaningfulLogs.map((e) => e['date'] as String).toSet();

      await _firestoreService.initialize();
      final CollectionReference collection = FirebaseFirestore.instance
          .collection('users')
          .doc(_userId)
          .collection('daily_symptom_logs');

      final snapshot = await collection.get();
      final Map<String, DocumentSnapshot> firebaseDocs = {
        for (var doc in snapshot.docs) doc.id: doc,
      };

      final WriteBatch batch = FirebaseFirestore.instance.batch();

      // Delete any dirty dates that became empty
      for (final date in dirtyDates) {
        if (!meaningfulDates.contains(date) && firebaseDocs.containsKey(date)) {
          batch.delete(firebaseDocs[date]!.reference);
          print('🗑️ Deleting cleared log from Firebase: $date');
        }
      }

      // Upsert only meaningful dirty logs
      for (final log in meaningfulLogs) {
        final String date = log['date'] as String;
        final ref = collection.doc(date);
        batch.set(ref, log, SetOptions(merge: true));
        print('💾 Syncing changed log to Firebase: $date');
      }

      await batch.commit();
      print('✅ Delta sync complete (${meaningfulLogs.length} updated, ${dirtyDates.length - meaningfulLogs.length} deleted)');

      // Clear dirty flags after success
      await prefs.remove('symptom_dirty_dates');

    } catch (e, stack) {
      print('🔥 Delta sync failed: $e');
      print(stack);
      // Keep dirty dates on failure so it retries next time
    } finally {
      _isSyncing = false;
    }
  }

  /// One-time pull from Firebase – only allowed on new devices
  Future<void> _pullFromFirebaseOnce() async {
    if (_userId == null) return;

    try {
      await _firestoreService.syncFromCloudToLocal();
      print('📲 Restored symptom logs from Firebase');
    } catch (e) {
      print('🔥 Initial restore failed: $e');
    }
  }

  /// Optional manual restore (e.g. for support cases)
  Future<void> manualRestoreFromCloud() async {
    final bool isNew = await _isNewDevice();
    if (!isNew) {
      print('⚠️ Manual restore blocked – device already has data');
      return;
    }

    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity == ConnectivityResult.none) {
      print('📴 Offline – cannot restore');
      return;
    }

    print('🔄 Manual restore from Firebase...');
    await _pullFromFirebaseOnce();
    await _markInitialSyncComplete();
  }

  void dispose() {
    _syncDebounceTimer?.cancel();
  }
}