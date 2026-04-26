// lib/screens/tracker/symptom_firestore_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'symptom_database_helper.dart';

class SymptomFirestoreService {
  static final SymptomFirestoreService instance = SymptomFirestoreService._internal();
  SymptomFirestoreService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Changed from 'late final' to nullable – safe to assign multiple times
  CollectionReference? _logsCollection;

  User? get currentUser => FirebaseAuth.instance.currentUser;

  /// Initialize the collection reference if not already done
  /// Safe to call multiple times
  Future<void> initialize() async {
    if (currentUser == null) return;

    // Only create the reference if it doesn't exist yet
    _logsCollection ??= _firestore
        .collection('users')
        .doc(currentUser!.uid)
        .collection('daily_symptom_logs');
  }

  /// Sync a local log to Firestore
  Future<void> syncLogToCloud(Map<String, dynamic> log) async {
    if (currentUser == null) return;

    // Safe to call initialize() every time
    await initialize();

    final String date = log['date'] as String;
    final bool isEmpty = isLogEmpty(log);

    if (isEmpty) {
      await _logsCollection!.doc(date).delete();
    } else {
      await _logsCollection!.doc(date).set(log, SetOptions(merge: true));
    }
  }

  /// Get a single log from cloud
  Future<Map<String, dynamic>?> getLogFromCloud(String date) async {
    if (currentUser == null) return null;
    await initialize();

    final doc = await _logsCollection!.doc(date).get();
    if (doc.exists && doc.data() != null) {
      final data = doc.data() as Map<String, dynamic>;
      data['date'] = date;
      return data;
    }
    return null;
  }

  /// Pull all logs from cloud to local
  Future<void> syncFromCloudToLocal() async {
    if (currentUser == null) return;
    await initialize();

    final snapshot = await _logsCollection!.get();
    for (var doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      data['date'] = doc.id;
      await SymptomDatabaseHelper.instance.saveDailyLog(data);
    }
  }

  /// Check if log is empty
  bool isLogEmpty(Map<String, dynamic> log) {
    final List<String> listFields = [
      'moods', 'symptoms', 'flow', 'discharge', 'sex', 'digestion', 'other'
    ];

    for (String field in listFields) {
      final value = log[field];
      if (value is List && value.isNotEmpty) return false;
      if (value is String && value.isNotEmpty) return false;
    }

    if (log['basal_temperature'] != null && log['basal_temperature'].toString().isNotEmpty) return false;
    if (log['weight'] != null && log['weight'].toString().isNotEmpty) return false;
    if (log['notes'] != null && log['notes'].toString().trim().isNotEmpty) return false;

    if ((log['stress_level'] as double?) != 3.0) return false;
    if (log['physical_activity'] != 'Didn\'t exercise') return false;
    if (log['pregnancy_test'] != 'Didn\'t take tests') return false;
    if (log['ovulation_test'] != 'Didn\'t take tests') return false;
    if (log['oral_contraceptives'] != 'Didn\'t take a contraceptive') return false;

    return true;
  }
}