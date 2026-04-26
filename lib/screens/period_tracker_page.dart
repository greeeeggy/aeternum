// lib/screens/period_tracker_page.dart     ← new file or rename existing one

import 'package:flutter/material.dart';
import 'tracker/full_period_tracker_page.dart';

class PeriodTrackerPage extends StatelessWidget {
  const PeriodTrackerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const FullPeriodTrackerPage();
  }
}