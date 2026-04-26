// lib/screens/note_edit_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

class NoteEditPage extends StatefulWidget {
  final String pairId;
  final String noteDocId;
  final dynamic initialNote; // We only need docId; data comes from Firestore

  const NoteEditPage({
    super.key,
    required this.pairId,
    required this.noteDocId,
    required this.initialNote,
  });

  @override
  State<NoteEditPage> createState() => _NoteEditPageState();
}

class _NoteEditPageState extends State<NoteEditPage> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  late int _selectedColor;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    final note = widget.initialNote;
    _titleController = TextEditingController(text: note.title);
    _contentController = TextEditingController(text: note.content);
    _selectedColor = note.color;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _saveToFirestore() {
    FirebaseFirestore.instance
        .collection('couples')
        .doc(widget.pairId)
        .collection('notes')
        .doc(widget.noteDocId)
        .update({
      'title': _titleController.text.trim(),
      'content': _contentController.text.trim(),
      'color': _selectedColor,
      'updatedAt': DateTime.now(),
    });
  }

  void _onTextChanged(String _) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), _saveToFirestore);
  }

  Future<void> _deleteNote() async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Note?'),
        content: const Text('This will delete it for both of you.'),
        actions: [
          TextButton(onPressed: Navigator.of(context).pop, child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              // Mark as deleted in Firestore → triggers sync
              await FirebaseFirestore.instance
                  .collection('couples')
                  .doc(widget.pairId)
                  .collection('notes')
                  .doc(widget.noteDocId)
                  .update({'isDeleted': true});
              if (!mounted) return;
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Note'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: const Color(0xFFE96D88),
        actions: [
          IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: _deleteNote),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _titleController,
              onChanged: _onTextChanged,
              decoration: const InputDecoration(
                hintText: 'Title',
                border: InputBorder.none,
                focusedBorder: InputBorder.none,
                enabledBorder: InputBorder.none,
              ),
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              maxLines: 1,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _contentController,
              onChanged: _onTextChanged,
              maxLines: null,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
              decoration: const InputDecoration(
                hintText: 'Take a note...',
                border: InputBorder.none,
                focusedBorder: InputBorder.none,
                enabledBorder: InputBorder.none,
                isDense: true,
              ),
              style: const TextStyle(fontSize: 16, height: 1.4),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                const Text('Color:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ...[
                  0xFFF44336, 0xFF4CAF50, 0xFF2196F3,
                  0xFFFF9800, 0xFF9C27B0, 0xFFFFFFFF,
                ].map((colorInt) {
                  final color = Color(colorInt);
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedColor = colorInt;
                        _saveToFirestore(); // Save immediately on color change
                      });
                    },
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: _selectedColor == colorInt
                            ? Border.all(color: Colors.black, width: 2)
                            : null,
                      ),
                    ),
                  );
                }).toList(),
              ],
            ),
          ],
        ),
      ),
    );
  }
}