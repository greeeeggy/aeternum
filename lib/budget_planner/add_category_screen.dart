import 'package:flutter/material.dart';
import 'budget_planner_theme.dart';
import 'category.dart';
import 'category_repository.dart';

class AddCategoryScreen extends StatefulWidget {
  final Category? category;

  const AddCategoryScreen({super.key, this.category});

  @override
  State<AddCategoryScreen> createState() => _AddCategoryScreenState();
}

class _AddCategoryScreenState extends State<AddCategoryScreen> {
  final _formKey = GlobalKey<FormState>();
  final CategoryRepository _categoryRepo = CategoryRepository();

  final TextEditingController _nameController = TextEditingController();

  String _selectedType = 'expense';
  String _selectedIcon = '🍔';
  Color _selectedColor = const Color(0xFFFF6B6B);
  bool _isLoading = false;

  final List<String> _icons = [
    '🍔', '🚗', '🏠', '💡', '🎮', '🛍️', '⚕️', '📚',
    '✈️', '🎬', '🏋️', '🎨', '🎵', '📱', '💻', '☕',
    '🍕', '🌮', '🍜', '🍺', '🎓', '🏥', '🚇', '⛽',
  ];

  final List<Color> _colors = [
    const Color(0xFFFF6B6B),
    const Color(0xFF4ECDC4),
    const Color(0xFF95E1D3),
    const Color(0xFFFFA07A),
    const Color(0xFFDDA15E),
    const Color(0xFFBC6C25),
    const Color(0xFF06BEE1),
    const Color(0xFF38A3A5),
    const Color(0xFF4CAF50),
    const Color(0xFF8BC34A),
    const Color(0xFF009688),
    const Color(0xFF00BCD4),
  ];

  @override
  void initState() {
    super.initState();
    if (widget.category != null) {
      _nameController.text = widget.category!.name;
      _selectedType = widget.category!.type;
      _selectedIcon = widget.category!.icon;
      _selectedColor = Color(widget.category!.color);
    }
  }

  Future<void> _saveCategory() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final name = _nameController.text.trim();
      if (widget.category == null) {
        final category = Category(
          name: name,
          type: _selectedType,
          icon: _selectedIcon,
          color: _selectedColor.value,
          createdAt: DateTime.now(),
        );
        await _categoryRepo.insert(category);
      } else {
        final category = widget.category!.copyWith(
          name: name,
          type: _selectedType,
          icon: _selectedIcon,
          color: _selectedColor.value,
        );
        await _categoryRepo.update(category);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          BPTheme.snackError('Error saving category: $e'),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BPTheme.background,
      appBar: bpAppBar(
        title: widget.category == null
            ? 'Add Category'
            : 'Edit Category',
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionLabel('Category Name'),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameController,
                style: TextStyle(color: BPTheme.textPrimary),
                decoration:
                    BPTheme.field('Enter category name'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a category name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              _sectionLabel('Type'),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                      child: _buildTypeButton('Income', 'income')),
                  const SizedBox(width: 8),
                  Expanded(
                      child:
                          _buildTypeButton('Expense', 'expense')),
                  const SizedBox(width: 8),
                  Expanded(
                      child:
                          _buildTypeButton('Savings', 'savings')),
                ],
              ),
              const SizedBox(height: 24),

              _sectionLabel('Icon'),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BPTheme.cardDecoration,
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _icons.map((icon) {
                    final isSelected = icon == _selectedIcon;
                    return InkWell(
                      onTap: () =>
                          setState(() => _selectedIcon = icon),
                      borderRadius: BorderRadius.circular(12),
                      child: AnimatedContainer(
                        duration:
                            const Duration(milliseconds: 120),
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? _selectedColor.withOpacity(0.25)
                              : BPTheme.surfaceEl,
                          borderRadius:
                              BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? _selectedColor
                                : BPTheme.divider,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Center(
                          child: Text(icon,
                              style: const TextStyle(
                                  fontSize: 22)),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 24),

              _sectionLabel('Color'),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BPTheme.cardDecoration,
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: _colors.map((color) {
                    final isSelected = color == _selectedColor;
                    return InkWell(
                      onTap: () =>
                          setState(() => _selectedColor = color),
                      borderRadius: BorderRadius.circular(14),
                      child: AnimatedContainer(
                        duration:
                            const Duration(milliseconds: 120),
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius:
                              BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected
                                ? Colors.white
                                : Colors.transparent,
                            width: 3,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: color.withOpacity(0.5),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  )
                                ]
                              : [],
                        ),
                        child: isSelected
                            ? const Icon(Icons.check,
                                color: Colors.white, size: 22)
                            : null,
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 32),

              BPGradientButton(
                label: widget.category == null
                    ? 'Add Category'
                    : 'Update Category',
                onPressed: _isLoading ? null : _saveCategory,
                isLoading: _isLoading,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeButton(String label, String value) {
    final isSelected = _selectedType == value;
    final color = value == 'income'
        ? BPTheme.income
        : value == 'savings'
            ? BPTheme.savings
            : BPTheme.expense;
    return InkWell(
      onTap: () => setState(() => _selectedType = value),
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 14),
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
    _nameController.dispose();
    super.dispose();
  }
}
