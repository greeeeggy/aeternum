import 'dart:convert';
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:confetti/confetti.dart';
import 'package:intl/intl.dart';
import 'budget_planner_theme.dart';
import 'budget_service.dart';
import 'category.dart';
import 'category_repository.dart';
import 'transaction_repository.dart';
import 'savings_goal.dart';
import 'savings_goal_repository.dart';
import 'add_savings_goal_screen.dart';
// ── Joint savings imports ──────────────────────────────────────────────────
import 'joint_savings_service.dart';
import 'joint_deposit_screen.dart';
import 'add_joint_savings_screen.dart';
import 'joint_savings_detail_screen.dart';
import 'add_joint_goal_screen.dart';

class SavingsScreen extends StatefulWidget {
  const SavingsScreen({super.key});

  @override
  State<SavingsScreen> createState() => _SavingsScreenState();
}

class _SavingsScreenState extends State<SavingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BPTheme.background,
      body: Column(
        children: [
          Container(
            color: BPTheme.surface,
            child: TabBar(
              controller: _tabController,
              indicatorColor: BPTheme.accentAmber,
              labelColor: BPTheme.accentAmber,
              unselectedLabelColor: BPTheme.textSecondary,
              indicatorWeight: 3,
              tabs: const [
                Tab(text: 'Overview'),
                Tab(text: 'Goals'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [
                _OverviewTab(),
                _GoalsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// OVERVIEW TAB
// ─────────────────────────────────────────────

class _OverviewTab extends StatefulWidget {
  const _OverviewTab();

  @override
  State<_OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends State<_OverviewTab> {
  final BudgetService _budgetService = BudgetService();
  final TransactionRepository _transactionRepo = TransactionRepository();
  final CategoryRepository _categoryRepo = CategoryRepository();
  final SavingsGoalRepository _goalRepo = SavingsGoalRepository();

  String _selectedPeriod = 'monthly';
  double _totalSavings = 0.0;
  List<Map<String, dynamic>> _savingsBreakdown = [];
  bool _isLoading = true;

  // ── Joint savings: pairId is loaded once ─────────────────────────────────
  String? _pairId;

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadPairId();
  }

  Future<void> _loadPairId() async {
    final id = await JointSavingsService.getPairId();
    if (mounted) setState(() => _pairId = id);
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final dates = _budgetService.calculatePeriodDates(_selectedPeriod,
          focusedDate: DateTime.now());
      final startDate = dates['startDate']!;
      final endDate = dates['endDate']!;

      final total =
          await _budgetService.getTotalSavings(startDate, endDate);

      final transactions =
          await _transactionRepo.getByDateRange(startDate, endDate);
      final savingsTx =
          transactions.where((t) => t.type == 'savings').toList();

      final goalIds = savingsTx
          .where((t) => t.goalId != null)
          .map((t) => t.goalId!)
          .toSet();
      final categoryIds = savingsTx
          .where((t) => t.goalId == null)
          .map((t) => t.categoryId)
          .toSet();

      final goalResults =
          await Future.wait(goalIds.map((id) => _goalRepo.getById(id)));
      final categoryResults = await Future.wait(
          categoryIds.map((id) => _categoryRepo.getById(id)));

      final Map<int, SavingsGoal> goalMap = {};
      for (final g in goalResults) {
        if (g != null) goalMap[g.id!] = g;
      }
      final Map<int, Category> categoryMap = {};
      for (final c in categoryResults) {
        if (c != null) categoryMap[c.id!] = c;
      }

      final Map<String, double> grouped = {};
      for (final t in savingsTx) {
        final key =
            t.goalId != null ? 'goal_${t.goalId}' : 'cat_${t.categoryId}';
        grouped[key] = (grouped[key] ?? 0.0) + t.amount;
      }

      final breakdown = grouped.entries.map((e) {
        if (e.key.startsWith('goal_')) {
          final id = int.parse(e.key.substring(5));
          final goal = goalMap[id];
          return {
            'label': goal?.name ?? 'Goal',
            'icon': goal?.icon ?? '🎯',
            'color': goal?.color ?? 0xFF10B981,
            'amount': e.value,
          };
        } else {
          final id = int.parse(e.key.substring(4));
          final cat = categoryMap[id];
          return {
            'label': cat?.name ?? 'Savings',
            'icon': cat?.icon ?? '💰',
            'color': cat?.color ?? 0xFFFFC107,
            'amount': e.value,
          };
        }
      }).toList()
        ..sort((a, b) =>
            (b['amount'] as double).compareTo(a['amount'] as double));

      setState(() {
        _totalSavings = total;
        _savingsBreakdown = breakdown;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          BPTheme.snackError('Error: $e'),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(
          child:
              CircularProgressIndicator(color: BPTheme.accentAmber));
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      color: BPTheme.accentAmber,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildPeriodSelector(),
          const SizedBox(height: 20),
          _buildTotalCard(),
          const SizedBox(height: 24),

          // ── JOINT SAVINGS SECTION — before "By Category" ──────────────
          if (_pairId != null) ...[
            _JointSavingsSection(pairId: _pairId!),
            const SizedBox(height: 8),
          ],

          Text('By Category',
              style: TextStyle(
                  color: BPTheme.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          if (_savingsBreakdown.isEmpty)
            _buildEmptyCategories()
          else
            ..._savingsBreakdown
                .map((entry) => _buildBreakdownTile(entry)),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector() {
    const periods = [
      {'label': 'Weekly', 'value': 'weekly'},
      {'label': 'Monthly', 'value': 'monthly'},
      {'label': 'Yearly', 'value': 'yearly'},
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: periods.map((p) {
          final sel = _selectedPeriod == p['value'];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () {
                if (!sel) {
                  setState(() => _selectedPeriod = p['value']!);
                  _loadData();
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 9),
                decoration: BoxDecoration(
                  color: sel
                      ? BPTheme.accentAmber.withOpacity(0.15)
                      : BPTheme.surfaceEl,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: sel
                        ? BPTheme.accentAmber
                        : BPTheme.divider,
                  ),
                ),
                child: Text(
                  p['label']!,
                  style: TextStyle(
                    color: sel
                        ? BPTheme.accentAmber
                        : BPTheme.textSecondary,
                    fontWeight: sel
                        ? FontWeight.bold
                        : FontWeight.normal,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTotalCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: BPTheme.gradientSavings,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: const [
            Icon(Icons.savings_rounded, color: Colors.black87, size: 28),
            SizedBox(width: 10),
            Text('Total Savings',
                style: TextStyle(
                    color: Colors.black87,
                    fontSize: 16,
                    fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 12),
          Text(
            '₱${NumberFormat('#,##0.00').format(_totalSavings)}',
            style: const TextStyle(
                color: Colors.black,
                fontSize: 36,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            _periodLabel(),
            style: TextStyle(
                color: Colors.black.withOpacity(0.6), fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownTile(Map<String, dynamic> entry) {
    final label = entry['label'] as String;
    final icon = entry['icon'] as String;
    final color = Color(entry['color'] as int);
    final amount = entry['amount'] as double;
    final percentage =
        _totalSavings > 0 ? (amount / _totalSavings * 100) : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BPTheme.cardDecoration,
      child: Row(children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(13)),
          child: Center(
              child: Text(icon, style: const TextStyle(fontSize: 24))),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      color: BPTheme.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w500)),
              const SizedBox(height: 5),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: percentage / 100,
                  minHeight: 6,
                  backgroundColor: BPTheme.divider,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Text(
          '₱${NumberFormat('#,##0.00').format(amount)}',
          style: TextStyle(
              color: color,
              fontSize: 15,
              fontWeight: FontWeight.bold),
        ),
      ]),
    );
  }

  Widget _buildEmptyCategories() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BPTheme.cardDecoration,
      child: Column(children: [
        Icon(Icons.savings_outlined,
            size: 48,
            color: BPTheme.accentAmber.withOpacity(0.4)),
        const SizedBox(height: 12),
        Text('No savings yet',
            style:
                TextStyle(color: BPTheme.textSecondary, fontSize: 16)),
        const SizedBox(height: 4),
        Text('Add savings transactions to see them here',
            style:
                TextStyle(color: BPTheme.textDisabled, fontSize: 13),
            textAlign: TextAlign.center),
      ]),
    );
  }

  String _periodLabel() {
    switch (_selectedPeriod) {
      case 'weekly':
        return 'This week';
      case 'monthly':
        return 'This month';
      case 'yearly':
        return 'This year';
      default:
        return '';
    }
  }
}

// ─────────────────────────────────────────────
// JOINT SAVINGS SECTION (inserted into Overview)
// Uses Firestore StreamBuilder — live updates for both partners
// ─────────────────────────────────────────────

class _JointSavingsSection extends StatelessWidget {
  final String pairId;
  const _JointSavingsSection({required this.pairId});

  @override
  Widget build(BuildContext context) {
    final service = JointSavingsService();

    return StreamBuilder<List<JointSavingsPot>>(
      stream: service.potsStream(pairId),
      builder: (context, snapshot) {
        final pots = snapshot.data ?? [];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section header
            Row(children: [
              Text('Joint Savings',
                  style: TextStyle(
                      color: BPTheme.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.bold)),
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        AddJointSavingsScreen(pairId: pairId),
                  ),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: BPTheme.accentAmber.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: BPTheme.accentAmber.withOpacity(0.4)),
                  ),
                  child: Row(children: [
                    Icon(Icons.add,
                        color: BPTheme.accentAmber, size: 16),
                    const SizedBox(width: 4),
                    Text('New',
                        style: TextStyle(
                            color: BPTheme.accentAmber,
                            fontSize: 13,
                            fontWeight: FontWeight.bold)),
                  ]),
                ),
              ),
            ]),
            const SizedBox(height: 12),

            if (pots.isEmpty)
              _buildEmptyJoint(context)
            else
              ...pots.map((pot) =>
                  _JointPotCard(pairId: pairId, pot: pot)),

            const SizedBox(height: 16),
            Divider(color: BPTheme.divider),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }

  Widget _buildEmptyJoint(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BPTheme.cardDecoration,
      child: Column(children: [
        const Text('👫', style: TextStyle(fontSize: 36)),
        const SizedBox(height: 10),
        Text('No joint savings yet',
            style:
                TextStyle(color: BPTheme.textSecondary, fontSize: 15)),
        const SizedBox(height: 4),
        Text('Create a shared savings pot with your partner',
            style: TextStyle(
                color: BPTheme.textDisabled, fontSize: 12),
            textAlign: TextAlign.center),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  AddJointSavingsScreen(pairId: pairId),
            ),
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: BPTheme.gradientSavings),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text('Create Joint Savings',
                style: TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.bold,
                    fontSize: 13)),
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────
// JOINT POT CARD (in Overview)
// Has its own StreamBuilder for latest transactions
// ─────────────────────────────────────────────

class _JointPotCard extends StatelessWidget {
  final String pairId;
  final JointSavingsPot pot;

  const _JointPotCard({required this.pairId, required this.pot});

  @override
  Widget build(BuildContext context) {
    final service = JointSavingsService();
    final fmt = NumberFormat('#,##0.00');

    return StreamBuilder<List<JointTransaction>>(
      stream: service.savingsTxStream(pairId, pot.id),
      builder: (context, snapshot) {
        final txs = snapshot.data ?? [];

        double total = 0;
        for (final tx in txs) {
          total += tx.type == 'deposit' ? tx.amount : -tx.amount;
        }
        final latest = txs.take(2).toList();

        return GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => JointSavingsDetailScreen(
                  pairId: pairId, pot: pot),
            ),
          ),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BPTheme.cardDecoration,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Card header ─────────────────────────────────────
                Container(
                  padding:
                      const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        BPTheme.accentAmber.withOpacity(0.15),
                        BPTheme.accentAmber.withOpacity(0.05),
                      ],
                    ),
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(20)),
                  ),
                  child: Row(children: [
                    const Text('👫',
                        style: TextStyle(fontSize: 22)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(pot.name,
                              style: TextStyle(
                                  color: BPTheme.textPrimary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          if (pot.description.isNotEmpty)
                            Text(pot.description,
                                style: TextStyle(
                                    color: BPTheme.textSecondary,
                                    fontSize: 12),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '₱${fmt.format(total)}',
                          style: TextStyle(
                              color: BPTheme.accentAmber,
                              fontSize: 18,
                              fontWeight: FontWeight.bold),
                        ),
                        Text('total',
                            style: TextStyle(
                                color: BPTheme.textDisabled,
                                fontSize: 11)),
                      ],
                    ),
                  ]),
                ),

                // ── Latest 2 transactions ────────────────────────────
                if (latest.isNotEmpty)
                  Padding(
                    padding:
                        const EdgeInsets.fromLTRB(16, 0, 16, 0),
                    child: Column(
                      children: latest.map((tx) {
                        final isDeposit = tx.type == 'deposit';
                        final color = isDeposit
                            ? BPTheme.income
                            : BPTheme.expense;
                        final sign = isDeposit ? '+' : '-';
                        return Padding(
                          padding:
                              const EdgeInsets.only(top: 10),
                          child: Row(children: [
                            _MiniAvatar(
                                avatarBase64: tx.avatarBase64,
                                photoUrl: tx.photoUrl,
                                name: tx.displayName),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(tx.displayName,
                                  style: TextStyle(
                                      color: BPTheme.textPrimary,
                                      fontSize: 13,
                                      fontWeight:
                                          FontWeight.w500),
                                  maxLines: 1,
                                  overflow:
                                      TextOverflow.ellipsis),
                            ),
                            Text(
                              '$sign₱${fmt.format(tx.amount)}',
                              style: TextStyle(
                                  color: color,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold),
                            ),
                          ]),
                        );
                      }).toList(),
                    ),
                  ),

                // ── Footer: Deposit button + View all ───────────────
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => JointDepositScreen(
                              pairId: pairId,
                              targetId: pot.id,
                              targetName: pot.name,
                              txContext: JointTxContext.savings,
                              initialType: 'deposit',
                            ),
                          ),
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: 10),
                          decoration: BoxDecoration(
                            color: BPTheme.income.withOpacity(0.12),
                            borderRadius:
                                BorderRadius.circular(12),
                            border: Border.all(
                                color:
                                    BPTheme.income.withOpacity(0.3)),
                          ),
                          child: Row(
                            mainAxisAlignment:
                                MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_circle_outline,
                                  color: BPTheme.income,
                                  size: 16),
                              const SizedBox(width: 4),
                              Text('Deposit',
                                  style: TextStyle(
                                      color: BPTheme.income,
                                      fontSize: 13,
                                      fontWeight:
                                          FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => JointSavingsDetailScreen(
                              pairId: pairId, pot: pot),
                        ),
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: BPTheme.surfaceEl,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: BPTheme.divider),
                        ),
                        child: Text('View All',
                            style: TextStyle(
                                color: BPTheme.textSecondary,
                                fontSize: 13,
                                fontWeight: FontWeight.w500)),
                      ),
                    ),
                  ]),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Small 28px avatar used in the pot card preview rows
class _MiniAvatar extends StatelessWidget {
  final String? avatarBase64;
  final String? photoUrl;
  final String name;
  const _MiniAvatar({required this.avatarBase64, this.photoUrl, required this.name});

  @override
  Widget build(BuildContext context) {
    if (avatarBase64 != null && avatarBase64!.isNotEmpty) {
      return CircleAvatar(
        radius: 14,
        backgroundImage: MemoryImage(base64Decode(avatarBase64!)),
      );
    }
    if (photoUrl != null && photoUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: 14,
        backgroundImage: NetworkImage(photoUrl!),
      );
    }
    return CircleAvatar(
      radius: 14,
      backgroundColor: BPTheme.accentAmber.withOpacity(0.2),
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: TextStyle(
            color: BPTheme.accentAmber,
            fontWeight: FontWeight.bold,
            fontSize: 11),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// GOALS TAB
// ─────────────────────────────────────────────

class _GoalsTab extends StatefulWidget {
  const _GoalsTab();

  @override
  State<_GoalsTab> createState() => _GoalsTabState();
}

/// A unified item that represents either a solo SavingsGoal or a JointGoal.
class _GoalItem {
  final SavingsGoal? soloGoal;
  final JointGoal? jointGoal;

  const _GoalItem.solo(SavingsGoal g)
      : soloGoal = g,
        jointGoal = null;
  const _GoalItem.joint(JointGoal g)
      : jointGoal = g,
        soloGoal = null;

  bool get isJoint => jointGoal != null;
  String get name => isJoint ? jointGoal!.name : soloGoal!.name;
  String get icon => isJoint ? jointGoal!.icon : soloGoal!.icon;
  int get color => isJoint ? jointGoal!.color : soloGoal!.color;
}

class _GoalsTabState extends State<_GoalsTab> {
  final _goalRepo = SavingsGoalRepository();
  final _jointService = JointSavingsService();

  // Solo goals — loaded from SQLite (unchanged logic)
  List<SavingsGoal> _soloGoals = [];

  // Joint goals — live from Firestore
  List<JointGoal> _jointGoals = [];
  StreamSubscription<List<JointGoal>>? _jointGoalSub;

  String? _pairId;
  int _selectedIndex = 0;
  bool _isLoading = true;

  List<_GoalItem> get _allItems => [
        ..._soloGoals.map((g) => _GoalItem.solo(g)),
        ..._jointGoals.map((g) => _GoalItem.joint(g)),
      ];

  @override
  void initState() {
    super.initState();
    _loadSoloGoals();
    _initJointGoals();
  }

  Future<void> _initJointGoals() async {
    final id = await JointSavingsService.getPairId();
    if (!mounted) return;
    setState(() => _pairId = id);
    if (id == null) return;

    _jointGoalSub =
        _jointService.goalsStream(id).listen((goals) {
      if (mounted) {
        setState(() {
          _jointGoals = goals;
          // Keep selected index in bounds
          if (_selectedIndex >= _allItems.length && _allItems.isNotEmpty) {
            _selectedIndex = 0;
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _jointGoalSub?.cancel();
    super.dispose();
  }

  Future<void> _loadSoloGoals() async {
    setState(() => _isLoading = true);
    final goals = await _goalRepo.getAll();
    setState(() {
      _soloGoals = goals;
      if (_selectedIndex >= _allItems.length) _selectedIndex = 0;
      _isLoading = false;
    });
  }

  void _navigateToAddSoloGoal() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddSavingsGoalScreen()),
    );
    if (result == true) _loadSoloGoals();
  }

  void _navigateToEditSoloGoal(SavingsGoal goal) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => AddSavingsGoalScreen(goal: goal)),
    );
    if (result == true || result == 'deleted') _loadSoloGoals();
  }

  void _navigateToAddJointGoal() async {
    if (_pairId == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => AddJointGoalScreen(pairId: _pairId!)),
    );
    // Joint goals update via stream; no manual reload needed
  }

  void _navigateToEditJointGoal(JointGoal goal) async {
    if (_pairId == null) return;
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) =>
              AddJointGoalScreen(pairId: _pairId!, goal: goal)),
    );
    if (result == 'deleted') {
      // Stream will remove it; reset selection if needed
      setState(() {
        if (_selectedIndex >= _allItems.length) _selectedIndex = 0;
      });
    }
  }

  /// Shows a bottom sheet to pick Solo or Joint goal type.
  void _showGoalTypeChooser() {
    showModalBottomSheet(
      context: context,
      backgroundColor: BPTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: BPTheme.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text('What kind of goal?',
                style: TextStyle(
                    color: BPTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    Navigator.pop(ctx);
                    _navigateToAddSoloGoal();
                  },
                  child: _GoalTypeCard(
                    emoji: '👤',
                    label: 'Solo Goal',
                    sublabel: 'Just for you',
                    color: BPTheme.income,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    Navigator.pop(ctx);
                    _navigateToAddJointGoal();
                  },
                  child: _GoalTypeCard(
                    emoji: '👫',
                    label: 'Joint Goal',
                    sublabel: 'Both partners',
                    color: const Color(0xFF8B5CF6),
                  ),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(
          child: CircularProgressIndicator(color: BPTheme.income));
    }
    if (_allItems.isEmpty) return _buildEmptyState();

    final items = _allItems;
    // Guard selected index
    final safeIndex =
        _selectedIndex.clamp(0, items.length - 1);
    final selected = items[safeIndex];

    return RefreshIndicator(
      onRefresh: _loadSoloGoals,
      color: BPTheme.income,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Chip selector ─────────────────────────────────────────────
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ...items.asMap().entries.map((entry) {
                  final i = entry.key;
                  final item = entry.value;
                  final sel = i == safeIndex;
                  final accent = Color(item.color);
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () =>
                          setState(() => _selectedIndex = i),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: sel
                              ? accent.withOpacity(0.2)
                              : BPTheme.surfaceEl,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: sel ? accent : BPTheme.divider,
                            width: 1.5,
                          ),
                        ),
                        child: Row(children: [
                          Text(item.icon,
                              style: const TextStyle(fontSize: 16)),
                          const SizedBox(width: 6),
                          Text(
                            item.name,
                            style: TextStyle(
                              color: sel
                                  ? BPTheme.textPrimary
                                  : BPTheme.textSecondary,
                              fontWeight: sel
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              fontSize: 13,
                            ),
                          ),
                          // 👫 badge for joint goals
                          if (item.isJoint) ...[
                            const SizedBox(width: 4),
                            const Text('👫',
                                style: TextStyle(fontSize: 12)),
                          ],
                        ]),
                      ),
                    ),
                  );
                }),
                // ── "New" button → shows type chooser ──────────────────
                GestureDetector(
                  onTap: _showGoalTypeChooser,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: BPTheme.surfaceEl,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: BPTheme.divider, width: 1),
                    ),
                    child: Row(children: [
                      Icon(Icons.add,
                          color: BPTheme.textSecondary, size: 16),
                      const SizedBox(width: 4),
                      Text('New',
                          style: TextStyle(
                              color: BPTheme.textSecondary,
                              fontSize: 13)),
                    ]),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Goal detail ───────────────────────────────────────────────
          if (!selected.isJoint)
            _GoalDetailInline(
              key: ValueKey('solo_${selected.soloGoal!.id}'),
              goal: selected.soloGoal!,
              onGoalChanged: _loadSoloGoals,
              onEdit: () =>
                  _navigateToEditSoloGoal(selected.soloGoal!),
            )
          else if (_pairId != null)
            _JointGoalDetailInline(
              key: ValueKey('joint_${selected.jointGoal!.id}'),
              pairId: _pairId!,
              goal: selected.jointGoal!,
              onEdit: () =>
                  _navigateToEditJointGoal(selected.jointGoal!),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: BPTheme.income.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.savings_outlined,
                  color: BPTheme.income, size: 44),
            ),
            const SizedBox(height: 24),
            Text('No savings goals yet',
                style: TextStyle(
                    color: BPTheme.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text(
              'Create a solo goal for yourself,\nor a joint goal with your partner.',
              style: TextStyle(
                  color: BPTheme.textSecondary,
                  fontSize: 15,
                  height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Row(children: [
              Expanded(
                child: BPGradientButton(
                  label: 'Solo Goal',
                  gradientColors: [BPTheme.income, BPTheme.accent],
                  onPressed: _navigateToAddSoloGoal,
                ),
              ),
              if (_pairId != null) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: BPGradientButton(
                    label: 'Joint Goal',
                    gradientColors: const [
                      Color(0xFF8B5CF6),
                      Color(0xFF6D28D9)
                    ],
                    onPressed: _navigateToAddJointGoal,
                  ),
                ),
              ],
            ]),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// GOAL TYPE CARD (for the bottom sheet chooser)
// ─────────────────────────────────────────────

class _GoalTypeCard extends StatelessWidget {
  final String emoji;
  final String label;
  final String sublabel;
  final Color color;

  const _GoalTypeCard({
    required this.emoji,
    required this.label,
    required this.sublabel,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.3), width: 1.5),
      ),
      child: Column(children: [
        Text(emoji, style: const TextStyle(fontSize: 32)),
        const SizedBox(height: 10),
        Text(label,
            style: TextStyle(
                color: BPTheme.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(sublabel,
            style: TextStyle(
                color: BPTheme.textSecondary, fontSize: 12)),
      ]),
    );
  }
}

// ─────────────────────────────────────────────
// JOINT GOAL DETAIL INLINE
// Mirrors _GoalDetailInline but reads from Firestore stream
// ─────────────────────────────────────────────

class _JointGoalDetailInline extends StatefulWidget {
  final String pairId;
  final JointGoal goal;
  final VoidCallback onEdit;

  const _JointGoalDetailInline({
    super.key,
    required this.pairId,
    required this.goal,
    required this.onEdit,
  });

  @override
  State<_JointGoalDetailInline> createState() =>
      _JointGoalDetailInlineState();
}

class _JointGoalDetailInlineState
    extends State<_JointGoalDetailInline>
    with TickerProviderStateMixin {
  final _service = JointSavingsService();
  StreamSubscription<List<JointTransaction>>? _txSub;

  List<JointTransaction> _transactions = [];
  bool _loaded = false;
  bool _wasCompleted = false;

  late AnimationController _progressAnimCtrl;
  late Animation<double> _progressAnim;
  late ConfettiController _confettiCtrl;

  final _fmt = NumberFormat('#,##0.00');

  double get _currentSaved {
    double total = 0;
    for (final tx in _transactions) {
      total += tx.type == 'deposit' ? tx.amount : -tx.amount;
    }
    return total.clamp(0.0, double.infinity);
  }

  double get _progress =>
      (_currentSaved / widget.goal.targetAmount).clamp(0.0, 1.0);

  double get _remaining =>
      (widget.goal.targetAmount - _currentSaved)
          .clamp(0.0, double.infinity);

  int get _monthsUntilDeadline {
    final now = DateTime.now();
    return ((widget.goal.deadline.year - now.year) * 12 +
            widget.goal.deadline.month - now.month)
        .clamp(1, 9999);
  }

  double get _monthlyRequired => _remaining / _monthsUntilDeadline;

  @override
  void initState() {
    super.initState();
    _progressAnimCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _progressAnim =
        Tween<double>(begin: 0, end: 0).animate(CurvedAnimation(
            parent: _progressAnimCtrl, curve: Curves.easeOut));
    _confettiCtrl =
        ConfettiController(duration: const Duration(seconds: 4));

    _txSub = _service
        .goalTxStream(widget.pairId, widget.goal.id)
        .listen(_onTxUpdate);
  }

  void _onTxUpdate(List<JointTransaction> txs) async {
    if (!mounted) return;
    setState(() {
      _transactions = txs;
      _loaded = true;
    });

    final saved = _currentSaved;
    final progress = (saved / widget.goal.targetAmount).clamp(0.0, 1.0);
    _progressAnim =
        Tween<double>(begin: _progressAnim.value, end: progress)
            .animate(CurvedAnimation(
                parent: _progressAnimCtrl, curve: Curves.easeOut));
    _progressAnimCtrl.forward(from: 0);

    // Auto-mark completed when both partners push it over the target
    final isNowCompleted = saved >= widget.goal.targetAmount;
    final wasAlreadyCompleted = widget.goal.completedAt != null;
    if (isNowCompleted && !wasAlreadyCompleted && !_wasCompleted) {
      _wasCompleted = true;
      await _service.markGoalCompleted(
          widget.pairId, widget.goal.id);
      if (mounted) _confettiCtrl.play();
    }
  }

  String get _motivationText {
    if (_progress >= 1.0) return '🎉 Goal achieved! Congratulations!';
    if (_progress >= 0.75)
      return '🔥 Almost there! ${(_progress * 100).toStringAsFixed(0)}% complete — keep pushing!';
    if (_progress >= 0.5)
      return '💪 Halfway there! Keep the momentum going.';
    if (_progress >= 0.25)
      return '🌱 Great start! You\'ve saved ₱${_fmt.format(_currentSaved)} so far.';
    return '🚀 Every peso counts. Add your first contribution!';
  }


  /// Shows fine-grained % for tiny progress (e.g. 0.001%) instead of rounding to 0%.
  String _formatSmallPercent(double fraction) {
    final pct = fraction * 100;
    if (pct == 0.0) return '0%';
    if (pct >= 100.0) return '100%';
    if (pct >= 1.0) return '${pct.toStringAsFixed(2)}%';
    if (pct >= 0.01) return '${pct.toStringAsFixed(2)}%';
    if (pct >= 0.001) return '${pct.toStringAsFixed(3)}%';
    return '<0.001%';
  }
  @override
  Widget build(BuildContext context) {
    final accent = Color(widget.goal.color);

    if (!_loaded) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Center(
            child: CircularProgressIndicator(color: BPTheme.income)),
      );
    }

    return Stack(
      children: [
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _confettiCtrl,
            blastDirectionality: BlastDirectionality.explosive,
            numberOfParticles: 30,
            gravity: 0.2,
            colors: [
              accent, BPTheme.accentAmber, Colors.white,
              const Color(0xFF059669), BPTheme.accentIndigo
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header banner ───────────────────────────────────────
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    accent.withOpacity(0.8),
                    accent.withOpacity(0.3)
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text(widget.goal.icon,
                        style: const TextStyle(fontSize: 32)),
                    const SizedBox(width: 8),
                    const Text('👫',
                        style: TextStyle(fontSize: 20)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.goal.name,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined,
                          color: Colors.white),
                      onPressed: widget.onEdit,
                    ),
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    const Icon(Icons.flag_outlined,
                        color: Colors.white70, size: 16),
                    const SizedBox(width: 6),
                    Text(
                        'Target: ₱${_fmt.format(widget.goal.targetAmount)}',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 14)),
                    const SizedBox(width: 16),
                    const Icon(Icons.calendar_today_outlined,
                        color: Colors.white70, size: 16),
                    const SizedBox(width: 6),
                    Text(
                        DateFormat('MMM d, y')
                            .format(widget.goal.deadline),
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 14)),
                  ]),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Circular progress ──────────────────────────────────
            _buildCircularProgress(accent),
            const SizedBox(height: 24),

            // ── Breakdown ─────────────────────────────────────────
            _buildBreakdownCard(accent),
            const SizedBox(height: 20),

            // ── Motivation ────────────────────────────────────────
            _buildMotivation(accent),
            const SizedBox(height: 20),
            // -- Contribute button (Joint Goals: deposit only, no withdraw) --
            BPGradientButton(
              label: 'Contribute',
              gradientColors: [accent, BPTheme.accentIndigo],
              height: 48,
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => JointDepositScreen(
                    pairId: widget.pairId,
                    targetId: widget.goal.id,
                    targetName: widget.goal.name,
                    txContext: JointTxContext.goal,
                    initialType: 'deposit',
                  ),
                ),
              ),
            ),
            // -- Recent contributions --
            if (_transactions.isNotEmpty) _buildRecentTx(accent),
            const SizedBox(height: 20),
            // ── Completion card ────────────────────────────────────
            _buildCompletionCard(accent),
            const SizedBox(height: 32),
          ],
        ),
      ],
    );
  }

  Widget _buildCircularProgress(Color accent) {
    return Center(
      child: AnimatedBuilder(
        animation: _progressAnim,
        builder: (context, _) {
          final pct = _progressAnim.value;
          return Column(children: [
            SizedBox(
              width: 160,
              height: 160,
              child: Stack(alignment: Alignment.center, children: [
                SizedBox(
                  width: 160,
                  height: 160,
                  child: CircularProgressIndicator(
                    value: pct,
                    strokeWidth: 14,
                    backgroundColor: BPTheme.divider,
                    valueColor: AlwaysStoppedAnimation<Color>(accent),
                    strokeCap: StrokeCap.round,
                  ),
                ),
                Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(
                    _formatSmallPercent(pct),
                    style: TextStyle(
                        color: BPTheme.textPrimary,
                        fontSize: 32,
                        fontWeight: FontWeight.bold),
                  ),
                  Text('saved',
                      style: TextStyle(
                          color: BPTheme.textSecondary, fontSize: 13)),
                ]),
              ]),
            ),
            const SizedBox(height: 16),
            RichText(
              text: TextSpan(children: [
                TextSpan(
                    text: '₱${_fmt.format(_currentSaved)}',
                    style: TextStyle(
                        color: accent,
                        fontSize: 20,
                        fontWeight: FontWeight.bold)),
                TextSpan(
                    text:
                        '  /  ₱${_fmt.format(widget.goal.targetAmount)}',
                    style: TextStyle(
                        color: BPTheme.textSecondary,
                        fontSize: 16)),
              ]),
            ),
          ]);
        },
      ),
    );
  }


  Widget _buildBreakdownCard(Color accent) {
    final daysLeft =
        widget.goal.deadline.difference(DateTime.now()).inDays;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BPTheme.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Progress Breakdown',
              style: TextStyle(
                  color: BPTheme.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _row('Remaining',
              '₱${_fmt.format(_remaining)}', Icons.arrow_downward,
              BPTheme.warning),
          _row('Monthly Target',
              '₱${_fmt.format(_monthlyRequired)}/mo',
              Icons.calendar_month, accent),
          _row('Days Left', '$daysLeft days', Icons.timer_outlined,
              daysLeft < 30 ? BPTheme.expense : BPTheme.income),
        ],
      ),
    );
  }

  Widget _row(String label, String value, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 14),
        Text(label,
            style: TextStyle(
                color: BPTheme.textSecondary, fontSize: 14)),
        const Spacer(),
        Text(value,
            style: TextStyle(
                color: BPTheme.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.bold)),
      ]),
    );
  }

  Widget _buildMotivation(Color accent) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          accent.withOpacity(0.15),
          accent.withOpacity(0.05)
        ]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withOpacity(0.3)),
      ),
      child: Row(children: [
        if (_progress >= 0.75)
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Icon(Icons.emoji_events,
                color: BPTheme.accentAmber, size: 28),
          ),
        Expanded(
          child: Text(_motivationText,
              style: TextStyle(
                  color: BPTheme.textPrimary, fontSize: 14, height: 1.5)),
        ),
      ]),
    );
  }

  Widget _buildRecentTx(Color accent) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BPTheme.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Contributions',
              style: TextStyle(
                  color: BPTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ..._transactions.map((tx) {
            final isDeposit = tx.type == 'deposit';
            final color = isDeposit ? BPTheme.income : BPTheme.expense;
            final sign = isDeposit ? '+' : '-';
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(children: [
                _MiniAvatar(
                    avatarBase64: tx.avatarBase64,
                    photoUrl: tx.photoUrl,
                    name: tx.displayName),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tx.displayName,
                          style: TextStyle(
                              color: BPTheme.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 13)),
                      if (tx.notes != null && tx.notes!.isNotEmpty)
                        Text(tx.notes!,
                            style: TextStyle(
                                color: BPTheme.textSecondary,
                                fontSize: 11),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      Text(
                        DateFormat('MMM d, y • h:mm a').format(tx.createdAt),
                        style: TextStyle(
                            color: BPTheme.textDisabled,
                            fontSize: 10),
                      ),
                    ],
                  ),
                ),
                Text('$sign₱${_fmt.format(tx.amount)}',
                    style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 14)),
                // Delete button
                Builder(builder: (ctx) => IconButton(
                  icon: Icon(Icons.delete_outline,
                      color: BPTheme.expense, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => _confirmDeleteGoalTx(ctx, tx),
                )),
              ]),
            );
          }),
        ],
      ),
    );
  }

  void _confirmDeleteGoalTx(BuildContext context, JointTransaction tx) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BPTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete this contribution?',
            style: TextStyle(color: BPTheme.textPrimary)),
        content: Text('This cannot be undone.',
            style: TextStyle(color: BPTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: BPTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete', style: TextStyle(color: BPTheme.expense)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _service.deleteGoalTransaction(
          pairId: widget.pairId, goalId: widget.goal.id, txId: tx.id);
      // Also delete the mirrored local transaction in SQLite
      await TransactionRepository().deleteByJointTx(
        firestoreTxId: tx.id,
        jointTargetId: widget.goal.id,
        potName: widget.goal.name,
        amount: tx.amount,
        categoryId: -2,
      );
    }
  }

  Widget _buildCompletionCard(Color accent) {
    final isCompleted = widget.goal.completedAt != null;
    if (!isCompleted) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BPTheme.cardDecoration,
        child: Row(children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
                color: BPTheme.surfaceEl, shape: BoxShape.circle),
            child: Icon(Icons.emoji_events_outlined,
                color: BPTheme.textSecondary, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Keep going!',
                      style: TextStyle(
                          color: BPTheme.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('Together you can reach 100% 🎊',
                      style: TextStyle(
                          color: BPTheme.textSecondary, fontSize: 13)),
                ]),
          ),
        ]),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFD97706), Color(0xFFF59E0B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(children: [
        const Icon(Icons.emoji_events, color: Colors.white, size: 48),
        const SizedBox(height: 12),
        const Text('Joint Goal Completed! 🎉',
            style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Text(
          'Completed on ${DateFormat('MMM d, y').format(widget.goal.completedAt!)}',
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        const SizedBox(height: 4),
        Text(
          'Total saved: ₱${_fmt.format(_currentSaved)}',
          style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold),
        ),
      ]),
    );
  }

  @override
  void dispose() {
    _txSub?.cancel();
    _progressAnimCtrl.dispose();
    _confettiCtrl.dispose();
    super.dispose();
  }
}

// ─────────────────────────────────────────────
// GOAL DETAIL INLINE  (solo goals — UNCHANGED)
// ─────────────────────────────────────────────

class _GoalDetailInline extends StatefulWidget {
  final SavingsGoal goal;
  final VoidCallback onGoalChanged;
  final VoidCallback onEdit;

  const _GoalDetailInline({
    super.key,
    required this.goal,
    required this.onGoalChanged,
    required this.onEdit,
  });

  @override
  State<_GoalDetailInline> createState() => _GoalDetailInlineState();
}

class _GoalDetailInlineState extends State<_GoalDetailInline>
    with TickerProviderStateMixin {
  final _goalRepo = SavingsGoalRepository();
  final _transactionRepo = TransactionRepository();

  late SavingsGoal _goal;
  double _currentSaved = 0.0;
  List<Map<String, dynamic>> _chartData = [];
  bool _chartWeekly = true;
  bool _isLoading = true;
  bool _wasCompleted = false;

  late AnimationController _progressAnimCtrl;
  late Animation<double> _progressAnim;
  late ConfettiController _confettiCtrl;

  final _fmt = NumberFormat('#,##0.00');

  @override
  void initState() {
    super.initState();
    _goal = widget.goal;
    _progressAnimCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _progressAnim =
        Tween<double>(begin: 0, end: 0).animate(CurvedAnimation(
            parent: _progressAnimCtrl, curve: Curves.easeOut));
    _confettiCtrl =
        ConfettiController(duration: const Duration(seconds: 4));
    _loadData();
  }

  @override
  void didUpdateWidget(_GoalDetailInline oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.goal.id != widget.goal.id) {
      _goal = widget.goal;
      _wasCompleted = false;
      _loadData();
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final saved =
        await _transactionRepo.getSumByGoal(_goal.id!);
    final chart = _chartWeekly
        ? await _transactionRepo.getWeeklyHistoryByGoal(_goal.id!)
        : await _transactionRepo.getMonthlyHistoryByGoal(_goal.id!);

    final progress =
        (saved / _goal.targetAmount).clamp(0.0, 1.0);
    _progressAnim =
        Tween<double>(begin: _progressAnim.value, end: progress)
            .animate(CurvedAnimation(
                parent: _progressAnimCtrl, curve: Curves.easeOut));
    _progressAnimCtrl.forward(from: 0);

    final isNowCompleted = saved >= _goal.targetAmount;
    final wasAlreadyCompleted = _goal.completedAt != null;

    if (isNowCompleted && !wasAlreadyCompleted && !_wasCompleted) {
      final updated = _goal.copyWith(completedAt: DateTime.now());
      await _goalRepo.update(updated);
      _goal = (await _goalRepo.getById(_goal.id!)) ?? updated;
      _confettiCtrl.play();
      _wasCompleted = true;
      widget.onGoalChanged();
    }

    setState(() {
      _currentSaved = saved;
      _chartData = chart;
      _isLoading = false;
    });
  }

  double get _progress =>
      (_currentSaved / _goal.targetAmount).clamp(0.0, 1.0);
  double get _remaining =>
      (_goal.targetAmount - _currentSaved).clamp(0.0, double.infinity);

  int get _monthsUntilDeadline {
    final now = DateTime.now();
    return (((_goal.deadline.year - now.year) * 12) +
            (_goal.deadline.month - now.month))
        .clamp(1, 9999);
  }

  double get _monthlyRequired => _remaining / _monthsUntilDeadline;

  String get _motivationText {
    if (_progress >= 1.0) return '🎉 Goal achieved! Congratulations!';
    if (_progress >= 0.75)
      return '🔥 Almost there! ${(_progress * 100).toStringAsFixed(0)}% complete — push through!';
    if (_progress >= 0.5)
      return '💪 Halfway there! Keep the momentum going.';
    if (_progress >= 0.25)
      return '🌱 Great start! You\'ve saved ₱${_fmt.format(_currentSaved)} so far.';
    return '🚀 Every journey starts with the first step. Add your first contribution!';
  }


  /// Shows fine-grained % for tiny progress (e.g. 0.001%) instead of rounding to 0%.
  String _formatSmallPercent(double fraction) {
    final pct = fraction * 100;
    if (pct == 0.0) return '0%';
    if (pct >= 100.0) return '100%';
    if (pct >= 1.0) return '${pct.toStringAsFixed(2)}%';
    if (pct >= 0.01) return '${pct.toStringAsFixed(2)}%';
    if (pct >= 0.001) return '${pct.toStringAsFixed(3)}%';
    return '<0.001%';
  }
  @override
  Widget build(BuildContext context) {
    final accent = Color(_goal.color);

    return Stack(
      children: [
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _confettiCtrl,
            blastDirectionality: BlastDirectionality.explosive,
            numberOfParticles: 30,
            gravity: 0.2,
            colors: [
              accent, BPTheme.accentAmber, Colors.white,
              const Color(0xFF059669), BPTheme.accentIndigo
            ],
          ),
        ),
        if (_isLoading)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 60),
            child: Center(
                child: CircularProgressIndicator(color: BPTheme.income)),
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      accent.withOpacity(0.8),
                      accent.withOpacity(0.3)
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Text(_goal.icon,
                          style: const TextStyle(fontSize: 32)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _goal.name,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined,
                            color: Colors.white),
                        onPressed: widget.onEdit,
                        tooltip: 'Edit goal',
                      ),
                    ]),
                    const SizedBox(height: 8),
                    Row(children: [
                      const Icon(Icons.flag_outlined,
                          color: Colors.white70, size: 16),
                      const SizedBox(width: 6),
                      Text(
                          'Target: ₱${_fmt.format(_goal.targetAmount)}',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 14)),
                      const SizedBox(width: 16),
                      const Icon(Icons.calendar_today_outlined,
                          color: Colors.white70, size: 16),
                      const SizedBox(width: 6),
                      Text(
                          DateFormat('MMM d, y')
                              .format(_goal.deadline),
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 14)),
                    ]),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _buildCircularProgress(accent),
              const SizedBox(height: 24),
              _buildBreakdownCard(accent),
              const SizedBox(height: 20),
              _buildMotivationCard(accent),
              const SizedBox(height: 20),
              if (_chartData.isNotEmpty) ...[
                _buildChartCard(accent),
                const SizedBox(height: 20),
              ],
              _buildCompletionCard(accent),
              const SizedBox(height: 32),
            ],
          ),
      ],
    );
  }

  Widget _buildCircularProgress(Color accent) {
    return Center(
      child: AnimatedBuilder(
        animation: _progressAnim,
        builder: (context, _) {
          final pct = _progressAnim.value;
          return Column(
            children: [
              SizedBox(
                width: 160,
                height: 160,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (pct >= 0.95)
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.5, end: 1.0),
                        duration: const Duration(seconds: 1),
                        builder: (_, v, __) => Container(
                          width: 160,
                          height: 160,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                  color: accent.withOpacity(0.4 * v),
                                  blurRadius: 30,
                                  spreadRadius: 5)
                            ],
                          ),
                        ),
                      ),
                    SizedBox(
                      width: 160,
                      height: 160,
                      child: CircularProgressIndicator(
                        value: pct,
                        strokeWidth: 14,
                        backgroundColor: BPTheme.divider,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(accent),
                        strokeCap: StrokeCap.round,
                      ),
                    ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _formatSmallPercent(pct),
                          style: TextStyle(
                              color: BPTheme.textPrimary,
                              fontSize: 32,
                              fontWeight: FontWeight.bold),
                        ),
                        Text('saved',
                            style: TextStyle(
                                color: BPTheme.textSecondary,
                                fontSize: 13)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              RichText(
                text: TextSpan(children: [
                  TextSpan(
                      text: '₱${_fmt.format(_currentSaved)}',
                      style: TextStyle(
                          color: accent,
                          fontSize: 20,
                          fontWeight: FontWeight.bold)),
                  TextSpan(
                      text:
                          '  /  ₱${_fmt.format(_goal.targetAmount)}',
                      style: TextStyle(
                          color: BPTheme.textSecondary,
                          fontSize: 16)),
                ]),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBreakdownCard(Color accent) {
    final daysLeft =
        _goal.deadline.difference(DateTime.now()).inDays;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BPTheme.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Progress Breakdown',
              style: TextStyle(
                  color: BPTheme.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _breakdownRow('Remaining',
              '₱${_fmt.format(_remaining)}', Icons.arrow_downward,
              BPTheme.warning),
          _breakdownRow('Monthly Target',
              '₱${_fmt.format(_monthlyRequired)}/mo',
              Icons.calendar_month, accent),
          _breakdownRow(
              'Days Left',
              '$daysLeft days',
              Icons.timer_outlined,
              daysLeft < 30 ? BPTheme.expense : BPTheme.income),
        ],
      ),
    );
  }

  Widget _breakdownRow(
      String label, String value, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 14),
        Text(label,
            style: TextStyle(
                color: BPTheme.textSecondary, fontSize: 14)),
        const Spacer(),
        Text(value,
            style: TextStyle(
                color: BPTheme.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.bold)),
      ]),
    );
  }

  Widget _buildMotivationCard(Color accent) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          accent.withOpacity(0.15),
          accent.withOpacity(0.05)
        ]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withOpacity(0.3)),
      ),
      child: Row(children: [
        if (_progress >= 0.75)
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Icon(Icons.emoji_events,
                color: BPTheme.accentAmber, size: 28),
          ),
        Expanded(
          child: Text(_motivationText,
              style: TextStyle(
                  color: BPTheme.textPrimary,
                  fontSize: 14,
                  height: 1.5)),
        ),
      ]),
    );
  }

  Widget _buildChartCard(Color accent) {
    final maxVal = _chartData
        .map((d) => d['cumulative'] as double)
        .reduce(math.max);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BPTheme.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text('Savings Activity',
                style: TextStyle(
                    color: BPTheme.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.bold)),
            const Spacer(),
            _chartToggleChip('Weekly', _chartWeekly, accent, () async {
              setState(() => _chartWeekly = true);
              await _loadData();
            }),
            const SizedBox(width: 8),
            _chartToggleChip('Monthly', !_chartWeekly, accent,
                () async {
              setState(() => _chartWeekly = false);
              await _loadData();
            }),
          ]),
          const SizedBox(height: 20),
          SizedBox(
            height: 160,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: (_chartData.length - 1).toDouble(),
                minY: 0,
                maxY: maxVal * 1.2,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (v) =>
                      FlLine(color: BPTheme.divider, strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      interval: math
                          .max(1,
                              (_chartData.length / 4).floor())
                          .toDouble(),
                      getTitlesWidget: (v, _) {
                        final i = v.toInt();
                        if (i >= 0 && i < _chartData.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(_chartData[i]['label'],
                                style: TextStyle(
                                    color: BPTheme.textSecondary,
                                    fontSize: 10)),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 46,
                      getTitlesWidget: (v, _) => v == 0
                          ? const SizedBox.shrink()
                          : Text(
                              '₱${(v / 1000).toStringAsFixed(0)}k',
                              style: TextStyle(
                                  color: BPTheme.textSecondary,
                                  fontSize: 9)),
                    ),
                  ),
                ),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => BPTheme.surfaceEl,
                    getTooltipItems: (spots) => spots
                        .map((s) => LineTooltipItem(
                              '₱${_fmt.format(s.y)}',
                              TextStyle(
                                  color: BPTheme.textPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12),
                            ))
                        .toList(),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: _chartData
                        .asMap()
                        .entries
                        .map((e) => FlSpot(e.key.toDouble(),
                            e.value['cumulative'] as double))
                        .toList(),
                    isCurved: true,
                    color: accent,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      getDotPainter: (_, __, ___, ____) =>
                          FlDotCirclePainter(
                              radius: 4,
                              color: Colors.white,
                              strokeWidth: 2,
                              strokeColor: accent),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          accent.withOpacity(0.3),
                          accent.withOpacity(0.02)
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                  LineChartBarData(
                    spots: [
                      FlSpot(0, _goal.targetAmount),
                      FlSpot(
                          (_chartData.length - 1).toDouble(),
                          _goal.targetAmount),
                    ],
                    isCurved: false,
                    color: BPTheme.accentAmber.withOpacity(0.5),
                    barWidth: 1,
                    dashArray: [6, 4],
                    dotData: const FlDotData(show: false),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chartToggleChip(
      String label, bool selected, Color accent, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: selected
              ? accent.withOpacity(0.2)
              : BPTheme.surfaceEl,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? accent : BPTheme.divider),
        ),
        child: Text(label,
            style: TextStyle(
                color: selected ? accent : BPTheme.textSecondary,
                fontSize: 12,
                fontWeight: selected
                    ? FontWeight.bold
                    : FontWeight.normal)),
      ),
    );
  }

  Widget _buildCompletionCard(Color accent) {
    final isCompleted = _goal.completedAt != null;

    if (!isCompleted) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BPTheme.cardDecoration,
        child: Row(children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
                color: BPTheme.surfaceEl, shape: BoxShape.circle),
            child: Icon(Icons.emoji_events_outlined,
                color: BPTheme.textSecondary, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Keep going!',
                      style: TextStyle(
                          color: BPTheme.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(
                      'Reach 100% to unlock the celebration 🎊',
                      style: TextStyle(
                          color: BPTheme.textSecondary,
                          fontSize: 13)),
                ]),
          ),
        ]),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFD97706), Color(0xFFF59E0B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const Icon(Icons.emoji_events,
              color: Colors.white, size: 48),
          const SizedBox(height: 12),
          const Text('Goal Completed! 🎉',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(
            'Completed on ${DateFormat('MMM d, y').format(_goal.completedAt!)}',
            style: const TextStyle(
                color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            'Total saved: ₱${_fmt.format(_currentSaved)}',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFFD97706),
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: widget.onGoalChanged,
            child: const Text('Start New Goal',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _progressAnimCtrl.dispose();
    _confettiCtrl.dispose();
    super.dispose();
  }
}
