// lib/services/note_sync_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/shared_note.dart';
import 'note_database.dart';

class NoteSyncService {
  final String pairId;
  final NoteDatabase _db = NoteDatabase.instance;

  NoteSyncService(this.pairId);

  // Call this periodically or on network change
  Future<void> syncWithFirebase() async {
    final unsyncedNotes = await _db.getUnsyncedNotes();
    final user = FirebaseAuth.instance.currentUser!;

    for (final note in unsyncedNotes) {
      try {
        if (note.isDeleted) {
          // Delete from Firebase
          if (note.docId != null) {
            await FirebaseFirestore.instance
                .collection('couples')
                .doc(pairId)
                .collection('notes')
                .doc(note.docId!)
                .delete();
          }
          // Hard-delete from local DB
          await _db.hardDelete(note.id!);
        } else {
          // Create or update in Firebase
          final firestoreMap = note.toFirestoreMap();
          DocumentReference ref;
          if (note.docId == null) {
            // New note
            ref = await FirebaseFirestore.instance
                .collection('couples')
                .doc(pairId)
                .collection('notes')
                .add(firestoreMap);
          } else {
            // Update existing
            ref = FirebaseFirestore.instance
                .collection('couples')
                .doc(pairId)
                .collection('notes')
                .doc(note.docId!);
            await ref.set(firestoreMap, SetOptions(merge: true));
          }
          // Mark as synced
          await _db.markAsSynced(note.id!, ref.id);
        }
      } catch (e) {
        // Keep note marked as unsynced; retry later
        print('Sync failed for note ${note.id}: $e');
      }
    }
  }
}