// lib/class_schedule/edit_day_schedule_page.dart
// FIXED: Proper context handling after navigation
import 'package:flutter/material.dart';
import 'class_model.dart';
import 'edit_class_dialog.dart';
import 'class_schedule_database.dart';
import 'class_schedule_sync_service.dart';

class EditDaySchedulePage extends StatefulWidget {
  final String dayName;
  final int dayIndex;
  final List<ClassSchedule> classes;
  final bool isReadOnly; // true when viewing partner's schedule

  const EditDaySchedulePage({
    super.key,
    required this.dayName,
    required this.dayIndex,
    required this.classes,
    this.isReadOnly = false,
  });

  @override
  State<EditDaySchedulePage> createState() => _EditDaySchedulePageState();
}

class _EditDaySchedulePageState extends State<EditDaySchedulePage> {
  final ClassScheduleDatabase _database = ClassScheduleDatabase();
  final ClassScheduleSyncService _syncService = ClassScheduleSyncService();
  late List<ClassSchedule> _classes;

  @override
  void initState() {
    super.initState();
    _classes = List.from(widget.classes)
      ..sort((a, b) => a.startMinutes.compareTo(b.startMinutes));
  }

  Future<void> _editClass(ClassSchedule classItem) async {
    final result = await showDialog<ClassSchedule>(
      context: context,
      builder: (context) => EditClassDialog(
        classSchedule: classItem,
        activeGroupId: classItem.groupId,
      ),
    );

    if (result != null) {
      try {
        await _database.updateClass(result);
        // Push the update to Firestore so it persists across app restarts
        await _syncService.updateClass(result);

        // ✅ FIX: Check if widget is still mounted before using context
        if (!mounted) return;

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Class updated successfully')),
        );

        // Pop with result
        Navigator.pop(context, true);
      } catch (e) {
        // ✅ FIX: Check if widget is still mounted before using context
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating class: $e')),
        );
      }
    }
  }

  Future<void> _deleteClass(ClassSchedule classItem) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[850],
        title: const Text('Delete Class', style: TextStyle(color: Colors.white)),
        content: Text(
          'Are you sure you want to delete ${classItem.subjectName}?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _database.deleteClass(classItem.id!);
        // Delete from Firestore too so it doesn't come back on next sync
        if (classItem.firestoreId != null) {
          await _syncService.deleteClass(classItem.firestoreId!);
        }

        // ✅ FIX: Check if widget is still mounted before using context
        if (!mounted) return;

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Class deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );

        // Pop with result after a short delay to let user see the snackbar
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            Navigator.pop(context, true);
          }
        });
      } catch (e) {
        // ✅ FIX: Check if widget is still mounted before using context
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting class: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        title: Text('${widget.dayName} Schedule', style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        elevation: 0,
      ),
      body: _classes.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy, size: 64, color: Colors.grey[600]),
            const SizedBox(height: 16),
            Text(
              'No classes on ${widget.dayName}',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _classes.length,
        itemBuilder: (context, index) {
          final classItem = _classes[index];
          return _buildClassCard(classItem);
        },
      ),
    );
  }

  Widget _buildClassCard(ClassSchedule classItem) {
    return Card(
      color: Colors.grey[850],
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: classItem.color, width: 2),
      ),
      child: InkWell(
        onTap: () => _editClass(classItem),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Color indicator
              Container(
                width: 8,
                height: 80,
                decoration: BoxDecoration(
                  color: classItem.color,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 16),
              // Class details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      classItem.subjectName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      classItem.professorName,
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: classItem.color.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        classItem.getTimeRange(),
                        style: TextStyle(
                          color: classItem.color,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Action buttons — hidden for read-only (partner's schedule)
              if (!widget.isReadOnly)
                Column(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () => _editClass(classItem),
                      tooltip: 'Edit',
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deleteClass(classItem),
                      tooltip: 'Delete',
                    ),
                  ],
                )
              else
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Tooltip(
                    message: "This is your partner's schedule",
                    child: Icon(Icons.lock_outline, color: Colors.grey[600], size: 20),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}