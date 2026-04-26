import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'budget_planner_theme.dart';
import 'recurring_transaction.dart';
import 'recurring_transaction_repository.dart';
import 'category.dart';
import 'category_repository.dart';

class AddRecurringTransactionScreen extends StatefulWidget {
  final RecurringTransaction? transaction;

  const AddRecurringTransactionScreen({super.key, this.transaction});

  @override
  State<AddRecurringTransactionScreen> createState() =>
      _AddRecurringTransactionScreenState();
}

class _AddRecurringTransactionScreenState
    extends State<AddRecurringTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final RecurringTransactionRepository _recurringRepo =
      RecurringTransactionRepository();
  final CategoryRepository _categoryRepo = CategoryRepository();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  String _selectedType = 'expense';
  int? _selectedCategoryId;
  String _selectedFrequency = 'monthly';
  List<Category> _categories = [];
  bool _isLoading = false;

  Set<int> _excludedDays = {};

  @override
  void initState() {
    super.initState();
    _loadCategories();

    if (widget.transaction != null) {
      _nameController.text = widget.transaction!.name ?? '';
      _amountController.text = widget.transaction!.amount.toString();
      _notesController.text = widget.transaction!.notes ?? '';
      _selectedType = widget.transaction!.type;
      _selectedCategoryId = widget.transaction!.categoryId;
      _selectedFrequency = widget.transaction!.frequency;
      if (widget.transaction!.excludedDays != null) {
        _excludedDays = widget.transaction!.excludedDays!.toSet();
      }
    }
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await _categoryRepo.getByType(_selectedType);
      setState(() {
        _categories = categories;
        if (_selectedCategoryId == null && categories.isNotEmpty) {
          _selectedCategoryId = categories.first.id;
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          BPTheme.snackError('Error loading categories: $e'),
        );
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        BPTheme.snackError('Please select a category'),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final name = _nameController.text.trim().isEmpty
          ? null
          : _nameController.text.trim();
      final amount = double.parse(_amountController.text);
      final notes = _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim();

      if (widget.transaction == null) {
        final transaction = RecurringTransaction(
          name: name,
          amount: amount,
          type: _selectedType,
          categoryId: _selectedCategoryId!,
          frequency: _selectedFrequency,
          startDate: DateTime.now(),
          notes: notes,
          createdAt: DateTime.now(),
          excludedDays: (_selectedFrequency == 'daily' && _excludedDays.isNotEmpty)
              ? (_excludedDays.toList()..sort())
              : null,
        );
        await _recurringRepo.insert(transaction);
      } else {
        final transaction = widget.transaction!.copyWith(
          name: name,
          amount: amount,
          type: _selectedType,
          categoryId: _selectedCategoryId,
          frequency: _selectedFrequency,
          notes: notes,
          excludedDays: (_selectedFrequency == 'daily' && _excludedDays.isNotEmpty)
              ? (_excludedDays.toList()..sort())
              : null,
        );
        await _recurringRepo.update(transaction);
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          BPTheme.snackError('Error saving: $e'),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BPTheme.background,
      appBar: bpAppBar(
        title: widget.transaction == null ? 'Add Recurring' : 'Edit Recurring',
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionLabel('Type'),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildTypeButton(
                        'Income', 'income', Icons.trending_down_rounded, BPTheme.income),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildTypeButton(
                        'Expense', 'expense', Icons.trending_up_rounded, BPTheme.expense),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildTypeButton(
                        'Savings', 'savings', Icons.savings_rounded, BPTheme.savings),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              _sectionLabel('Name (Optional)'),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameController,
                style: TextStyle(color: BPTheme.textPrimary),
                decoration: BPTheme.field('e.g., Daily Allowance, Monthly Rent'),
              ),
              const SizedBox(height: 24),

              _sectionLabel('Amount'),
              const SizedBox(height: 12),
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))
                ],
                style: TextStyle(color: BPTheme.textPrimary),
                decoration: BPTheme.field('0.00', prefix: '₱ '),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Please enter an amount';
                  final amount = double.tryParse(value);
                  if (amount == null || amount <= 0) return 'Please enter a valid amount';
                  return null;
                },
              ),
              const SizedBox(height: 24),

              _sectionLabel('Category'),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: BPTheme.surfaceEl,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: BPTheme.divider),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    isExpanded: true,
                    value: _selectedCategoryId,
                    dropdownColor: BPTheme.surface,
                    style: TextStyle(color: BPTheme.textPrimary, fontSize: 15),
                    icon: Icon(Icons.keyboard_arrow_down_rounded,
                        color: BPTheme.textSecondary),
                    items: _categories.map((category) {
                      return DropdownMenuItem<int>(
                        value: category.id,
                        child: Row(
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: Color(category.color).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Text(category.icon,
                                    style: const TextStyle(fontSize: 16)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(category.name,
                                style: TextStyle(color: BPTheme.textPrimary)),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (value) =>
                        setState(() => _selectedCategoryId = value),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              _sectionLabel('Frequency'),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: BPTheme.surfaceEl,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: BPTheme.divider),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: _selectedFrequency,
                    dropdownColor: BPTheme.surface,
                    style: TextStyle(color: BPTheme.textPrimary, fontSize: 15),
                    icon: Icon(Icons.keyboard_arrow_down_rounded,
                        color: BPTheme.textSecondary),
                    items: [
                      DropdownMenuItem(
                        value: 'daily',
                        child: Text('Daily',
                            style: TextStyle(color: BPTheme.textPrimary)),
                      ),
                      DropdownMenuItem(
                        value: 'weekly',
                        child: Text('Weekly',
                            style: TextStyle(color: BPTheme.textPrimary)),
                      ),
                      DropdownMenuItem(
                        value: 'monthly',
                        child: Text('Monthly',
                            style: TextStyle(color: BPTheme.textPrimary)),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedFrequency = value;
                          if (value != 'daily') _excludedDays.clear();
                        });
                      }
                    },
                  ),
                ),
              ),

              if (_selectedFrequency == 'daily') ...[
                const SizedBox(height: 24),
                _sectionLabel('Exclude Days (Optional)'),
                const SizedBox(height: 6),
                Text(
                  'Select days when this should NOT occur',
                  style: TextStyle(color: BPTheme.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 12),
                _buildDaySelector(),
              ],

              const SizedBox(height: 24),

              _sectionLabel('Notes (Optional)'),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesController,
                maxLines: 3,
                style: TextStyle(color: BPTheme.textPrimary),
                decoration: BPTheme.field('Add a note...'),
              ),
              const SizedBox(height: 32),

              BPGradientButton(
                label: widget.transaction == null
                    ? 'Add Recurring'
                    : 'Update Recurring',
                onPressed: _isLoading ? null : _save,
                isLoading: _isLoading,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDaySelector() {
    final days = [
      {'name': 'Mon', 'value': 1},
      {'name': 'Tue', 'value': 2},
      {'name': 'Wed', 'value': 3},
      {'name': 'Thu', 'value': 4},
      {'name': 'Fri', 'value': 5},
      {'name': 'Sat', 'value': 6},
      {'name': 'Sun', 'value': 7},
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: days.map((day) {
        final isExcluded = _excludedDays.contains(day['value'] as int);
        return InkWell(
          onTap: () {
            setState(() {
              if (isExcluded) {
                _excludedDays.remove(day['value'] as int);
              } else {
                _excludedDays.add(day['value'] as int);
              }
            });
          },
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isExcluded
                  ? BPTheme.expense.withOpacity(0.15)
                  : BPTheme.surfaceEl,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isExcluded ? BPTheme.expense : BPTheme.divider,
                width: isExcluded ? 1.5 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  day['name'] as String,
                  style: TextStyle(
                    color: isExcluded ? BPTheme.expense : BPTheme.textPrimary,
                    fontWeight:
                        isExcluded ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                if (isExcluded) ...[
                  const SizedBox(width: 6),
                  Icon(Icons.close_rounded, size: 14, color: BPTheme.expense),
                ],
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTypeButton(
      String label, String value, IconData icon, Color color) {
    final isSelected = _selectedType == value;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedType = value;
          _selectedCategoryId = null;
        });
        _loadCategories();
      },
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.15) : BPTheme.surfaceEl,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? color : BPTheme.divider,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon,
                color: isSelected ? color : BPTheme.textSecondary, size: 20),
            const SizedBox(height: 5),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? BPTheme.textPrimary : BPTheme.textSecondary,
                fontSize: 13,
                fontWeight:
                    isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(
        text,
        style: TextStyle(
          color: BPTheme.textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      );

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }
}
