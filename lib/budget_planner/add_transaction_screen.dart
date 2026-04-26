import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'budget_planner_theme.dart';
import 'transaction.dart' as bp_transaction;
import 'transaction_repository.dart';
import 'category.dart';
import 'category_repository.dart';
import 'savings_goal.dart';
import 'savings_goal_repository.dart';
import 'joint_savings_service.dart';

class AddTransactionScreen extends StatefulWidget {
  final bp_transaction.Transaction? transaction;

  const AddTransactionScreen({super.key, this.transaction});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final TransactionRepository _transactionRepo = TransactionRepository();
  final CategoryRepository _categoryRepo = CategoryRepository();

  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  String _selectedType = 'expense';
  int? _selectedCategoryId;
  int? _pendingCategoryId; // holds the id while categories are loading
  DateTime _selectedDate = DateTime.now();
  List<Category> _categories = [];
  bool _isLoading = false;

  final SavingsGoalRepository _goalRepo = SavingsGoalRepository();
  List<SavingsGoal> _activeGoals = [];
  int? _selectedGoalId;

  bool get _isJointTransaction =>
      widget.transaction != null &&
      (widget.transaction!.categoryId == -1 ||
          widget.transaction!.categoryId == -2);

  bool get _hideCategory =>
      _isJointTransaction ||
      (_selectedType == 'savings' && _selectedGoalId != null);

  @override
  void initState() {
    super.initState();
    if (widget.transaction != null) {
      _selectedType = widget.transaction!.type;
      _amountController.text = widget.transaction!.amount.toString();
      _notesController.text = widget.transaction!.notes ?? '';
      // Don't assign _selectedCategoryId yet — wait until categories load
      // so the DropdownButton never has a value that isn't in its items list.
      _pendingCategoryId = widget.transaction!.categoryId;
      _selectedDate = widget.transaction!.date;
      _selectedGoalId = widget.transaction!.goalId;
    }
    _loadCategories();
    if (_selectedType == 'savings') _loadActiveGoals();
  }

  Future<void> _loadActiveGoals() async {
    final goals = await _goalRepo.getActive();
    if (mounted) setState(() => _activeGoals = goals);
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await _categoryRepo.getByType(_selectedType);
      setState(() {
        _categories = categories;
        // Resolve the pending category id now that we have the list
        if (_pendingCategoryId != null) {
          if (categories.any((c) => c.id == _pendingCategoryId)) {
            _selectedCategoryId = _pendingCategoryId;
          } else {
            _selectedCategoryId =
                categories.isNotEmpty ? categories.first.id : null;
          }
          _pendingCategoryId = null;
        } else if (_selectedCategoryId == null &&
            categories.isNotEmpty &&
            widget.transaction == null) {
          if (_selectedType != 'savings') {
            _selectedCategoryId = categories.first.id;
          }
        } else if (_selectedCategoryId != null &&
            !categories.any((c) => c.id == _selectedCategoryId)) {
          _selectedCategoryId =
              categories.isNotEmpty ? categories.first.id : null;
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

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: ColorScheme.dark(
              primary: BPTheme.accentIndigo,
              onPrimary: Colors.white,
              surface: BPTheme.surface,
              onSurface: BPTheme.textPrimary,
              secondary: BPTheme.accentAmber,
              onSecondary: Colors.black,
            ),
            dialogBackgroundColor: BPTheme.surface,
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: BPTheme.accentIndigo,
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _saveTransaction() async {
    if (!_formKey.currentState!.validate()) return;

    if (_hideCategory) {
      if (_categories.isNotEmpty) {
        _selectedCategoryId = _categories.first.id;
      }
    }

    if (_selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        BPTheme.snackError('Please select a category'),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final amount = double.parse(_amountController.text);
      final notes = _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim();

      if (widget.transaction == null) {
        final transaction = bp_transaction.Transaction(
          amount: amount,
          type: _selectedType,
          categoryId: _selectedCategoryId!,
          date: _selectedDate,
          notes: notes,
          goalId:
              (_selectedType == 'savings') ? _selectedGoalId : null,
        );
        await _transactionRepo.insert(transaction);
      } else {
        final transaction = widget.transaction!.copyWith(
          amount: amount,
          type: _selectedType,
          categoryId: _selectedCategoryId,
          date: _selectedDate,
          notes: notes,
          goalId:
              (_selectedType == 'savings') ? _selectedGoalId : null,
        );
        await _transactionRepo.update(transaction);
        // If this is a joint savings/goal transaction, also sync to Firestore
        final orig = widget.transaction!;
        if (orig.jointPairId != null &&
            orig.jointTargetId != null &&
            orig.jointFirestoreTxId != null) {
          final service = JointSavingsService();
          // Map local type back to Firestore deposit/withdraw
          final firestoreType = _selectedType == 'savings' ? 'deposit' : 'withdraw';
          if (orig.categoryId == -1) {
            await service.editSavingsTransaction(
              pairId: orig.jointPairId!,
              potId: orig.jointTargetId!,
              txId: orig.jointFirestoreTxId!,
              amount: amount,
              type: firestoreType,
              notes: notes,
            );
          } else if (orig.categoryId == -2) {
            await service.editGoalTransaction(
              pairId: orig.jointPairId!,
              goalId: orig.jointTargetId!,
              txId: orig.jointFirestoreTxId!,
              amount: amount,
              type: firestoreType,
              notes: notes,
            );
          }
        }
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          BPTheme.snackError('Error saving transaction: $e'),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BPTheme.background,
      appBar: bpAppBar(
        title: widget.transaction == null
            ? 'Add Transaction'
            : 'Edit Transaction',
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
                        'Income', 'income',
                        Icons.trending_up_rounded, BPTheme.income),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildTypeButton(
                        'Expense', 'expense',
                        Icons.trending_down_rounded, BPTheme.expense),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildTypeButton(
                        'Savings', 'savings',
                        Icons.savings_rounded, BPTheme.savings),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              _sectionLabel('Amount'),
              const SizedBox(height: 12),
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                      RegExp(r'^\d+\.?\d{0,2}'))
                ],
                style: TextStyle(color: BPTheme.textPrimary),
                decoration: BPTheme.field('0.00', prefix: '₱ '),
                validator: (value) {
                  if (value == null || value.isEmpty)
                    return 'Please enter an amount';
                  final amount = double.tryParse(value);
                  if (amount == null || amount <= 0)
                    return 'Please enter a valid amount';
                  return null;
                },
              ),
              const SizedBox(height: 24),

              if (_selectedType == 'savings')
                ..._buildGoalSelector(),

              if (_isJointTransaction) ...[  
                _sectionLabel('Category'),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: BPTheme.surfaceEl,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: BPTheme.divider),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.link_rounded, color: BPTheme.accentIndigo, size: 20),
                      const SizedBox(width: 12),
                      Text(
                        widget.transaction!.categoryId == -1
                            ? 'Joint Savings Contribution'
                            : 'Joint Goal Contribution',
                        style: TextStyle(
                            color: BPTheme.textSecondary, fontSize: 15),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],

              if (!_hideCategory && !_isJointTransaction) ...[  
                _sectionLabel('Category'),
                const SizedBox(height: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16),
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
                      style: TextStyle(
                          color: BPTheme.textPrimary, fontSize: 15),
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
                                  color: Color(category.color)
                                      .withOpacity(0.2),
                                  borderRadius:
                                      BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: Text(category.icon,
                                      style: const TextStyle(
                                          fontSize: 16)),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(category.name,
                                  style: TextStyle(
                                      color: BPTheme.textPrimary)),
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
              ],

              _sectionLabel('Date'),
              const SizedBox(height: 12),
              InkWell(
                onTap: _selectDate,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: BPTheme.surfaceEl,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: BPTheme.divider),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today_rounded,
                          color: BPTheme.accentIndigo),
                      const SizedBox(width: 12),
                      Text(
                        DateFormat('MMM d, y').format(_selectedDate),
                        style: TextStyle(
                            color: BPTheme.textPrimary, fontSize: 15),
                      ),
                      const Spacer(),
                      Icon(Icons.keyboard_arrow_down_rounded,
                          color: BPTheme.textSecondary),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              _sectionLabel('Notes (Optional)'),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesController,
                maxLines: 3,
                style: TextStyle(color: BPTheme.textPrimary),
                decoration:
                    BPTheme.field('Add a note...'),
              ),
              const SizedBox(height: 32),

              BPGradientButton(
                label: widget.transaction == null
                    ? 'Add Transaction'
                    : 'Update Transaction',
                onPressed: _isLoading ? null : _saveTransaction,
                isLoading: _isLoading,
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildGoalSelector() {
    return [
      _sectionLabel('Assign to Savings Goal (Optional)'),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: BPTheme.surfaceEl,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: BPTheme.divider),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<int?>(
            isExpanded: true,
            value: _selectedGoalId,
            dropdownColor: BPTheme.surface,
            style: TextStyle(color: BPTheme.textPrimary, fontSize: 15),
            icon: Icon(Icons.keyboard_arrow_down_rounded,
                color: BPTheme.textSecondary),
            items: [
              DropdownMenuItem<int?>(
                value: null,
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: BPTheme.surfaceEl,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.block,
                          color: BPTheme.textDisabled, size: 16),
                    ),
                    const SizedBox(width: 12),
                    Text('None',
                        style:
                            TextStyle(color: BPTheme.textSecondary)),
                  ],
                ),
              ),
              ..._activeGoals.map((goal) => DropdownMenuItem<int?>(
                    value: goal.id,
                    child: Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color:
                                Color(goal.color).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(goal.icon,
                                style: const TextStyle(fontSize: 16)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(goal.name,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: BPTheme.textPrimary)),
                        ),
                      ],
                    ),
                  )),
            ],
            onChanged: (value) =>
                setState(() => _selectedGoalId = value),
          ),
        ),
      ),
      const SizedBox(height: 24),
    ];
  }

  Widget _buildTypeButton(
      String label, String value, IconData icon, Color color) {
    final isSelected = _selectedType == value;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedType = value;
          _selectedCategoryId = null;
          _selectedGoalId = null;
        });
        _loadCategories();
        if (value == 'savings') _loadActiveGoals();
      },
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withOpacity(0.15)
              : BPTheme.surfaceEl,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? color : BPTheme.divider,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon,
                color: isSelected ? color : BPTheme.textSecondary,
                size: 22),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? BPTheme.textPrimary
                    : BPTheme.textSecondary,
                fontSize: 13,
                fontWeight: isSelected
                    ? FontWeight.bold
                    : FontWeight.normal,
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
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }
}
