import 'package:flutter/material.dart';
import 'budget_planner_theme.dart';
import 'category.dart';
import 'category_repository.dart';
import 'add_category_screen.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  final CategoryRepository _categoryRepo = CategoryRepository();

  List<Category> _incomeCategories = [];
  List<Category> _expenseCategories = [];
  List<Category> _savingsCategories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final income = await _categoryRepo.getByType('income');
      final expense = await _categoryRepo.getByType('expense');
      final savings = await _categoryRepo.getByType('savings');

      setState(() {
        _incomeCategories = income;
        _expenseCategories = expense;
        _savingsCategories = savings;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          BPTheme.snackError('Error loading categories: $e'),
        );
      }
    }
  }

  void _navigateToAddCategory({Category? category}) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddCategoryScreen(category: category),
      ),
    );
    if (result == true) _loadData();
  }

  Future<void> _deleteCategory(Category category) async {
    try {
      await _categoryRepo.delete(category.id!);
      _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          BPTheme.snackSuccess('Category deleted'),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          BPTheme.snackError('Error: $e'),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BPTheme.background,
      appBar: bpAppBar(title: 'Categories'),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                  color: BPTheme.accentIndigo))
          : RefreshIndicator(
              onRefresh: _loadData,
              color: BPTheme.accentIndigo,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildSection('Income Categories',
                      _incomeCategories, BPTheme.income),
                  const SizedBox(height: 24),
                  _buildSection('Expense Categories',
                      _expenseCategories, BPTheme.expense),
                  const SizedBox(height: 24),
                  _buildSection('Savings Categories',
                      _savingsCategories, BPTheme.savings),
                ],
              ),
            ),
      floatingActionButton: BPGradientFab(
        onPressed: () => _navigateToAddCategory(),
      ),
    );
  }

  Widget _buildSection(
      String title, List<Category> categories, Color accent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 20,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                color: BPTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...categories.map((category) =>
            _buildCategoryTile(category)),
      ],
    );
  }

  Widget _buildCategoryTile(Category category) {
    final isDefault = category.isDefault;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BPTheme.cardDecoration,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Color(category.color).withOpacity(0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(category.icon,
                  style: const TextStyle(fontSize: 22)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category.name,
                  style: TextStyle(
                    color: BPTheme.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isDefault
                        ? BPTheme.accentIndigo.withOpacity(0.12)
                        : BPTheme.accentAmber.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    isDefault ? 'Default' : 'Custom',
                    style: TextStyle(
                      color: isDefault
                          ? BPTheme.accentIndigo
                          : BPTheme.accentAmber,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (!isDefault)
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert_rounded,
                  color: BPTheme.textSecondary),
              color: BPTheme.surface,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              onSelected: (value) {
                if (value == 'edit') {
                  _navigateToAddCategory(category: category);
                } else if (value == 'delete') {
                  _deleteCategory(category);
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit_rounded,
                          color: BPTheme.accentIndigo, size: 18),
                      const SizedBox(width: 10),
                      Text('Edit',
                          style: TextStyle(
                              color: BPTheme.textPrimary)),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_rounded,
                          color: BPTheme.expense, size: 18),
                      const SizedBox(width: 10),
                      Text('Delete',
                          style:
                              TextStyle(color: BPTheme.expense)),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
