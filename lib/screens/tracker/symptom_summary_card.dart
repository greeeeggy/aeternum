// lib/screens/tracker/symptom_summary_card.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'symptom_database_helper.dart';
import 'secret_sex_section.dart'; // for hidden gesture

class SymptomSummaryCard extends StatefulWidget {
  const SymptomSummaryCard({super.key});

  @override
  State<SymptomSummaryCard> createState() => _SymptomSummaryCardState();
}

class _SymptomSummaryCardState extends State<SymptomSummaryCard> {
  DateTime selectedDate = DateTime.now();
  Map<String, dynamic> logData = {};

  bool _isLoading = true;

  // 5-tap gesture
  int _tapCount = 0;
  DateTime? _lastTapTime;

  // ── Lighter neutral/masculine palette (no yellow, no pink, light & clean) ──
  static const Color backgroundSoft = Color(0xFFF5F7FA);     // very light cool gray-blue
  static const Color vibrantAccent = Color(0xFF0B7285);      // deep teal/blue – calm, trustworthy, masculine
  static const Color accentGlow   = Color(0xFF20C997);       // soft teal glow (subtle highlight)
  static const Color surfaceWhite = Colors.white;            // clean white surfaces
  static const Color textPrimary  = Color(0xFF1F2A44);       // dark charcoal text

  static const Color borderColor  = Color(0xFFDDE4ED);       // light muted border
  static const Color greyText     = Color(0xFF6B7280);       // neutral gray for placeholders / secondary

  @override
  void initState() {
    super.initState();
    _loadLogForDate();
  }

  Future<void> _loadLogForDate() async {
    setState(() => _isLoading = true);

    String dateStr = DateFormat('yyyy-MM-dd').format(selectedDate);
    Map<String, dynamic>? existingLog = await SymptomDatabaseHelper.instance.getLogForDate(dateStr);

    if (existingLog != null) {
      logData = Map.from(existingLog);
      logData['stress_level'] = (existingLog['stress_level'] ?? 3.0).toDouble();
      logData['sex'] ??= <String>[];
    } else {
      logData = {
        'moods': <String>[],
        'symptoms': <String>[],
        'flow': <String>[],
        'discharge': <String>[],
        'digestion': <String>[],
        'other': <String>[],
        'basal_temperature': null,
        'stress_level': 3.0,
        'physical_activity': 'Not logged',
        'pregnancy_test': 'Not logged',
        'ovulation_test': 'Not logged',
        'oral_contraceptives': 'Not logged',
        'weight': null,
        'notes': '',
        'sex': <String>[],
      };
    }

    setState(() => _isLoading = false);
  }

  void _handleScreenTap() {
    final now = DateTime.now();
    if (_lastTapTime == null || now.difference(_lastTapTime!) > const Duration(seconds: 2)) {
      _tapCount = 1;
    } else {
      _tapCount++;
    }
    _lastTapTime = now;

    if (_tapCount >= 5) {
      _tapCount = 0;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SecretSexScreen(
            selectedSexOptions: logData['sex'] as List<String>,
            onOptionsChanged: (_) {}, // read-only
            currentDate: selectedDate,
          ),
        ),
      );
    }
  }

  void _goToPreviousDay() {
    setState(() {
      selectedDate = selectedDate.subtract(const Duration(days: 1));
    });
    _loadLogForDate();
  }

  void _goToNextDay() {
    setState(() {
      selectedDate = selectedDate.add(const Duration(days: 1));
    });
    _loadLogForDate();
  }

  Future<void> _selectDateFromCalendar() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: vibrantAccent,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != selectedDate) {
      setState(() => selectedDate = picked);
      _loadLogForDate();
    }
  }

  Widget _buildChipGroupDisplay(String title, List<dynamic> loggedItems, List<String> allOptions) {
    final loggedSet = Set<String>.from(loggedItems.map((e) => e.toString().trim()));

    return Padding(
      padding: const EdgeInsets.only(left: 20, right: 20, top: 32, bottom: 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: allOptions.map((option) {
              final isLogged = loggedSet.contains(option);

              return AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                child: FilterChip(
                  label: Text(
                    option,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isLogged ? Colors.white : textPrimary,
                    ),
                  ),
                  selected: isLogged,
                  selectedColor: vibrantAccent,
                  backgroundColor: surfaceWhite,
                  elevation: isLogged ? 10 : 3,
                  shadowColor: vibrantAccent.withOpacity(0.4),
                  pressElevation: 16,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                    side: BorderSide(
                      color: isLogged ? vibrantAccent : borderColor,
                      width: 1.5,
                    ),
                  ),
                  onSelected: (_) {}, // read-only
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildReadOnlyField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: textPrimary)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: surfaceWhite,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: borderColor),
            ),
            width: double.infinity,
            child: Text(
              value,
              style: const TextStyle(fontSize: 16, color: textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: backgroundSoft,
        body: Center(child: CircularProgressIndicator(color: vibrantAccent)),
      );
    }

    return GestureDetector(
      onTap: _handleScreenTap,
      behavior: HitTestBehavior.translucent,
      child: Scaffold(
        backgroundColor: backgroundSoft,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text(
            "Girlfriend's Daily Log",
            style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),

                // Date Navigation Card
                Center(
                  child: Card(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    elevation: 8,
                    shadowColor: vibrantAccent.withOpacity(0.3),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(36)),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 28),
                      decoration: BoxDecoration(
                        color: surfaceWhite,
                        borderRadius: BorderRadius.circular(36),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          GestureDetector(
                            onTap: _goToPreviousDay,
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: vibrantAccent.withOpacity(0.12),
                              ),
                              child: Icon(Icons.arrow_back_ios_new_rounded, color: vibrantAccent, size: 26),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: _selectDateFromCalendar,
                              child: Column(
                                children: [
                                  AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 300),
                                    transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
                                    child: Text(
                                      DateFormat('EEEE, MMM d').format(selectedDate),
                                      key: ValueKey(selectedDate),
                                      style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold, color: textPrimary),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  const Text('🗓️', style: TextStyle(fontSize: 38)),
                                ],
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: _goToNextDay,
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: vibrantAccent.withOpacity(0.12),
                              ),
                              child: Icon(Icons.arrow_forward_ios_rounded, color: vibrantAccent, size: 26),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // Mood
                _buildChipGroupDisplay(
                  'Mood',
                  logData['moods'] as List<dynamic>,
                  [
                    'Calm', 'Happy', 'Energetic', 'Frisky', 'Mood swings',
                    'Irritated', 'Sad', 'Anxious', 'Depressed', 'Feeling guilty',
                    'Obsessive thoughts', 'Low energy', 'Apathetic', 'Confused',
                    'Very self-critical'
                  ],
                ),
                const SizedBox(height: 24),

                // Symptoms / Feelings
                _buildChipGroupDisplay(
                  'Symptoms / Feelings',
                  logData['symptoms'] as List<dynamic>,
                  [
                    'Everything is fine', 'Cramps', 'Tender breasts', 'Headache',
                    'Acne', 'Backache', 'Fatigue', 'Cravings', 'Insomnia',
                    'Abdominal pain', 'Vaginal itching', 'Vaginal dryness', 'Bloating'
                  ],
                ),
                const SizedBox(height: 24),

                // Menstrual Flow
                _buildChipGroupDisplay(
                  'Menstrual Flow',
                  logData['flow'] as List<dynamic>,
                  ['Light', 'Medium', 'Heavy', 'Blood Clots'],
                ),
                const SizedBox(height: 24),

                // Vaginal Discharge
                _buildChipGroupDisplay(
                  'Vaginal Discharge',
                  logData['discharge'] as List<dynamic>,
                  ['No discharge', 'Creamy', 'Watery', 'Sticky', 'Egg white', 'Spotting', 'Unusual', 'Clumpy white', 'Gray'],
                ),
                const SizedBox(height: 24),

                // Digestion and Stool
                _buildChipGroupDisplay(
                  'Digestion and Stool',
                  logData['digestion'] as List<dynamic>,
                  ['Nausea', 'Bloating', 'Constipation', 'Diarrhea'],
                ),
                const SizedBox(height: 24),

                // Other
                _buildChipGroupDisplay(
                  'Other',
                  logData['other'] as List<dynamic>,
                  [
                    'Travel', 'Meditation', 'Journaling', 'Kegel exercises',
                    'Breathing exercises', 'Disease or injury', 'Alcohol', 'Stress'
                  ],
                ),

                const SizedBox(height: 40),

                // Basal Temperature
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Basal Temperature (°C)', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textPrimary)),
                      const SizedBox(height: 16),
                      Card(
                        elevation: 6,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            gradient: LinearGradient(
                              colors: [
                                surfaceWhite,
                                (logData['basal_temperature'] as num? ?? 0) > 36.8
                                    ? accentGlow.withOpacity(0.25)
                                    : vibrantAccent.withOpacity(0.12),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            (logData['basal_temperature'] as num?)?.toStringAsFixed(1) ?? 'Not logged',
                            style: const TextStyle(fontSize: 18, color: textPrimary),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                // Stress Level
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Stress Level', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textPrimary)),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: surfaceWhite,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: borderColor),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.sentiment_very_satisfied, color: Colors.orange, size: 20),
                            const SizedBox(width: 12),
                            Text(
                              "${(logData['stress_level'] as num? ?? 3.0).toStringAsFixed(1)} / 5.0",
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: textPrimary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                // Physical Activity, etc.
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      _buildReadOnlyField('Physical Activity', logData['physical_activity'] as String? ?? 'Not logged'),
                      const SizedBox(height: 16),
                      _buildReadOnlyField('Pregnancy Test', logData['pregnancy_test'] as String? ?? 'Not logged'),
                      const SizedBox(height: 16),
                      _buildReadOnlyField('Ovulation Test', logData['ovulation_test'] as String? ?? 'Not logged'),
                      const SizedBox(height: 16),
                      _buildReadOnlyField('Oral Contraceptives', logData['oral_contraceptives'] as String? ?? 'Not logged'),
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                // Weight
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Weight (kg)', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textPrimary)),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: surfaceWhite,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: borderColor),
                        ),
                        width: double.infinity,
                        child: Text(
                          (logData['weight'] as num?)?.toStringAsFixed(1) ?? 'Not logged',
                          style: const TextStyle(fontSize: 18, color: textPrimary),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                // Notes – always full white box, even empty
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Note',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textPrimary),
                      ),
                      const SizedBox(height: 16),
                      ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 140),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: surfaceWhite,
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(color: borderColor),
                          ),
                          child: (logData['notes'] as String?)?.isNotEmpty == true
                              ? Text(
                            logData['notes'] as String,
                            style: TextStyle(
                              fontSize: 16,
                              height: 1.4,
                              color: textPrimary,
                            ),
                          )
                              : Center(
                            child: Text(
                              'No notes added by your partner',
                              style: TextStyle(
                                fontSize: 16,
                                height: 1.4,
                                color: greyText,
                                fontStyle: FontStyle.italic,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 120),
              ],
            ),
          ),
        ),
      ),
    );
  }
}