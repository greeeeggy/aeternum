// lib/budget_planner/joint_savings_service.dart
// Firestore models + service for Joint Savings and Joint Goals.
// Data lives under: couples/{pairId}/jointSavings  and  couples/{pairId}/jointGoals

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ─────────────────────────────────────────────
// MODELS
// ─────────────────────────────────────────────

class JointSavingsPot {
  final String id;
  final String name;
  final String description;
  final DateTime createdAt;
  final String createdBy;

  const JointSavingsPot({
    required this.id,
    required this.name,
    required this.description,
    required this.createdAt,
    required this.createdBy,
  });

  factory JointSavingsPot.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return JointSavingsPot(
      id: doc.id,
      name: d['name'] as String? ?? '',
      description: d['description'] as String? ?? '',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdBy: d['createdBy'] as String? ?? '',
    );
  }
}

class JointTransaction {
  final String id;
  final double amount;
  final String type; // 'deposit' | 'withdraw'
  final String userId;
  final String displayName;
  final String? avatarBase64;
  final String? photoUrl; // network URL fallback when avatarBase64 is absent
  final String? notes;
  final DateTime createdAt;

  const JointTransaction({
    required this.id,
    required this.amount,
    required this.type,
    required this.userId,
    required this.displayName,
    this.avatarBase64,
    this.photoUrl,
    this.notes,
    required this.createdAt,
  });

  factory JointTransaction.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return JointTransaction(
      id: doc.id,
      amount: (d['amount'] as num?)?.toDouble() ?? 0.0,
      type: d['type'] as String? ?? 'deposit',
      userId: d['userId'] as String? ?? '',
      displayName: d['displayName'] as String? ?? 'Unknown',
      avatarBase64: d['avatarBase64'] as String?,
      photoUrl: d['photoUrl'] as String?,
      notes: d['notes'] as String?,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

class JointGoal {
  final String id;
  final String name;
  final double targetAmount;
  final DateTime deadline;
  final String icon;
  final int color;
  final DateTime createdAt;
  final String createdBy;
  final DateTime? completedAt;

  const JointGoal({
    required this.id,
    required this.name,
    required this.targetAmount,
    required this.deadline,
    required this.icon,
    required this.color,
    required this.createdAt,
    required this.createdBy,
    this.completedAt,
  });

  factory JointGoal.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return JointGoal(
      id: doc.id,
      name: d['name'] as String? ?? '',
      targetAmount: (d['targetAmount'] as num?)?.toDouble() ?? 0.0,
      deadline: (d['deadline'] as Timestamp?)?.toDate() ?? DateTime.now(),
      icon: d['icon'] as String? ?? '🎯',
      color: d['color'] as int? ?? 0xFF10B981,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdBy: d['createdBy'] as String? ?? '',
      completedAt: (d['completedAt'] as Timestamp?)?.toDate(),
    );
  }
}

// ─────────────────────────────────────────────
// SERVICE
// ─────────────────────────────────────────────

class JointSavingsService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── Collection refs ───────────────────────────────────────────────────────
  CollectionReference _potsRef(String pairId) =>
      _db.collection('couples').doc(pairId).collection('jointSavings');

  CollectionReference _savingsTxRef(String pairId, String potId) =>
      _potsRef(pairId).doc(potId).collection('transactions');

  CollectionReference _goalsRef(String pairId) =>
      _db.collection('couples').doc(pairId).collection('jointGoals');

  CollectionReference _goalTxRef(String pairId, String goalId) =>
      _goalsRef(pairId).doc(goalId).collection('transactions');

  // ── Savings Pots ──────────────────────────────────────────────────────────

  /// Live stream — updates both partners instantly when a pot is added/changed.
  Stream<List<JointSavingsPot>> potsStream(String pairId) =>
      _potsRef(pairId)
          .orderBy('createdAt', descending: false)
          .snapshots()
          .map((s) => s.docs.map(JointSavingsPot.fromDoc).toList());

  Future<void> createPot(
      String pairId, String name, String description) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    await _potsRef(pairId).add({
      'name': name,
      'description': description,
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': uid,
    });
  }

  /// Deletes all sub-transactions then the pot document in one batch.
  Future<void> deletePot(String pairId, String potId) async {
    final txSnap = await _savingsTxRef(pairId, potId).get();
    final batch = _db.batch();
    for (final doc in txSnap.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(_potsRef(pairId).doc(potId));
    await batch.commit();
  }

  // ── Savings Transactions ──────────────────────────────────────────────────

  /// Live stream of all transactions for one pot, newest first.
  Stream<List<JointTransaction>> savingsTxStream(
          String pairId, String potId) =>
      _savingsTxRef(pairId, potId)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((s) => s.docs.map(JointTransaction.fromDoc).toList());

  Future<String> addSavingsTransaction({
    required String pairId,
    required String potId,
    required double amount,
    required String type,
    required String displayName,
    String? avatarBase64,
    String? photoUrl,
    String? notes,
  }) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final ref = await _savingsTxRef(pairId, potId).add({
      'amount': amount,
      'type': type,
      'userId': uid,
      'displayName': displayName,
      'avatarBase64': avatarBase64,
      'photoUrl': photoUrl,
      'notes': notes,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  /// Edit only the amount, type, and notes — displayName/avatar stay as the
  /// original snapshot so history always shows who actually made the entry.
  Future<void> editSavingsTransaction({
    required String pairId,
    required String potId,
    required String txId,
    required double amount,
    required String type,
    String? notes,
  }) async {
    await _savingsTxRef(pairId, potId).doc(txId).update({
      'amount': amount,
      'type': type,
      'notes': notes,
    });
  }

  Future<void> deleteSavingsTransaction({
    required String pairId,
    required String potId,
    required String txId,
  }) async {
    await _savingsTxRef(pairId, potId).doc(txId).delete();
  }

  // ── Joint Goals ───────────────────────────────────────────────────────────

  /// Live stream of all joint goals, oldest first (consistent chip order).
  Stream<List<JointGoal>> goalsStream(String pairId) =>
      _goalsRef(pairId)
          .orderBy('createdAt', descending: false)
          .snapshots()
          .map((s) => s.docs.map(JointGoal.fromDoc).toList());

  Future<void> createGoal({
    required String pairId,
    required String name,
    required double targetAmount,
    required DateTime deadline,
    required String icon,
    required int color,
  }) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    await _goalsRef(pairId).add({
      'name': name,
      'targetAmount': targetAmount,
      'deadline': Timestamp.fromDate(deadline),
      'icon': icon,
      'color': color,
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': uid,
      'completedAt': null,
    });
  }

  Future<void> updateGoal({
    required String pairId,
    required String goalId,
    required String name,
    required double targetAmount,
    required DateTime deadline,
    required String icon,
    required int color,
  }) async {
    await _goalsRef(pairId).doc(goalId).update({
      'name': name,
      'targetAmount': targetAmount,
      'deadline': Timestamp.fromDate(deadline),
      'icon': icon,
      'color': color,
    });
  }

  Future<void> markGoalCompleted(String pairId, String goalId) async {
    await _goalsRef(pairId).doc(goalId).update({
      'completedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteGoal(String pairId, String goalId) async {
    final txSnap = await _goalTxRef(pairId, goalId).get();
    final batch = _db.batch();
    for (final doc in txSnap.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(_goalsRef(pairId).doc(goalId));
    await batch.commit();
  }

  // ── Goal Transactions ─────────────────────────────────────────────────────

  /// Live stream of all transactions for one joint goal, newest first.
  Stream<List<JointTransaction>> goalTxStream(
          String pairId, String goalId) =>
      _goalTxRef(pairId, goalId)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((s) => s.docs.map(JointTransaction.fromDoc).toList());

  Future<String> addGoalTransaction({
    required String pairId,
    required String goalId,
    required double amount,
    required String type,
    required String displayName,
    String? avatarBase64,
    String? photoUrl,
    String? notes,
  }) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final ref = await _goalTxRef(pairId, goalId).add({
      'amount': amount,
      'type': type,
      'userId': uid,
      'displayName': displayName,
      'avatarBase64': avatarBase64,
      'photoUrl': photoUrl,
      'notes': notes,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  Future<void> editGoalTransaction({
    required String pairId,
    required String goalId,
    required String txId,
    required double amount,
    required String type,
    String? notes,
  }) async {
    await _goalTxRef(pairId, goalId).doc(txId).update({
      'amount': amount,
      'type': type,
      'notes': notes,
    });
  }

  Future<void> deleteGoalTransaction({
    required String pairId,
    required String goalId,
    required String txId,
  }) async {
    await _goalTxRef(pairId, goalId).doc(txId).delete();
  }

  // ── User Info ─────────────────────────────────────────────────────────────

  /// Snapshot of the current user's name + avatar — embedded into each transaction
  /// so history stays accurate even if they change their profile later.
  Future<Map<String, String?>> getCurrentUserInfo() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return {'displayName': 'Unknown', 'avatarBase64': null, 'photoUrl': null};
    final doc =
        await _db.collection('users').doc(user.uid).get();
    final data = doc.data();
    final appPhoto = data?['appPhotoBase64'] as String?;
    return {
      'displayName':
          user.displayName ?? (data?['email'] as String?) ?? 'Unknown',
      'avatarBase64': (appPhoto != null && appPhoto.isNotEmpty) ? appPhoto : null,
      'photoUrl': (appPhoto == null || appPhoto.isEmpty) ? user.photoURL : null,
    };
  }

  /// Gets the couple's pairId from Firestore for the current user.
  static Future<String?> getPairId() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    return doc.data()?['pairId'] as String?;
  }
}