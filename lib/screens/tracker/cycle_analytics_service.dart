// lib/screens/tracker/cycle_analytics_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:menstrual_cycle_widget/database_helper/menstrual_cycle_db_helper.dart';
import 'symptom_database_helper.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Data Models
// ─────────────────────────────────────────────────────────────────────────────

class CycleData {
  final int cycleNumber;
  final DateTime periodStart;
  final DateTime periodEnd;
  final DateTime cycleWindowEnd; // day before next period (or today)
  final int bleedingLength;
  final int? cycleLength; // null for current/last cycle if next hasn't started
  final int loggedDaysCount;
  final int totalCycleDays;

  // Symptom frequencies (count of logged days with that item)
  final Map<String, int> moodFrequency;
  final Map<String, int> physicalSymptomsFrequency;
  final Map<String, int> dischargeFrequency;
  final Map<String, int> digestionFrequency;
  final Map<String, int> otherTagFrequency;

  // Flow (only from bleeding days)
  final int heavyFlowDays;
  final int mediumFlowDays;
  final int lightFlowDays;
  final int bloodClotsDays;

  // Stress
  final double? avgStress;
  final double? maxStress;
  final int highStressDays; // stress > 3.5

  // Physical measurements (from logged days only)
  final double? minTemperature;
  final double? maxTemperature;
  final double? minWeight;
  final double? maxWeight;

  // Activity
  final Map<String, int> activityDistribution;

  // Tests / contraceptives
  final Map<String, int> pregnancyTestResults;
  final Map<String, int> ovulationTestResults;
  final Map<String, int> contraceptiveCompliance;

  // Notes count (we don't send content to AI)
  final int daysWithNotes;

  const CycleData({
    required this.cycleNumber,
    required this.periodStart,
    required this.periodEnd,
    required this.cycleWindowEnd,
    required this.bleedingLength,
    this.cycleLength,
    required this.loggedDaysCount,
    required this.totalCycleDays,
    required this.moodFrequency,
    required this.physicalSymptomsFrequency,
    required this.dischargeFrequency,
    required this.digestionFrequency,
    required this.otherTagFrequency,
    required this.heavyFlowDays,
    required this.mediumFlowDays,
    required this.lightFlowDays,
    required this.bloodClotsDays,
    this.avgStress,
    this.maxStress,
    required this.highStressDays,
    this.minTemperature,
    this.maxTemperature,
    this.minWeight,
    this.maxWeight,
    required this.activityDistribution,
    required this.pregnancyTestResults,
    required this.ovulationTestResults,
    required this.contraceptiveCompliance,
    required this.daysWithNotes,
  });
}

class GlobalCycleStats {
  final int totalCyclesTracked;
  final int totalDaysLogged;

  // Cycle length stats
  final double? avgCycleLength;
  final int? shortestCycle;
  final int? longestCycle;
  final double? cycleStdDev;

  // Bleeding stats
  final double? avgBleedingLength;
  final int? shortestBleeding;
  final int? longestBleeding;

  // Top symptoms / moods across all cycles
  final List<MapEntry<String, int>> topSymptoms;
  final List<MapEntry<String, int>> topMoods;

  // Stress
  final int highStressCycleCount;
  final double? overallAvgStress;

  const GlobalCycleStats({
    required this.totalCyclesTracked,
    required this.totalDaysLogged,
    this.avgCycleLength,
    this.shortestCycle,
    this.longestCycle,
    this.cycleStdDev,
    this.avgBleedingLength,
    this.shortestBleeding,
    this.longestBleeding,
    required this.topSymptoms,
    required this.topMoods,
    required this.highStressCycleCount,
    this.overallAvgStress,
  });
}

class CycleAnalytics {
  final List<CycleData> cycles;
  final GlobalCycleStats stats;
  final DateTime? currentCycleStart;
  final int? currentCycleDay;
  final String estimatedPhase;

  const CycleAnalytics({
    required this.cycles,
    required this.stats,
    this.currentCycleStart,
    this.currentCycleDay,
    required this.estimatedPhase,
  });

  bool get hasData => cycles.isNotEmpty;
}

// ─────────────────────────────────────────────────────────────────────────────
// Service
// ─────────────────────────────────────────────────────────────────────────────

class CycleAnalyticsService {
  static final CycleAnalyticsService _instance =
      CycleAnalyticsService._internal();
  factory CycleAnalyticsService() => _instance;
  CycleAnalyticsService._internal();

  String? get _userId => FirebaseAuth.instance.currentUser?.uid;

  // ── Public API ──────────────────────────────────────────────────────────────

  Future<CycleAnalytics> buildAnalytics() async {
    // 1. Get period date ranges (local widget DB primary, Firebase fallback)
    final List<_PeriodRange> ranges = await _getPeriodRanges();

    // 2. Get all symptom logs from SQLite
    final List<Map<String, dynamic>> allLogs =
        await SymptomDatabaseHelper.instance.getAllLogs(limit: 1000);

    // Convert logs to a date-keyed map for fast lookup
    final Map<String, Map<String, dynamic>> logsByDate = {};
    for (final log in allLogs) {
      final date = log['date'] as String?;
      if (date != null) logsByDate[date] = log;
    }

    if (ranges.isEmpty) {
      return CycleAnalytics(
        cycles: [],
        stats: GlobalCycleStats(
          totalCyclesTracked: 0,
          totalDaysLogged: allLogs.length,
          topSymptoms: [],
          topMoods: [],
          highStressCycleCount: 0,
        ),
        estimatedPhase: 'Unknown',
      );
    }

    // 3. Build per-cycle data
    final List<CycleData> cycles = [];
    for (int i = 0; i < ranges.length; i++) {
      final range = ranges[i];
      final DateTime cycleWindowEnd = i < ranges.length - 1
          ? ranges[i + 1].start.subtract(const Duration(days: 1))
          : DateTime.now();

      final int? cycleLength = i < ranges.length - 1
          ? ranges[i + 1].start.difference(range.start).inDays
          : null;

      final cycleData = _buildCycleData(
        cycleNumber: i + 1,
        range: range,
        cycleWindowEnd: cycleWindowEnd,
        cycleLength: cycleLength,
        logsByDate: logsByDate,
      );
      cycles.add(cycleData);
    }

    // 4. Compute global stats
    final GlobalCycleStats stats = _computeGlobalStats(cycles, allLogs.length);

    // 5. Current cycle info
    final DateTime? currentCycleStart =
        ranges.isNotEmpty ? ranges.last.start : null;
    final int? currentCycleDay = currentCycleStart != null
        ? DateTime.now().difference(currentCycleStart).inDays + 1
        : null;

    final String estimatedPhase = _estimatePhase(
      currentCycleDay,
      stats.avgCycleLength,
    );

    return CycleAnalytics(
      cycles: cycles,
      stats: stats,
      currentCycleStart: currentCycleStart,
      currentCycleDay: currentCycleDay,
      estimatedPhase: estimatedPhase,
    );
  }

  // ── Period Range Fetching ───────────────────────────────────────────────────

  Future<List<_PeriodRange>> _getPeriodRanges() async {
    // Primary: local widget DB
    try {
      final List<String> rawDates =
          await MenstrualCycleDbHelper.instance.getPastPeriodDates();
      if (rawDates.isNotEmpty) {
        return _datesToRanges(rawDates);
      }
    } catch (e) {
      print('⚠️ CycleAnalytics: local widget DB read failed: $e');
    }

    // Fallback: Firebase period_cycles collection
    return await _getPeriodRangesFromFirebase();
  }

  Future<List<_PeriodRange>> _getPeriodRangesFromFirebase() async {
    if (_userId == null) return [];
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(_userId)
          .collection('period_cycles')
          .orderBy('startDate')
          .get();

      final List<_PeriodRange> ranges = [];
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final startStr = data['startDate'] as String?;
        final endStr = data['endDate'] as String?;
        if (startStr == null || endStr == null) continue;
        final start = DateTime.tryParse(startStr);
        final end = DateTime.tryParse(endStr);
        if (start != null && end != null) {
          ranges.add(_PeriodRange(start: start, end: end));
        }
      }
      return ranges;
    } catch (e) {
      print('⚠️ CycleAnalytics: Firebase fallback failed: $e');
      return [];
    }
  }

  /// Converts a flat list of date strings into consecutive bleeding ranges
  List<_PeriodRange> _datesToRanges(List<String> dates) {
    if (dates.isEmpty) return [];

    dates.sort();
    final parsedDates = dates
        .map((d) => DateTime.tryParse(d))
        .whereType<DateTime>()
        .toList();

    final List<_PeriodRange> ranges = [];
    DateTime rangeStart = parsedDates[0];
    DateTime rangeEnd = parsedDates[0];

    for (int i = 1; i < parsedDates.length; i++) {
      final prev = parsedDates[i - 1];
      final curr = parsedDates[i];
      if (curr.difference(prev).inDays <= 1) {
        rangeEnd = curr;
      } else {
        ranges.add(_PeriodRange(start: rangeStart, end: rangeEnd));
        rangeStart = curr;
        rangeEnd = curr;
      }
    }
    ranges.add(_PeriodRange(start: rangeStart, end: rangeEnd));
    return ranges;
  }

  // ── Per-Cycle Builder ───────────────────────────────────────────────────────

  CycleData _buildCycleData({
    required int cycleNumber,
    required _PeriodRange range,
    required DateTime cycleWindowEnd,
    required int? cycleLength,
    required Map<String, Map<String, dynamic>> logsByDate,
  }) {
    // Collect all logs that fall within this cycle window
    final List<Map<String, dynamic>> cycleLogs = [];
    final List<Map<String, dynamic>> bleedingLogs = [];

    DateTime day = range.start;
    while (!day.isAfter(cycleWindowEnd)) {
      final dateStr =
          '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
      final log = logsByDate[dateStr];
      if (log != null) {
        cycleLogs.add(log);
        if (!day.isAfter(range.end)) {
          bleedingLogs.add(log);
        }
      }
      day = day.add(const Duration(days: 1));
    }

    final int totalCycleDays =
        cycleWindowEnd.difference(range.start).inDays + 1;
    final int bleedingLength = range.end.difference(range.start).inDays + 1;

    // ── Moods ──
    final Map<String, int> moodFreq = {};
    for (final log in cycleLogs) {
      final moods = _parseList(log['moods']);
      for (final m in moods) {
        moodFreq[m] = (moodFreq[m] ?? 0) + 1;
      }
    }

    // ── Physical Symptoms ──
    final Map<String, int> symptomFreq = {};
    for (final log in cycleLogs) {
      final symptoms = _parseList(log['symptoms']);
      for (final s in symptoms) {
        symptomFreq[s] = (symptomFreq[s] ?? 0) + 1;
      }
    }

    // ── Discharge ──
    final Map<String, int> dischargeFreq = {};
    for (final log in cycleLogs) {
      final discharge = _parseList(log['discharge']);
      for (final d in discharge) {
        dischargeFreq[d] = (dischargeFreq[d] ?? 0) + 1;
      }
    }

    // ── Digestion ──
    final Map<String, int> digestionFreq = {};
    for (final log in cycleLogs) {
      final digestion = _parseList(log['digestion']);
      for (final d in digestion) {
        digestionFreq[d] = (digestionFreq[d] ?? 0) + 1;
      }
    }

    // ── Other Tags ──
    final Map<String, int> otherFreq = {};
    for (final log in cycleLogs) {
      final other = _parseList(log['other']);
      for (final o in other) {
        otherFreq[o] = (otherFreq[o] ?? 0) + 1;
      }
    }

    // ── Flow (bleeding days only) ──
    int heavyDays = 0, mediumDays = 0, lightDays = 0, clotDays = 0;
    for (final log in bleedingLogs) {
      final flow = _parseList(log['flow']);
      if (flow.contains('Heavy')) heavyDays++;
      if (flow.contains('Medium')) mediumDays++;
      if (flow.contains('Light')) lightDays++;
      if (flow.contains('Blood Clots')) clotDays++;
    }

    // ── Stress ──
    final List<double> stressValues = [];
    for (final log in cycleLogs) {
      final s = _toDouble(log['stress_level']);
      if (s != null) stressValues.add(s);
    }
    final double? avgStress = stressValues.isNotEmpty
        ? stressValues.reduce((a, b) => a + b) / stressValues.length
        : null;
    final double? maxStress = stressValues.isNotEmpty
        ? stressValues.reduce((a, b) => a > b ? a : b)
        : null;
    final int highStressDays = stressValues.where((s) => s > 3.5).length;

    // ── Temperature ──
    final List<double> temps = [];
    for (final log in cycleLogs) {
      final t = _toDouble(log['basal_temperature']);
      if (t != null && t > 30 && t < 45) temps.add(t);
    }
    final double? minTemp =
        temps.isNotEmpty ? temps.reduce((a, b) => a < b ? a : b) : null;
    final double? maxTemp =
        temps.isNotEmpty ? temps.reduce((a, b) => a > b ? a : b) : null;

    // ── Weight ──
    final List<double> weights = [];
    for (final log in cycleLogs) {
      final w = _toDouble(log['weight']);
      if (w != null && w > 20 && w < 300) weights.add(w);
    }
    final double? minWeight =
        weights.isNotEmpty ? weights.reduce((a, b) => a < b ? a : b) : null;
    final double? maxWeight =
        weights.isNotEmpty ? weights.reduce((a, b) => a > b ? a : b) : null;

    // ── Activity ──
    final Map<String, int> activityDist = {};
    for (final log in cycleLogs) {
      final activity = log['physical_activity'] as String?;
      if (activity != null && activity.isNotEmpty) {
        activityDist[activity] = (activityDist[activity] ?? 0) + 1;
      }
    }

    // ── Tests / Contraceptives ──
    final Map<String, int> pregnancyResults = {};
    final Map<String, int> ovulationResults = {};
    final Map<String, int> contraceptiveMap = {};
    for (final log in cycleLogs) {
      final pt = log['pregnancy_test'] as String?;
      if (pt != null && pt != "Didn't take tests") {
        pregnancyResults[pt] = (pregnancyResults[pt] ?? 0) + 1;
      }
      final ot = log['ovulation_test'] as String?;
      if (ot != null && ot != "Didn't take tests") {
        ovulationResults[ot] = (ovulationResults[ot] ?? 0) + 1;
      }
      final oc = log['oral_contraceptives'] as String?;
      if (oc != null && oc != "Didn't take a contraceptive") {
        contraceptiveMap[oc] = (contraceptiveMap[oc] ?? 0) + 1;
      }
    }

    // ── Notes ──
    int daysWithNotes = 0;
    for (final log in cycleLogs) {
      final notes = log['notes'] as String?;
      if (notes != null && notes.trim().isNotEmpty) daysWithNotes++;
    }

    return CycleData(
      cycleNumber: cycleNumber,
      periodStart: range.start,
      periodEnd: range.end,
      cycleWindowEnd: cycleWindowEnd,
      bleedingLength: bleedingLength,
      cycleLength: cycleLength,
      loggedDaysCount: cycleLogs.length,
      totalCycleDays: totalCycleDays,
      moodFrequency: moodFreq,
      physicalSymptomsFrequency: symptomFreq,
      dischargeFrequency: dischargeFreq,
      digestionFrequency: digestionFreq,
      otherTagFrequency: otherFreq,
      heavyFlowDays: heavyDays,
      mediumFlowDays: mediumDays,
      lightFlowDays: lightDays,
      bloodClotsDays: clotDays,
      avgStress: avgStress,
      maxStress: maxStress,
      highStressDays: highStressDays,
      minTemperature: minTemp,
      maxTemperature: maxTemp,
      minWeight: minWeight,
      maxWeight: maxWeight,
      activityDistribution: activityDist,
      pregnancyTestResults: pregnancyResults,
      ovulationTestResults: ovulationResults,
      contraceptiveCompliance: contraceptiveMap,
      daysWithNotes: daysWithNotes,
    );
  }

  // ── Global Stats ────────────────────────────────────────────────────────────

  GlobalCycleStats _computeGlobalStats(
      List<CycleData> cycles, int totalDaysLogged) {
    if (cycles.isEmpty) {
      return GlobalCycleStats(
        totalCyclesTracked: 0,
        totalDaysLogged: totalDaysLogged,
        topSymptoms: [],
        topMoods: [],
        highStressCycleCount: 0,
      );
    }

    final completedCycles = cycles.where((c) => c.cycleLength != null).toList();
    final cycleLengths =
        completedCycles.map((c) => c.cycleLength!.toDouble()).toList();

    double? avgCycleLength;
    int? shortestCycle;
    int? longestCycle;
    double? cycleStdDev;

    if (cycleLengths.isNotEmpty) {
      avgCycleLength =
          cycleLengths.reduce((a, b) => a + b) / cycleLengths.length;
      shortestCycle = cycleLengths
          .map((l) => l.toInt())
          .reduce((a, b) => a < b ? a : b);
      longestCycle = cycleLengths
          .map((l) => l.toInt())
          .reduce((a, b) => a > b ? a : b);
      if (cycleLengths.length > 1) {
        final variance = cycleLengths
                .map((l) => (l - avgCycleLength!) * (l - avgCycleLength))
                .reduce((a, b) => a + b) /
            cycleLengths.length;
        cycleStdDev = _sqrt(variance);
      }
    }

    final bleedingLengths =
        cycles.map((c) => c.bleedingLength.toDouble()).toList();
    final double? avgBleeding = bleedingLengths.isNotEmpty
        ? bleedingLengths.reduce((a, b) => a + b) / bleedingLengths.length
        : null;
    final int? shortestBleeding = bleedingLengths.isNotEmpty
        ? bleedingLengths.map((l) => l.toInt()).reduce((a, b) => a < b ? a : b)
        : null;
    final int? longestBleeding = bleedingLengths.isNotEmpty
        ? bleedingLengths.map((l) => l.toInt()).reduce((a, b) => a > b ? a : b)
        : null;

    final Map<String, int> symptomCycleCounts = {};
    for (final cycle in cycles) {
      for (final symptom in cycle.physicalSymptomsFrequency.keys) {
        symptomCycleCounts[symptom] =
            (symptomCycleCounts[symptom] ?? 0) + 1;
      }
    }
    final topSymptoms = symptomCycleCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final Map<String, int> moodCycleCounts = {};
    for (final cycle in cycles) {
      for (final mood in cycle.moodFrequency.keys) {
        moodCycleCounts[mood] = (moodCycleCounts[mood] ?? 0) + 1;
      }
    }
    final topMoods = moodCycleCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final int highStressCycleCount =
        cycles.where((c) => c.highStressDays >= 3).length;

    final allStressValues = cycles
        .where((c) => c.avgStress != null)
        .map((c) => c.avgStress!)
        .toList();
    final double? overallAvgStress = allStressValues.isNotEmpty
        ? allStressValues.reduce((a, b) => a + b) / allStressValues.length
        : null;

    return GlobalCycleStats(
      totalCyclesTracked: cycles.length,
      totalDaysLogged: totalDaysLogged,
      avgCycleLength: avgCycleLength,
      shortestCycle: shortestCycle,
      longestCycle: longestCycle,
      cycleStdDev: cycleStdDev,
      avgBleedingLength: avgBleeding,
      shortestBleeding: shortestBleeding,
      longestBleeding: longestBleeding,
      topSymptoms: topSymptoms.take(8).toList(),
      topMoods: topMoods.take(8).toList(),
      highStressCycleCount: highStressCycleCount,
      overallAvgStress: overallAvgStress,
    );
  }

  // ── Personalized Cycle Length ───────────────────────────────────────────────

  /// Returns the best cycle length estimate to use for predictions and the
  /// phase arc view.
  ///
  /// Rules (Flo / Clue-style):
  ///   • < 3 completed cycles  →  fallback to 28 (not enough data yet)
  ///   • ≥ 3 completed cycles  →  linearly-weighted average of the most
  ///     recent 6 completed cycles (most recent = highest weight), clamped
  ///     to the physiologically safe range [21, 35].
  Future<int> computePersonalizedCycleLength() async {
    final List<_PeriodRange> ranges = await _getPeriodRanges();

    // Build completed cycle lengths (need at least two consecutive starts)
    final List<int> completedLengths = [];
    for (int i = 0; i < ranges.length - 1; i++) {
      final len = ranges[i + 1].start.difference(ranges[i].start).inDays;
      // Filter physiologically implausible values
      if (len >= 21 && len <= 45) {
        completedLengths.add(len);
      }
    }

    // Not enough data — use default
    if (completedLengths.length < 3) return 28;

    // Take last 6 completed cycles (most recent at the end of the list)
    final recent = completedLengths.length > 6
        ? completedLengths.sublist(completedLengths.length - 6)
        : completedLengths;

    // Linearly increasing weights: oldest = 1, ..., newest = n
    double weightedSum = 0;
    double totalWeight = 0;
    for (int i = 0; i < recent.length; i++) {
      final weight = (i + 1).toDouble();
      weightedSum += weight * recent[i];
      totalWeight += weight;
    }

    final computed = (weightedSum / totalWeight).round();
    return computed.clamp(21, 35);
  }

  // ── Phase Estimation ────────────────────────────────────────────────────────

  String _estimatePhase(int? currentDay, double? avgCycleLength) {
    if (currentDay == null) return 'Unknown';
    final int cycleLen = avgCycleLength?.round() ?? 28;

    if (currentDay <= 5) return 'Menstruation (Day $currentDay)';
    if (currentDay <= 10) return 'Follicular Phase (Day $currentDay)';
    final int ovulationDay = (cycleLen * 0.5).round();
    if (currentDay >= ovulationDay - 3 && currentDay <= ovulationDay + 3) {
      return 'Ovulatory Window (Day $currentDay)';
    }
    if (currentDay <= cycleLen) return 'Luteal Phase (Day $currentDay)';
    return 'Late / Possibly Late Cycle (Day $currentDay)';
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  List<String> _parseList(dynamic value) {
    if (value is List) {
      return value.map((e) => e.toString().trim()).toList();
    }
    if (value is String && value.isNotEmpty) {
      return value
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    return [];
  }

  double? _toDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  double _sqrt(double x) {
    if (x <= 0) return 0;
    double guess = x / 2;
    for (int i = 0; i < 20; i++) {
      guess = (guess + x / guess) / 2;
    }
    return guess;
  }
}

class _PeriodRange {
  final DateTime start;
  final DateTime end;
  _PeriodRange({required this.start, required this.end});
}
