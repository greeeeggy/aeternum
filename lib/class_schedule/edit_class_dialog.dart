// lib/class_schedule/edit_class_dialog.dart
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'class_model.dart';
import 'class_schedule_database.dart';

class EditClassDialog extends StatefulWidget {
  final ClassSchedule classSchedule;
  final String? activeGroupId;

  const EditClassDialog({
    super.key,
    required this.classSchedule,
    this.activeGroupId,
  });

  @override
  State<EditClassDialog> createState() => _EditClassDialogState();
}

class _EditClassDialogState extends State<EditClassDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _subjectController;
  late TextEditingController _professorController;

  late int _selectedDay;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  late Color _selectedColor;

  final List<String> _days = [
    'Sunday',
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
  ];

  @override
  void initState() {
    super.initState();
    _subjectController = TextEditingController(text: widget.classSchedule.subjectName);
    _professorController = TextEditingController(text: widget.classSchedule.professorName);
    _selectedDay = widget.classSchedule.dayOfWeek;
    _startTime = widget.classSchedule.startTime;
    _endTime = widget.classSchedule.endTime;
    _selectedColor = widget.classSchedule.color;
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _professorController.dispose();
    super.dispose();
  }

  Future<void> _selectStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime,
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark(),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startTime = picked;
        if (_timeToMinutes(_endTime) <= _timeToMinutes(_startTime)) {
          _endTime = TimeOfDay(
            hour: (_startTime.hour + 1) % 24,
            minute: _startTime.minute,
          );
        }
      });
    }
  }

  Future<void> _selectEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _endTime,
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark(),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _endTime = picked);
    }
  }

  int _timeToMinutes(TimeOfDay time) {
    return time.hour * 60 + time.minute;
  }

  bool _validateTimes() {
    final startMinutes = _timeToMinutes(_startTime);
    final endMinutes = _timeToMinutes(_endTime);

    if (endMinutes <= startMinutes) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End time must be after start time')),
      );
      return false;
    }

    const lunchStart = 12 * 60;
    const lunchEnd = 13 * 60;

    if (startMinutes < lunchEnd && endMinutes > lunchStart) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Classes cannot overlap with lunch break (12:00 PM - 1:00 PM)'),
          duration: Duration(seconds: 3),
        ),
      );
      return false;
    }

    return true;
  }

  Future<bool> _checkForOverlap() async {
    final startMinutes = _timeToMinutes(_startTime);
    final endMinutes = _timeToMinutes(_endTime);

    // Get all existing classes for the selected day
    final database = ClassScheduleDatabase();
    final allClasses = await database.getAllClasses();
    final dayClasses = allClasses
        .where((c) => c.dayOfWeek == _selectedDay)
        .where((c) => c.id != widget.classSchedule.id) // Exclude current class
        .where((c) => c.groupId == widget.activeGroupId) // Only same group
        .toList();

    for (final existingClass in dayClasses) {
      final existingStart = existingClass.startMinutes;
      final existingEnd = existingClass.endMinutes;

      // Check if new class overlaps with existing class
      // Overlap occurs if: (start1 < end2) AND (end1 > start2)
      if (startMinutes < existingEnd && endMinutes > existingStart) {
        if (mounted) {
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              backgroundColor: Colors.grey[850],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Colors.red, width: 2),
              ),
              title: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 32),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Schedule Conflict',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'You already have a class scheduled at this time:',
                    style: TextStyle(color: Colors.grey[300], fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: existingClass.color.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: existingClass.color, width: 1),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          existingClass.subjectName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          existingClass.getTimeRange(),
                          style: TextStyle(
                            color: existingClass.color,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _days[_selectedDay],
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Please choose a different time slot.',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
              actions: [
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: const Text(
                    'OK',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          );
        }
        return true; // Overlap found
      }
    }

    return false; // No overlap
  }

  void _showColorPicker() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[850],
        title: const Text('Pick a color', style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: _selectedColor,
            onColorChanged: (color) {
              setState(() => _selectedColor = color);
            },
            pickerAreaHeightPercent: 0.8,
            enableAlpha: false,
            displayThumbColor: true,
            labelTypes: const [],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _saveChanges() async {
    if (_formKey.currentState!.validate() && _validateTimes()) {
      // Check for overlapping schedules
      final hasOverlap = await _checkForOverlap();
      if (hasOverlap) {
        return; // Don't save if there's an overlap
      }

      final updatedClass = widget.classSchedule.copyWith(
        dayOfWeek: _selectedDay,
        startTime: _startTime,
        endTime: _endTime,
        subjectName: _subjectController.text.trim(),
        professorName: _professorController.text.trim(),
        color: _selectedColor,
      );

      Navigator.pop(context, updatedClass);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.grey[900],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Edit Class',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 24),

                // Day selector
                const Text('Day', style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[850],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButton<int>(
                    value: _selectedDay,
                    isExpanded: true,
                    dropdownColor: Colors.grey[850],
                    style: const TextStyle(color: Colors.white),
                    underline: Container(),
                    items: List.generate(
                      7,
                          (index) => DropdownMenuItem(
                        value: index,
                        child: Text(_days[index]),
                      ),
                    ),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _selectedDay = value);
                      }
                    },
                  ),
                ),
                const SizedBox(height: 16),

                // Time selectors
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Start Time', style: TextStyle(color: Colors.white70)),
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: _selectStartTime,
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey[850],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _startTime.format(context),
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                  const Icon(Icons.access_time, color: Colors.white70),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('End Time', style: TextStyle(color: Colors.white70)),
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: _selectEndTime,
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey[850],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _endTime.format(context),
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                  const Icon(Icons.access_time, color: Colors.white70),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Subject name
                const Text('Subject Name', style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _subjectController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.grey[850],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a subject name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Professor name
                const Text('Professor Name', style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _professorController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.grey[850],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a professor name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Color picker
                const Text('Color', style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 8),
                InkWell(
                  onTap: _showColorPicker,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[850],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: _selectedColor,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Text('Tap to change color', style: TextStyle(color: Colors.white)),
                          ],
                        ),
                        const Icon(Icons.palette, color: Colors.white70),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _saveChanges,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      child: const Text('Save Changes', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}