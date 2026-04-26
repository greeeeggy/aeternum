// lib/study_planner/add_study_event_dialog.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'study_event_model.dart';

class AddStudyEventDialog extends StatefulWidget {
  final DateTime initialDate;
  final StudyEvent? existingEvent;
  final Future<void> Function(StudyEvent event) onSave;

  const AddStudyEventDialog({
    super.key,
    required this.initialDate,
    required this.onSave,
    this.existingEvent,
  });

  @override
  State<AddStudyEventDialog> createState() => _AddStudyEventDialogState();
}

class _AddStudyEventDialogState extends State<AddStudyEventDialog> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  late DateTime _selectedDate;
  late StudyEventType _selectedType;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existingEvent;
    _selectedDate = e?.date ?? widget.initialDate;
    _selectedType = e?.type ?? StudyEventType.exam;
    _titleController.text = e?.title ?? '';
    _descController.text = e?.description ?? '';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFD4849A),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Color(0xFF2A1A1A),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a title.')),
      );
      return;
    }
    setState(() => _isSaving = true);
    final event = StudyEvent(
      firestoreId: widget.existingEvent?.firestoreId,
      ownerUid: widget.existingEvent?.ownerUid ?? '',
      ownerName: widget.existingEvent?.ownerName ?? '',
      title: title,
      description: _descController.text.trim().isEmpty
          ? null
          : _descController.text.trim(),
      date: _selectedDate,
      type: _selectedType,
    );
    await widget.onSave(event);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existingEvent != null;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(24, 12, 24, 24 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE0D4D8),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Title
          Text(
            isEdit ? 'Edit Event' : 'New Event',
            style: GoogleFonts.playfairDisplay(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF2A1A1A),
            ),
          ),
          const SizedBox(height: 20),

          // Event type selector
          Text(
            'Type',
            style: GoogleFonts.nunito(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF8B6070),
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 8),
          _buildTypeSelector(),
          const SizedBox(height: 20),

          // Title field
          _buildTextField(
            controller: _titleController,
            label: 'Title',
            hint: 'e.g. Math Finals, Assignment Due...',
            maxLines: 1,
          ),
          const SizedBox(height: 14),

          // Description field
          _buildTextField(
            controller: _descController,
            label: 'Notes (optional)',
            hint: 'Add any extra details...',
            maxLines: 3,
          ),
          const SizedBox(height: 20),

          // Date picker
          Text(
            'Date',
            style: GoogleFonts.nunito(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF8B6070),
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 8),
          _buildDateButton(),
          const SizedBox(height: 28),

          // Save button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD4849A),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : Text(
                      isEdit ? 'Save Changes' : 'Add Event',
                      style: GoogleFonts.nunito(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeSelector() {
    return Wrap(
      spacing: 8,
      children: StudyEventType.values.map((type) {
        final selected = _selectedType == type;
        return GestureDetector(
          onTap: () => setState(() => _selectedType = type),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: selected ? type.color : type.lightColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: selected ? type.color : const Color(0xFFE8DDE0),
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  type.icon,
                  size: 14,
                  color: selected ? Colors.white : type.color,
                ),
                const SizedBox(width: 6),
                Text(
                  type.label,
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : type.color,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required int maxLines,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.nunito(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF8B6070),
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          style: GoogleFonts.nunito(
            fontSize: 14,
            color: const Color(0xFF2A1A1A),
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.nunito(
              color: const Color(0xFFBBAFB4),
              fontSize: 13,
            ),
            filled: true,
            fillColor: const Color(0xFFFAF4F6),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFEADDE2)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFEADDE2)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide:
                  const BorderSide(color: Color(0xFFD4849A), width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateButton() {
    return GestureDetector(
      onTap: _pickDate,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFFAF4F6),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFEADDE2)),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_rounded,
                size: 18, color: Color(0xFFD4849A)),
            const SizedBox(width: 12),
            Text(
              DateFormat('EEEE, MMMM d, yyyy').format(_selectedDate),
              style: GoogleFonts.nunito(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF2A1A1A),
              ),
            ),
            const Spacer(),
            const Icon(Icons.chevron_right_rounded,
                size: 18, color: Color(0xFFBBAFB4)),
          ],
        ),
      ),
    );
  }
}
