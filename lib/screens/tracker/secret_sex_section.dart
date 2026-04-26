// lib/screens/tracker/secret_sex_section.dart

import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'symptom_database_helper.dart';

class SecretSexScreen extends StatefulWidget {
  final List<String> selectedSexOptions;
  final ValueChanged<List<String>> onOptionsChanged;
  final DateTime currentDate;

  const SecretSexScreen({
    super.key,
    required this.selectedSexOptions,
    required this.onOptionsChanged,
    required this.currentDate,
  });

  @override
  State<SecretSexScreen> createState() => _SecretSexScreenState();
}

class _SecretSexScreenState extends State<SecretSexScreen>
    with SingleTickerProviderStateMixin {
  static const Color backgroundSoft = Color(0xFFFFDBE9);
  static const Color vibrantAccent = Color(0xFFE91E63);
  static const Color deepRed = Color(0xFFC2185B);
  static const Color hotPink = Color(0xFFF50057);
  static const Color surfaceWhite = Colors.white;
  static const Color textPrimary = Color(0xFF212121);

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  int _tapCount = 0;
  DateTime? _lastTapTime;

  // Map: date (stripped) → has intimate activity
  final Map<DateTime, bool> _intimateDates = {};

  final List<String> _options = [
    'Didn\'t have sex',
    'Protected sex',
    'Unprotected sex',
    'Oral sex',
    'Anal sex',
    'Masturbation',
    'Sensual touch',
    'Sex toys',
    'Orgasm',
    'High sex drive',
    'Neutral sex drive',
    'Low sex drive',
  ];

  @override
  void initState() {
    super.initState();

    // Pulsing heartbeat animation
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.3).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _loadAllIntimateDates();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  /// Load all saved logs and mark dates with intimate activity
  Future<void> _loadAllIntimateDates() async {
    final List<Map<String, dynamic>> allLogs =
    await SymptomDatabaseHelper.instance.getAllLogs(limit: 1000);

    Map<DateTime, bool> dates = {};

    for (var log in allLogs) {
      final String? dateStr = log['date'] as String?;
      if (dateStr == null) continue;

      final DateTime date = DateTime.parse(dateStr);
      final DateTime strippedDate = DateTime(date.year, date.month, date.day);

      final dynamic sexField = log['sex'];
      List<String> sexList = [];

      if (sexField is List<String>) {
        sexList = sexField;
      } else if (sexField is String && sexField.isNotEmpty) {
        sexList = sexField.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      }

      // Has intimate activity if:
      // - List is not empty
      // - AND it's not ONLY "Didn't have sex"
      bool hasIntimate = sexList.isNotEmpty &&
          !(sexList.length == 1 && sexList.contains("Didn\'t have sex"));

      if (hasIntimate) {
        dates[strippedDate] = true;
      }
    }

    if (mounted) {
      setState(() {
        _intimateDates.clear();
        _intimateDates.addAll(dates);
      });
    }
  }

  void _handleTap() {
    final now = DateTime.now();
    if (_lastTapTime == null ||
        now.difference(_lastTapTime!) > const Duration(seconds: 2)) {
      _tapCount = 1;
    } else {
      _tapCount++;
    }
    _lastTapTime = now;

    if (_tapCount >= 5) {
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      behavior: HitTestBehavior.translucent,
      child: Scaffold(
        backgroundColor: backgroundSoft,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          automaticallyImplyLeading: false,
          title: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.favorite, color: vibrantAccent, size: 28),
              SizedBox(width: 12),
              Text(
                'Sex and Sex Drive',
                style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 21),
              ),
              SizedBox(width: 10),
              Text('🔥🔒', style: TextStyle(fontSize: 20)),
            ],
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
            child: Column(
              children: [
                Card(
                  elevation: 14,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      gradient: LinearGradient(
                        colors: [vibrantAccent.withOpacity(0.2), deepRed.withOpacity(0.3)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      border: Border.all(color: hotPink.withOpacity(0.6), width: 2),
                    ),
                    child: TableCalendar(
                      firstDay: DateTime(2020),
                      lastDay: DateTime.now().add(const Duration(days: 365)),
                      focusedDay: widget.currentDate,
                      selectedDayPredicate: (day) => isSameDay(day, widget.currentDate),
                      calendarFormat: CalendarFormat.month,
                      startingDayOfWeek: StartingDayOfWeek.monday,
                      headerStyle: const HeaderStyle(
                        titleCentered: true,
                        formatButtonVisible: false,
                        titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textPrimary),
                      ),
                      calendarStyle: CalendarStyle(
                        todayDecoration: BoxDecoration(
                          color: vibrantAccent.withOpacity(0.4),
                          shape: BoxShape.circle,
                        ),
                        selectedDecoration: const BoxDecoration(color: hotPink, shape: BoxShape.circle),
                      ),
                      calendarBuilders: CalendarBuilders(
                        markerBuilder: (context, day, events) {
                          final DateTime strippedDay = DateTime(day.year, day.month, day.day);
                          if (_intimateDates.containsKey(strippedDay)) {
                            return Center(
                              child: AnimatedBuilder(
                                animation: _pulseAnimation,
                                builder: (context, child) {
                                  return Transform.scale(
                                    scale: _pulseAnimation.value,
                                    child: const Text('❤️', style: TextStyle(fontSize: 26)),
                                  );
                                },
                              ),
                            );
                          }
                          return null;
                        },
                        todayBuilder: (context, day, focusedDay) {
                          final DateTime strippedDay = DateTime(day.year, day.month, day.day);
                          if (_intimateDates.containsKey(strippedDay)) {
                            return Center(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: hotPink.withOpacity(0.35),
                                  shape: BoxShape.circle,
                                ),
                                width: 40,
                                height: 40,
                                alignment: Alignment.center,
                                child: Text(
                                  '${day.day}',
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                              ),
                            );
                          }
                          return null;
                        },
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: _options.map((option) {
                    bool isSelected = widget.selectedSexOptions.contains(option);

                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      child: FilterChip(
                        label: Text(
                          option,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: isSelected ? Colors.white : textPrimary,
                          ),
                        ),
                        selected: isSelected,
                        selectedColor: vibrantAccent,
                        backgroundColor: surfaceWhite,
                        elevation: isSelected ? 12 : 4,
                        shadowColor: hotPink.withOpacity(0.5),
                        pressElevation: 18,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(32),
                          side: BorderSide(
                            color: isSelected ? hotPink : Colors.grey.shade300,
                            width: 2,
                          ),
                        ),
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              widget.selectedSexOptions.add(option);
                            } else {
                              widget.selectedSexOptions.remove(option);
                            }
                            widget.onOptionsChanged(widget.selectedSexOptions);
                          });
                        },
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      ),
    );
  }
}