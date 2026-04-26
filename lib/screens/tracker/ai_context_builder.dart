// lib/screens/tracker/ai_context_builder.dart

import 'package:intl/intl.dart';
import 'cycle_analytics_service.dart';

class AiContextBuilder {
  static String build(CycleAnalytics analytics) {
    final buf = StringBuffer();
    final dateFormat = DateFormat('MMM d, yyyy');
    final today = DateTime.now();

    // ── Header ──────────────────────────────────────────────────────────────
    buf.writeln(
        '=== CYCLE HISTORY (${analytics.cycles.length} cycle(s) tracked) ===');
    buf.writeln();

    if (!analytics.hasData) {
      buf.writeln('No period cycle data has been logged yet.');
      buf.writeln(_dataQualityNote());
      return buf.toString();
    }

    // ── Per-Cycle Detail ────────────────────────────────────────────────────
    for (final cycle in analytics.cycles) {
      final isCurrentCycle =
          cycle == analytics.cycles.last && cycle.cycleLength == null;
      final cycleLabel = isCurrentCycle
          ? '[Current Cycle ${cycle.cycleNumber}]'
          : '[Cycle ${cycle.cycleNumber}]';

      final cycleLengthStr =
          cycle.cycleLength != null ? '${cycle.cycleLength} days' : 'ongoing';

      final sparseWarning =
          cycle.loggedDaysCount < (cycle.totalCycleDays * 0.3).round() &&
                  cycle.loggedDaysCount < 5
              ? ' ⚠ sparse data'
              : '';

      buf.writeln(
        '$cycleLabel  '
        '${dateFormat.format(cycle.periodStart)} – ${dateFormat.format(cycle.cycleWindowEnd)}  '
        '| cycle: $cycleLengthStr  '
        '| bleeding: ${cycle.bleedingLength} days  '
        '| logged: ${cycle.loggedDaysCount}/${cycle.totalCycleDays} days$sparseWarning',
      );

      if (cycle.moodFrequency.isNotEmpty) {
        final sorted = _sortedMap(cycle.moodFrequency);
        buf.writeln('  Moods: ${_formatFreqMap(sorted)}');
      }

      if (cycle.physicalSymptomsFrequency.isNotEmpty) {
        final sorted = _sortedMap(cycle.physicalSymptomsFrequency);
        buf.writeln('  Physical symptoms: ${_formatFreqMap(sorted)}');
      }

      final totalFlowDays = cycle.heavyFlowDays +
          cycle.mediumFlowDays +
          cycle.lightFlowDays +
          cycle.bloodClotsDays;
      if (totalFlowDays > 0) {
        final flowParts = <String>[];
        if (cycle.heavyFlowDays > 0) {
          flowParts.add('heavy ×${cycle.heavyFlowDays}');
        }
        if (cycle.mediumFlowDays > 0) {
          flowParts.add('medium ×${cycle.mediumFlowDays}');
        }
        if (cycle.lightFlowDays > 0) {
          flowParts.add('light ×${cycle.lightFlowDays}');
        }
        if (cycle.bloodClotsDays > 0) {
          flowParts.add('blood clots ×${cycle.bloodClotsDays}');
        }
        buf.writeln('  Flow: ${flowParts.join(', ')}');
      }

      if (cycle.dischargeFrequency.isNotEmpty) {
        final sorted = _sortedMap(cycle.dischargeFrequency);
        buf.writeln('  Discharge: ${_formatFreqMap(sorted)}');
      }

      if (cycle.digestionFrequency.isNotEmpty) {
        final sorted = _sortedMap(cycle.digestionFrequency);
        buf.writeln('  Digestion: ${_formatFreqMap(sorted)}');
      }

      if (cycle.otherTagFrequency.isNotEmpty) {
        final sorted = _sortedMap(cycle.otherTagFrequency);
        buf.writeln('  Other: ${_formatFreqMap(sorted)}');
      }

      if (cycle.avgStress != null) {
        buf.writeln(
          '  Stress: avg ${cycle.avgStress!.toStringAsFixed(1)}/5'
          ' | high-stress days (>3.5): ${cycle.highStressDays}'
          '${cycle.maxStress != null ? " | peak: ${cycle.maxStress!.toStringAsFixed(1)}" : ""}',
        );
      }

      if (cycle.minTemperature != null && cycle.maxTemperature != null) {
        buf.writeln(
          '  Basal temperature: ${cycle.minTemperature!.toStringAsFixed(1)}–'
          '${cycle.maxTemperature!.toStringAsFixed(1)} °C',
        );
      }

      if (cycle.minWeight != null && cycle.maxWeight != null) {
        final weightStr = cycle.minWeight == cycle.maxWeight
            ? '${cycle.minWeight!.toStringAsFixed(1)} kg'
            : '${cycle.minWeight!.toStringAsFixed(1)}–${cycle.maxWeight!.toStringAsFixed(1)} kg';
        buf.writeln('  Weight: $weightStr');
      }

      if (cycle.activityDistribution.isNotEmpty) {
        final sorted = _sortedMap(cycle.activityDistribution);
        buf.writeln('  Activity: ${_formatFreqMap(sorted)}');
      }

      if (cycle.contraceptiveCompliance.isNotEmpty) {
        final sorted = _sortedMap(cycle.contraceptiveCompliance);
        buf.writeln('  Contraceptive: ${_formatFreqMap(sorted)}');
      }

      if (cycle.ovulationTestResults.isNotEmpty) {
        final sorted = _sortedMap(cycle.ovulationTestResults);
        buf.writeln('  Ovulation tests: ${_formatFreqMap(sorted)}');
      }

      if (cycle.pregnancyTestResults.isNotEmpty) {
        final total =
            cycle.pregnancyTestResults.values.fold(0, (a, b) => a + b);
        buf.writeln('  Pregnancy tests logged: $total time(s)');
      }

      if (cycle.daysWithNotes > 0) {
        buf.writeln('  Personal notes on: ${cycle.daysWithNotes} day(s)');
      }

      buf.writeln();
    }

    // ── Global Statistics ───────────────────────────────────────────────────
    final s = analytics.stats;
    buf.writeln('=== COMPUTED STATISTICS ===');

    if (s.avgCycleLength != null) {
      buf.writeln(
        'Cycle length: avg ${s.avgCycleLength!.toStringAsFixed(1)} days'
        ' | range ${s.shortestCycle}–${s.longestCycle} days'
        '${s.cycleStdDev != null ? " | std dev ${s.cycleStdDev!.toStringAsFixed(2)}" : ""}'
        ' | ${s.totalCyclesTracked} cycle(s) tracked',
      );
    } else {
      buf.writeln(
          'Cycle length: only 1 cycle recorded — not enough data for averages yet');
    }

    if (s.avgBleedingLength != null) {
      buf.writeln(
        'Bleeding: avg ${s.avgBleedingLength!.toStringAsFixed(1)} days'
        ' | range ${s.shortestBleeding}–${s.longestBleeding} days',
      );
    }

    if (s.topSymptoms.isNotEmpty) {
      final symptomsStr = s.topSymptoms
          .map((e) => '${e.key} (${e.value}/${s.totalCyclesTracked} cycles)')
          .join(', ');
      buf.writeln('Most frequent symptoms across cycles: $symptomsStr');
    }

    if (s.topMoods.isNotEmpty) {
      final moodsStr = s.topMoods
          .map((e) => '${e.key} (${e.value}/${s.totalCyclesTracked} cycles)')
          .join(', ');
      buf.writeln('Most frequent moods across cycles: $moodsStr');
    }

    if (s.totalCyclesTracked > 0) {
      buf.writeln(
        'High-stress cycles (3+ high-stress days): '
        '${s.highStressCycleCount} out of ${s.totalCyclesTracked}',
      );
    }

    if (s.overallAvgStress != null) {
      buf.writeln(
          'Overall average stress level: ${s.overallAvgStress!.toStringAsFixed(1)}/5');
    }

    buf.writeln('Total days with any symptom log: ${s.totalDaysLogged}');
    buf.writeln();

    // ── Current Cycle ───────────────────────────────────────────────────────
    buf.writeln('=== CURRENT CYCLE ===');
    if (analytics.currentCycleStart != null) {
      buf.writeln(
        'Started: ${dateFormat.format(analytics.currentCycleStart!)}'
        ' | Today: ${dateFormat.format(today)}'
        '${analytics.currentCycleDay != null ? " | Day ${analytics.currentCycleDay} of cycle" : ""}',
      );
      buf.writeln('Estimated phase: ${analytics.estimatedPhase}');

      final currentCycle = analytics.cycles.last;
      if (currentCycle.loggedDaysCount > 0) {
        buf.writeln(
            'Logged ${currentCycle.loggedDaysCount} day(s) so far this cycle');
      } else {
        buf.writeln('No logs recorded yet this cycle');
      }
    } else {
      buf.writeln('No cycle data available yet');
    }

    buf.writeln();
    buf.writeln(_dataQualityNote());

    return buf.toString();
  }

  // ── Recent Logs Formatter ────────────────────────────────────────────────
  static String buildRecentLogsSnippet(List<Map<String, dynamic>> recentLogs) {
    if (recentLogs.isEmpty) return '';
    final buf = StringBuffer();
    buf.writeln(
        '=== RECENT SYMPTOM LOGS (last ${recentLogs.length} entries) ===');

    for (final log in recentLogs) {
      final date = log['date'] as String? ?? '?';
      final parts = <String>[];

      final moods = _parseListStatic(log['moods']);
      if (moods.isNotEmpty) parts.add('moods [${moods.join(', ')}]');

      final symptoms = _parseListStatic(log['symptoms']);
      if (symptoms.isNotEmpty) parts.add('symptoms [${symptoms.join(', ')}]');

      final flow = _parseListStatic(log['flow']);
      if (flow.isNotEmpty) parts.add('flow [${flow.join(', ')}]');

      final discharge = _parseListStatic(log['discharge']);
      if (discharge.isNotEmpty) {
        parts.add('discharge [${discharge.join(', ')}]');
      }

      final digestion = _parseListStatic(log['digestion']);
      if (digestion.isNotEmpty) {
        parts.add('digestion [${digestion.join(', ')}]');
      }

      final other = _parseListStatic(log['other']);
      if (other.isNotEmpty) parts.add('other [${other.join(', ')}]');

      final stress = log['stress_level'];
      if (stress != null) {
        final s = double.tryParse(stress.toString());
        if (s != null) parts.add('stress ${s.toStringAsFixed(1)}/5');
      }

      final activity = log['physical_activity'] as String?;
      if (activity != null && activity != "Didn't exercise") {
        parts.add('activity: $activity');
      }

      final temp = log['basal_temperature'];
      if (temp != null) {
        final t = double.tryParse(temp.toString());
        if (t != null) parts.add('temp ${t.toStringAsFixed(1)}°C');
      }

      buf.writeln(
          '  $date: ${parts.isEmpty ? "(no details)" : parts.join(" | ")}');
    }
    buf.writeln();
    return buf.toString();
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  static String _dataQualityNote() {
    return '=== DATA QUALITY NOTE ===\n'
        'This user logs symptoms selectively, not every day. '
        'Absence of a log on a given day does NOT mean the user was symptom-free. '
        'Frequencies reflect logged days only. '
        'Treat missing entries as unknown rather than negative. '
        'When a user claims they "always" or "never" experience something, '
        'consider incomplete logging before concluding from frequency counts alone.\n';
  }

  static List<MapEntry<String, int>> _sortedMap(Map<String, int> map) {
    final entries = map.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries;
  }

  static String _formatFreqMap(List<MapEntry<String, int>> entries) {
    return entries.map((e) => '${e.key} ×${e.value}').join(', ');
  }

  static List<String> _parseListStatic(dynamic value) {
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
}
