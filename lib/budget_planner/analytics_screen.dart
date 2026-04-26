import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'budget_planner_theme.dart';
import 'budget_service.dart';
import 'category.dart';
import 'category_repository.dart';
import 'transaction_repository.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final BudgetService _budgetService = BudgetService();
  final CategoryRepository _categoryRepo = CategoryRepository();
  final TransactionRepository _transactionRepo = TransactionRepository();

  String _selectedPeriod = 'monthly';
  DateTime _currentDate = DateTime.now();

  Map<String, DateTime>? _periodDates;
  Map<int, double> _categorySpending = {};
  Map<int, Category> _categories = {};
  double _totalSpending = 0.0;
  bool _isLoading = true;

  List<Map<String, dynamic>> _trendData = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      _periodDates = _budgetService.calculatePeriodDates(
          _selectedPeriod,
          focusedDate: _currentDate);
      final startDate = _periodDates!['startDate']!;
      final endDate = _periodDates!['endDate']!;

      final spending =
          await _budgetService.getSpendingByCategory(startDate, endDate);
      final categories = await _categoryRepo.getAll();

      final categoryMap = <int, Category>{};
      for (var category in categories) {
        categoryMap[category.id!] = category;
      }

      final total =
          spending.values.fold(0.0, (sum, value) => sum + value);

      await _loadTrendData(startDate, endDate);

      setState(() {
        _categorySpending = spending;
        _categories = categoryMap;
        _totalSpending = total;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          BPTheme.snackError('Error loading data: $e'),
        );
      }
    }
  }

  Future<void> _loadTrendData(
      DateTime startDate, DateTime endDate) async {
    final trendData = <Map<String, dynamic>>[];

    if (_selectedPeriod == 'monthly') {
      final daysInMonth = endDate.day;
      for (int day = 1; day <= daysInMonth; day++) {
        final dayStart =
            DateTime(startDate.year, startDate.month, day);
        final dayEnd = DateTime(
            startDate.year, startDate.month, day, 23, 59, 59);
        final transactions =
            await _transactionRepo.getByDateRange(dayStart, dayEnd);
        final daySpending = transactions
            .where((t) => t.type == 'expense')
            .fold(0.0, (sum, t) => sum + t.amount);
        trendData.add({'label': day.toString(), 'value': daySpending, 'date': dayStart});
      }
    } else if (_selectedPeriod == 'weekly') {
      for (int day = 0; day < 7; day++) {
        final dayDate = startDate.add(Duration(days: day));
        final dayEnd = DateTime(
            dayDate.year, dayDate.month, dayDate.day, 23, 59, 59);
        final transactions =
            await _transactionRepo.getByDateRange(dayDate, dayEnd);
        final daySpending = transactions
            .where((t) => t.type == 'expense')
            .fold(0.0, (sum, t) => sum + t.amount);
        trendData.add({
          'label': DateFormat('EEE').format(dayDate).substring(0, 3),
          'value': daySpending,
          'date': dayDate,
        });
      }
    } else if (_selectedPeriod == 'yearly') {
      for (int month = 1; month <= 12; month++) {
        final monthStart = DateTime(startDate.year, month, 1);
        final monthEnd =
            DateTime(startDate.year, month + 1, 0, 23, 59, 59);
        final transactions =
            await _transactionRepo.getByDateRange(monthStart, monthEnd);
        final monthSpending = transactions
            .where((t) => t.type == 'expense')
            .fold(0.0, (sum, t) => sum + t.amount);
        trendData.add({
          'label': DateFormat('MMM').format(monthStart),
          'value': monthSpending,
          'date': monthStart,
        });
      }
    }

    setState(() => _trendData = trendData);
  }

  void _changePeriod() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: BPTheme.surface,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Select Period',
            style: TextStyle(
                color: BPTheme.textPrimary,
                fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ['weekly', 'monthly', 'yearly'].map((p) {
            return ListTile(
              title: Text(
                p[0].toUpperCase() + p.substring(1),
                style: TextStyle(color: BPTheme.textPrimary),
              ),
              leading: Radio<String>(
                value: p,
                groupValue: _selectedPeriod,
                activeColor: BPTheme.accentIndigo,
                onChanged: (value) {
                  setState(() => _selectedPeriod = value!);
                  Navigator.pop(context);
                  _loadData();
                },
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  void _navigatePeriod(bool forward) {
    setState(() {
      if (_selectedPeriod == 'weekly') {
        _currentDate = forward
            ? _currentDate.add(const Duration(days: 7))
            : _currentDate.subtract(const Duration(days: 7));
      } else if (_selectedPeriod == 'monthly') {
        _currentDate = forward
            ? DateTime(_currentDate.year, _currentDate.month + 1, 1)
            : DateTime(_currentDate.year, _currentDate.month - 1, 1);
      } else if (_selectedPeriod == 'yearly') {
        _currentDate = forward
            ? DateTime(_currentDate.year + 1, 1, 1)
            : DateTime(_currentDate.year - 1, 1, 1);
      }
    });
    _loadData();
  }

  String _getPeriodLabel() {
    if (_periodDates == null) return '';
    final startDate = _periodDates!['startDate']!;
    final endDate = _periodDates!['endDate']!;

    if (_selectedPeriod == 'weekly') {
      return '${DateFormat('MMM d').format(startDate)} - ${DateFormat('MMM d, y').format(endDate)}';
    } else if (_selectedPeriod == 'yearly') {
      return DateFormat('yyyy').format(startDate);
    } else {
      return DateFormat('MMMM yyyy').format(startDate);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(
          child:
              CircularProgressIndicator(color: BPTheme.accentIndigo));
    }

    final sortedSpending = _categorySpending.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return RefreshIndicator(
      onRefresh: _loadData,
      color: BPTheme.accentIndigo,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Period Selector
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: BPTheme.surfaceEl,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: BPTheme.divider),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: Icon(Icons.chevron_left,
                        color: BPTheme.accentIndigo),
                    onPressed: () => _navigatePeriod(false),
                  ),
                  InkWell(
                    onTap: _changePeriod,
                    borderRadius: BorderRadius.circular(12),
                    child: Column(
                      children: [
                        Text(
                          _getPeriodLabel(),
                          style: TextStyle(
                            color: BPTheme.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          _selectedPeriod.toUpperCase(),
                          style: TextStyle(
                            color: BPTheme.accent,
                            fontSize: 11,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.chevron_right,
                        color: BPTheme.accentIndigo),
                    onPressed: () => _navigatePeriod(true),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Total Spending Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: BPTheme.gradientAnalytics,
                ),
                borderRadius: BorderRadius.circular(20),
                border:
                    Border.all(color: Colors.white.withOpacity(0.15)),
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Icon(
                      Icons.analytics_rounded,
                      size: 60,
                      color: Colors.white.withOpacity(0.15),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total Spending',
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.85),
                            fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      RichText(
                        text: const TextSpan(
                          children: [],
                        ),
                      ),
                      Text(
                        '₱${_totalSpending.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Spending Trend Chart
            if (_trendData.isNotEmpty) ...[
              Text(
                'Spending Trend',
                style: TextStyle(
                  color: BPTheme.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BPTheme.cardDecoration,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedPeriod == 'yearly'
                          ? 'Monthly Spending'
                          : 'Daily Spending',
                      style: TextStyle(
                          color: BPTheme.textSecondary, fontSize: 14),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 250,
                      child: _buildTrendChart(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Category Breakdown
            Text(
              'Spending by Category',
              style: TextStyle(
                color: BPTheme.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            if (sortedSpending.isEmpty)
              Container(
                padding: const EdgeInsets.all(40),
                decoration: BPTheme.cardDecoration,
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.analytics_rounded,
                          size: 60,
                          color:
                              BPTheme.accentIndigo.withOpacity(0.3)),
                      const SizedBox(height: 16),
                      Text(
                        'No spending data for this period',
                        style: TextStyle(
                            color: BPTheme.textSecondary, fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            else
              ...sortedSpending.map((entry) {
                final category = _categories[entry.key];
                if (category == null) return const SizedBox.shrink();

                final amount = entry.value;
                final percentage = _totalSpending > 0
                    ? (amount / _totalSpending * 100)
                    : 0.0;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(20),
                  decoration: BPTheme.cardDecoration,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: Color(category.color)
                                  .withOpacity(0.2),
                              borderRadius:
                                  BorderRadius.circular(14),
                            ),
                            child: Center(
                              child: Text(category.icon,
                                  style: const TextStyle(
                                      fontSize: 24)),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  category.name,
                                  style: TextStyle(
                                    color: BPTheme.textPrimary,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${percentage.toStringAsFixed(1)}% of total',
                                  style: TextStyle(
                                      color: BPTheme.textSecondary,
                                      fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '₱${amount.toStringAsFixed(2)}',
                            style: TextStyle(
                              color: BPTheme.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: percentage / 100,
                          minHeight: 10,
                          backgroundColor: BPTheme.divider,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Color(category.color),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendChart() {
    if (_trendData.isEmpty) {
      return Center(
        child: Text(
          'No data available',
          style: TextStyle(color: BPTheme.textSecondary),
        ),
      );
    }

    final maxValue = _trendData
        .map((d) => d['value'] as double)
        .reduce((a, b) => a > b ? a : b);
    final hasSpending = maxValue > 0;
    final chartMaxY = hasSpending ? maxValue * 1.3 : 100.0;

    final dataPoints = _trendData.length;
    final minWidth = MediaQuery.of(context).size.width - 72;
    final calculatedWidth = dataPoints * 40.0;
    final chartWidth =
        calculatedWidth > minWidth ? calculatedWidth : minWidth;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: chartWidth,
        height: 250,
        child: Padding(
          padding: const EdgeInsets.only(right: 16, top: 10),
          child: LineChart(
            LineChartData(
              minX: 0,
              maxX: (dataPoints - 1).toDouble(),
              minY: 0,
              maxY: chartMaxY,
              lineTouchData: LineTouchData(
                enabled: true,
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (touchedSpot) => BPTheme.surfaceEl,
                  tooltipBorder:
                      BorderSide(color: BPTheme.divider),
                  tooltipPadding: const EdgeInsets.all(8),
                  tooltipMargin: 8,
                  getTooltipItems:
                      (List<LineBarSpot> touchedSpots) {
                    return touchedSpots.map((spot) {
                      final value = spot.y;
                      final index = spot.x.toInt();
                      if (index < _trendData.length) {
                        final label = _trendData[index]['label'];
                        return LineTooltipItem(
                          '$label\n₱${value.toStringAsFixed(2)}',
                          TextStyle(
                            color: BPTheme.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        );
                      }
                      return null;
                    }).toList();
                  },
                ),
                handleBuiltInTouches: true,
                getTouchedSpotIndicator:
                    (LineChartBarData barData,
                        List<int> spotIndexes) {
                  return spotIndexes.map((index) {
                    return TouchedSpotIndicatorData(
                      FlLine(
                        color: BPTheme.accentIndigo.withOpacity(0.5),
                        strokeWidth: 2,
                        dashArray: [5, 5],
                      ),
                      FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData,
                                index) =>
                            FlDotCirclePainter(
                          radius: 6,
                          color: Colors.white,
                          strokeWidth: 3,
                          strokeColor: BPTheme.accentIndigo,
                        ),
                      ),
                    );
                  }).toList();
                },
              ),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval:
                    hasSpending ? chartMaxY / 5 : 20,
                getDrawingHorizontalLine: (value) =>
                    FlLine(color: BPTheme.divider, strokeWidth: 1),
              ),
              titlesData: FlTitlesData(
                show: true,
                rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 32,
                    interval: 1,
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index >= 0 &&
                          index < _trendData.length) {
                        final showEvery =
                            _selectedPeriod == 'monthly' ? 3 : 1;
                        if (index % showEvery == 0 ||
                            index == _trendData.length - 1) {
                          return Padding(
                            padding:
                                const EdgeInsets.only(top: 8.0),
                            child: Text(
                              _trendData[index]['label'],
                              style: TextStyle(
                                color: BPTheme.textSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          );
                        }
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: hasSpending ? chartMaxY / 5 : 20,
                    reservedSize: 45,
                    getTitlesWidget: (value, meta) {
                      if (value == 0)
                        return const SizedBox.shrink();
                      return Text(
                        '₱${value.toInt()}',
                        style: TextStyle(
                            color: BPTheme.textSecondary,
                            fontSize: 10),
                      );
                    },
                  ),
                ),
              ),
              borderData: FlBorderData(
                show: true,
                border: Border(
                  bottom:
                      BorderSide(color: BPTheme.divider, width: 1),
                  left:
                      BorderSide(color: BPTheme.divider, width: 1),
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: _trendData.asMap().entries.map((entry) {
                    return FlSpot(entry.key.toDouble(),
                        entry.value['value'] as double);
                  }).toList(),
                  isCurved: true,
                  curveSmoothness: 0.35,
                  color: BPTheme.accentIndigo,
                  barWidth: 3,
                  isStrokeCapRound: true,
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (spot, percent, barData,
                            index) =>
                        FlDotCirclePainter(
                      radius: 4,
                      color: Colors.white,
                      strokeWidth: 2,
                      strokeColor: BPTheme.accentIndigo,
                    ),
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      colors: [
                        BPTheme.accentIndigo.withOpacity(0.3),
                        BPTheme.accentIndigo.withOpacity(0.05),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
