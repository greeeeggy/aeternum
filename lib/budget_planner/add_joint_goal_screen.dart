import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'budget_planner_theme.dart';
import 'joint_savings_service.dart';

class AddJointGoalScreen extends StatefulWidget {
  final String pairId;
  final JointGoal? goal; // null = create mode, non-null = edit mode

  const AddJointGoalScreen({
    super.key,
    required this.pairId,
    this.goal,
  });

  @override
  State<AddJointGoalScreen> createState() => _AddJointGoalScreenState();
}

class _AddJointGoalScreenState extends State<AddJointGoalScreen> {
  final _service = JointSavingsService();
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();

  DateTime _deadline = DateTime.now().add(const Duration(days: 90));
  String _selectedIcon = '🎯';
  Color _selectedColor = const Color(0xFF10B981);
  bool _isLoading = false;

  final List<String> _icons = [
    '🎯', '🏠', '✈️', '🚗', '💍', '🎓', '💻', '📱',
    '🏖️', '🎮', '🛡️', '💰', '🏋️', '🎨', '🌍', '🐷',
  ];

  final List<Color> _colors = [
    const Color(0xFF10B981),
    const Color(0xFF3B82F6),
    const Color(0xFF8B5CF6),
    const Color(0xFFEC4899),
    const Color(0xFFF59E0B),
    const Color(0xFFEF4444),
    const Color(0xFF06B6D4),
    const Color(0xFF84CC16),
  ];

  bool get _isEditing => widget.goal != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final g = widget.goal!;
      _nameCtrl.text = g.name;
      _amountCtrl.text = g.targetAmount.toStringAsFixed(0);
      _deadline = g.deadline;
      _selectedIcon = g.icon;
      _selectedColor = Color(g.color);
    }
  }

  Future<void> _selectDeadline() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline,
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: ColorScheme.dark(
            primary: BPTheme.accentIndigo,
            surface: BPTheme.surface,
            onSurface: BPTheme.textPrimary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _deadline = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final name = _nameCtrl.text.trim();
      final amount =
          double.parse(_amountCtrl.text.replaceAll(',', ''));

      if (!_isEditing) {
        await _service.createGoal(
          pairId: widget.pairId,
          name: name,
          targetAmount: amount,
          deadline: _deadline,
          icon: _selectedIcon,
          color: _selectedColor.value,
        );
      } else {
        await _service.updateGoal(
          pairId: widget.pairId,
          goalId: widget.goal!.id,
          name: name,
          targetAmount: amount,
          deadline: _deadline,
          icon: _selectedIcon,
          color: _selectedColor.value,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(BPTheme.snackError('Error: $e'));
      }
    }
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BPTheme.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: Text('Delete Goal',
            style: TextStyle(
                color: BPTheme.textPrimary,
                fontWeight: FontWeight.w700)),
        content: Text(
            'All contributions will also be deleted. Are you sure?',
            style: TextStyle(color: BPTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: TextStyle(color: BPTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child:
                Text('Delete', style: TextStyle(color: BPTheme.expense)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _service.deleteGoal(widget.pairId, widget.goal!.id);
      if (mounted) Navigator.pop(context, 'deleted');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BPTheme.background,
      appBar: bpAppBar(
        title: _isEditing ? 'Edit Joint Goal' : 'New Joint Goal',
        actions: [
          if (_isEditing)
            IconButton(
              icon: Icon(Icons.delete_outline_rounded,
                  color: BPTheme.expense.withOpacity(0.9)),
              onPressed: _delete,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Joint badge
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: const Color(0xFF8B5CF6).withOpacity(0.3)),
                ),
                child: Row(children: [
                  const Text('👫', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Joint Goal — both partners can contribute and track progress together.',
                      style: TextStyle(
                          color: BPTheme.textSecondary,
                          fontSize: 13,
                          height: 1.5),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 28),

              _label('Goal Name'),
              const SizedBox(height: 10),
              TextFormField(
                controller: _nameCtrl,
                style: TextStyle(color: BPTheme.textPrimary),
                decoration:
                    BPTheme.field('e.g. Dream Vacation, New Apartment'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Enter a name' : null,
              ),
              const SizedBox(height: 24),

              _label('Target Amount'),
              const SizedBox(height: 10),
              TextFormField(
                controller: _amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\d,.]'))
                ],
                style: TextStyle(color: BPTheme.textPrimary),
                decoration: BPTheme.field('0', prefix: '₱ '),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Enter an amount';
                  final n = double.tryParse(v.replaceAll(',', ''));
                  if (n == null || n <= 0) return 'Enter a valid amount';
                  return null;
                },
              ),
              const SizedBox(height: 24),

              _label('Deadline'),
              const SizedBox(height: 10),
              InkWell(
                onTap: _selectDeadline,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: BPTheme.surfaceEl,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: BPTheme.divider),
                  ),
                  child: Row(children: [
                    Icon(Icons.calendar_today_rounded,
                        color: BPTheme.accentIndigo, size: 20),
                    const SizedBox(width: 12),
                    Text(
                      DateFormat('MMM d, y').format(_deadline),
                      style: TextStyle(
                          color: BPTheme.textPrimary, fontSize: 15),
                    ),
                    const Spacer(),
                    Icon(Icons.keyboard_arrow_down_rounded,
                        color: BPTheme.textSecondary),
                  ]),
                ),
              ),
              const SizedBox(height: 24),

              _label('Icon'),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BPTheme.cardDecoration,
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _icons.map((icon) {
                    final sel = icon == _selectedIcon;
                    return GestureDetector(
                      onTap: () =>
                          setState(() => _selectedIcon = icon),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 120),
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: sel
                              ? _selectedColor.withOpacity(0.25)
                              : BPTheme.surfaceEl,
                          borderRadius: BorderRadius.circular(13),
                          border: Border.all(
                            color: sel
                                ? _selectedColor
                                : BPTheme.divider,
                            width: sel ? 2 : 1,
                          ),
                        ),
                        child: Center(
                          child: Text(icon,
                              style: const TextStyle(fontSize: 24)),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 24),

              _label('Color'),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BPTheme.cardDecoration,
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: _colors.map((color) {
                    final sel = color.value == _selectedColor.value;
                    return GestureDetector(
                      onTap: () =>
                          setState(() => _selectedColor = color),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 120),
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: sel
                                ? Colors.white
                                : Colors.transparent,
                            width: 3,
                          ),
                          boxShadow: sel
                              ? [
                                  BoxShadow(
                                    color: color.withOpacity(0.5),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  )
                                ]
                              : [],
                        ),
                        child: sel
                            ? const Icon(Icons.check,
                                color: Colors.white, size: 20)
                            : null,
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 40),

              BPGradientButton(
                label: _isEditing ? 'Update Goal' : 'Create Joint Goal',
                gradientColors: const [
                  Color(0xFF8B5CF6),
                  Color(0xFF6D28D9)
                ],
                onPressed: _isLoading ? null : _save,
                isLoading: _isLoading,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Text(
        text,
        style: TextStyle(
          color: BPTheme.textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      );

  @override
  void dispose() {
    _nameCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }
}