// lib/screens/shared_notes_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

import '../models/shared_note.dart';
import '../services/note_database.dart';
import 'note_edit_page.dart';

class SharedNotesPage extends StatefulWidget {
  final String pairId;
  const SharedNotesPage({super.key, required this.pairId});

  @override
  State<SharedNotesPage> createState() => _SharedNotesPageState();
}

class _SharedNotesPageState extends State<SharedNotesPage> {
  final NoteDatabase _db = NoteDatabase.instance;
  StreamSubscription? _firestoreSubscription;

  @override
  void initState() {
    super.initState();
    _startFirestoreSync();
  }

  void _startFirestoreSync() {
    _firestoreSubscription = FirebaseFirestore.instance
        .collection('couples')
        .doc(widget.pairId)
        .collection('notes')
        .snapshots()
        .listen((querySnapshot) async {
      for (final doc in querySnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final isDeleted = data['isDeleted'] == true;

        if (isDeleted) {
          // Remove from local DB
          await _db.hardDeleteByDocId(doc.id);
        } else {
          // Upsert into local DB
          final note = SharedNote(
            docId: doc.id,
            title: data['title'] ?? '',
            content: data['content'] ?? '',
            color: data['color'] ?? 0xFFFFFFFF,
            isPinned: data['isPinned'] ?? false,
            createdAt: (data['createdAt'] as Timestamp).toDate(),
            updatedAt: (data['updatedAt'] as Timestamp).toDate(),
            createdBy: data['createdBy'] ?? '',
            isSynced: true,
            isDeleted: false,
          );

          final existing = await _db.getNoteByDocId(doc.id);
          if (existing != null) {
            await _db.update(note.copyWith(id: existing.id));
          } else {
            await _db.create(note);
          }
        }
      }
      if (mounted) setState(() {}); // Refresh UI
    });
  }

  void _createNewNote() async {
    final user = FirebaseAuth.instance.currentUser!;
    final now = DateTime.now();
    await FirebaseFirestore.instance
        .collection('couples')
        .doc(widget.pairId)
        .collection('notes')
        .add({
      'title': '',
      'content': '',
      'color': 0xFFFFFFFF,
      'isPinned': false,
      'createdAt': now,
      'updatedAt': now,
      'createdBy': user.uid,
      'isDeleted': false,
    });
  }

  @override
  void dispose() {
    _firestoreSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Shared Notes 💬')),
      body: FutureBuilder<List<SharedNote>>(
        future: _db.getAllUnDeleted(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.note_outlined, size: 60, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No notes yet.\nTap + to create one!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                ],
              ),
            );
          }

          final notes = snapshot.data!;

          return Padding(
            padding: const EdgeInsets.all(8.0),
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 1.0,
              ),
              itemCount: notes.length,
              itemBuilder: (context, index) {
                final note = notes[index];
                final bgColor = Color(note.color).withOpacity(0.15);
                final title = note.title.isEmpty ? '(Untitled)' : note.title;

                return GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => NoteEditPage(
                        pairId: widget.pairId,
                        noteDocId: note.docId!,
                        initialNote: note,
                      ),
                    ),
                  ),
                  child: Card(
                    color: bgColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Expanded(
                            child: Text(
                              note.content,
                              style: const TextStyle(fontSize: 12),
                              maxLines: 6,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Align(
                            alignment: Alignment.bottomRight,
                            child: Text(
                              '${note.updatedAt.day}/${note.updatedAt.month}',
                              style: const TextStyle(fontSize: 10, color: Colors.grey),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createNewNote,
        child: const Icon(Icons.add),
      ),
    );
  }
}