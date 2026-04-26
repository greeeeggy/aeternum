import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'budget_planner_theme.dart';
import 'budget.dart';
import 'category.dart';
import 'budget_repository.dart';
import 'category_repository.dart';
import 'budget_service.dart';

class AddBudgetScreen extends StatefulWidget {
  final Budget? budget;

  const AddBudgetScreen({super.key, this.budget});

  @override
  State<AddBudgetScreen> createState() => _AddBudgetScreenState();
}

class _AddBudgetScreenState extends State<AddBudgetScreen> {
  final _formKey = GlobalKey<FormState>();
  final BudgetRepository _budgetRepo = BudgetRepository();
  final CategoryRepository _categoryRepo = CategoryRepository();
  final BudgetService _budgetService = BudgetService();

  final TextEditingController _amountController =
      TextEditingController();

  int? _selectedCategoryId;
  String _selectedPeriod = 'monthly';
  bool _isOverall = false;
  List<Category> _expenseCategories = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCategories();

    if (widget.budget != null) {
      _amountController.text = widget.budget!.amount.toString();
      _selectedPeriod = widget.budget!.periodType;
      _selectedCategoryId = widget.budget!.categoryId;
      _isOverall = widget.budget!.categoryId == null;
    }
  }

  Future<void> _loadCategories() async {
    try {
      final categories =
          await _categoryRepo.getByType('expense');
      setState(() {
        _expenseCategories = categories;
        if (!_isOverall &&
            _selectedCategoryId == null &&
            categories.isNotEmpty) {
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

  Future<void> _saveBudget() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_isOverall && _selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        BPTheme.snackError('Please select a category'),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final amount = double.parse(_amountController.text);
      final dates =
          _budgetService.calculatePeriodDates(_selectedPeriod);

      if (widget.budget == null) {
        final budget = Budget(
          categoryId: _isOverall ? null : _selectedCategoryId,
          amount: amount,
          periodType: _selectedPeriod,
          startDate: dates['startDate']!,
          endDate: dates['endDate']!,
          createdAt: DateTime.now(),
        );
        await _budgetRepo.insert(budget);
      } else {
        final budget = widget.budget!.copyWith(
          categoryId: _isOverall ? null : _selectedCategoryId,
          amount: amount,
          periodType: _selectedPeriod,
          startDate: dates['startDate'],
          endDate: dates['endDate'],
        );
        await _budgetRepo.update(budget);
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          BPTheme.snackError('Error saving budget: $e'),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BPTheme.background,
      appBar: bpAppBar(
        title: widget.budget == null ? 'Add Budget' : 'Edit Budget',
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionLabel('Budget Type'),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildTypeButton('Overall Budget', true),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child:
                        _buildTypeButton('Category Budget', false),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              if (!_isOverall) ...[
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
                          color: BPTheme.textPrimary,
                          fontSize: 15),
                      icon: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: BPTheme.textSecondary),
                      items: _expenseCategories.map((category) {
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
                                      color:
                                          BPTheme.textPrimary)),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(
                            () => _selectedCategoryId = value);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],

              _sectionLabel('Budget Amount'),
              const SizedBox(height: 12),
              TextFormField(
                controller: _amountController,
                keyboardType:
                    const TextInputType.numberWithOptions(
                        decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                      RegExp(r'^\d+\.?\d{0,2}')),
                ],
                style: TextStyle(color: BPTheme.textPrimary),
                decoration:
                    BPTheme.field('0.00', prefix: '₱ '),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a budget amount';
                  }
                  final amount = double.tryParse(value);
                  if (amount == null || amount <= 0) {
                    return 'Please enter a valid amount';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              _sectionLabel('Period'),
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
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: _selectedPeriod,
                    dropdownColor: BPTheme.surface,
                    style: TextStyle(
                        color: BPTheme.textPrimary, fontSize: 15),
                    icon: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: BPTheme.textSecondary),
                    items: [
                      DropdownMenuItem(
                        value: 'weekly',
                        child: Text('Weekly',
                            style: TextStyle(
                                color: BPTheme.textPrimary)),
                      ),
                      DropdownMenuItem(
                        value: 'monthly',
                        child: Text('Monthly',
                            style: TextStyle(
                                color: BPTheme.textPrimary)),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _selectedPeriod = value);
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 32),

              BPGradientButton(
                label: widget.budget == null
                    ? 'Create Budget'
                    : 'Update Budget',
                onPressed: _isLoading ? null : _saveBudget,
                isLoading: _isLoading,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeButton(String label, bool isOverall) {
    final isSelected = _isOverall == isOverall;
    return InkWell(
      onTap: () {
        setState(() {
          _isOverall = isOverall;
          if (isOverall) {
            _selectedCategoryId = null;
          } else if (_expenseCategories.isNotEmpty) {
            _selectedCategoryId = _expenseCategories.first.id;
          }
        });
      },
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? BPTheme.accentIndigo.withOpacity(0.15)
              : BPTheme.surfaceEl,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? BPTheme.accentIndigo
                : BPTheme.divider,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected
                ? BPTheme.textPrimary
                : BPTheme.textSecondary,
            fontSize: 14,
            fontWeight: isSelected
                ? FontWeight.bold
                : FontWeight.normal,
          ),
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
    super.dispose();
  }
}
