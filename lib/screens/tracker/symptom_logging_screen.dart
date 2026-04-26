// lib/screens/tracker/symptom_logging_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_xlider/flutter_xlider.dart';
import 'symptom_database_helper.dart';
import 'symptom_firestore_service.dart'; // Remove if not using Firebase
import 'secret_sex_section.dart'; // Full-screen secret page
import 'symptom_sync_service.dart';  // ← ADD THIS LINE
import 'package:shared_preferences/shared_preferences.dart';
import 'eri_ai_service.dart';

class SymptomLoggingScreen extends StatefulWidget {
  const SymptomLoggingScreen({super.key});

  @override
  State<SymptomLoggingScreen> createState() => _SymptomLoggingScreenState();
}

class _SymptomLoggingScreenState extends State<SymptomLoggingScreen> {
  DateTime selectedDate = DateTime.now();

  Map<String, dynamic> logData = {
    'moods': <String>[],
    'symptoms': <String>[],
    'flow': <String>[],
    'discharge': <String>[],
    'digestion': <String>[],
    'other': <String>[],
    'basal_temperature': '',
    'stress_level': 3.0,
    'physical_activity': 'Didn\'t exercise',
    'pregnancy_test': 'Didn\'t take tests',
    'ovulation_test': 'Didn\'t take tests',
    'oral_contraceptives': 'Didn\'t take a contraceptive',
    'weight': '',
    'notes': '',
    'sex': <String>[],
  };

  final TextEditingController _tempController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  bool _isLoading = true;

  // For 5-tap gesture to open secret screen
  int _tapCount = 0;
  DateTime? _lastTapTime;

  // Colors
  static const Color backgroundSoft = Color(0xFFFFDBE9);
  static const Color vibrantAccent = Color(0xFFE91E63);
  static const Color accentGlow = Color(0xFFF06292);
  static const Color surfaceWhite = Colors.white;
  static const Color textPrimary = Color(0xFF212121);

  @override
  void initState() {
    super.initState();
    _loadLogForDate();
  }

  @override
  void dispose() {
    _tempController.dispose();
    _weightController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadLogForDate() async {
    setState(() => _isLoading = true);

    String dateStr = DateFormat('yyyy-MM-dd').format(selectedDate);
    Map<String, dynamic>? existingLog =
    await SymptomDatabaseHelper.instance.getLogForDate(dateStr);

    if (existingLog != null) {
      logData = existingLog;
      _tempController.text = existingLog['basal_temperature']?.toString() ?? '';
      _weightController.text = existingLog['weight']?.toString() ?? '';
      _notesController.text = existingLog['notes'] ?? '';
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
        'basal_temperature': '',
        'stress_level': 3.0,
        'physical_activity': 'Didn\'t exercise',
        'pregnancy_test': 'Didn\'t take tests',
        'ovulation_test': 'Didn\'t take tests',
        'oral_contraceptives': 'Didn\'t take a contraceptive',
        'weight': '',
        'notes': '',
        'sex': <String>[],
      };
      _tempController.clear();
      _weightController.clear();
      _notesController.clear();
    }

    setState(() => _isLoading = false);
  }

  Future<void> _saveLog() async {
    String dateStr = DateFormat('yyyy-MM-dd').format(selectedDate);
    logData['date'] = dateStr;
    logData['basal_temperature'] = double.tryParse(_tempController.text);
    logData['weight'] = double.tryParse(_weightController.text);
    logData['notes'] = _notesController.text;

    // Save to local DB
    await SymptomDatabaseHelper.instance.saveDailyLog(logData);

    // Mark this date as dirty (needs sync)
    final prefs = await SharedPreferences.getInstance();
    Set<String> dirtyDates = (prefs.getStringList('symptom_dirty_dates') ?? []).toSet();
    dirtyDates.add(dateStr);
    await prefs.setStringList('symptom_dirty_dates', dirtyDates.toList());

    // Trigger sync (will only push dirty dates)
    SymptomSyncService().onLocalLogChanged();

    // Invalidate Eri's cached context so next chat reflects new data
    EriAiService().invalidateContext();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Today’s feelings saved with care ❤️'),
        backgroundColor: vibrantAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      ),
    );
  }

  void _handleScreenTap() {
    final now = DateTime.now();
    if (_lastTapTime == null ||
        now.difference(_lastTapTime!) > const Duration(seconds: 2)) {
      _tapCount = 1;
    } else {
      _tapCount++;
    }
    _lastTapTime = now;

    if (_tapCount >= 5) {
      _tapCount = 0; // Reset to prevent repeated triggers
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SecretSexScreen(
            selectedSexOptions: logData['sex'] as List<String>,
            onOptionsChanged: (updatedList) {
              setState(() {
                logData['sex'] = updatedList;
              });
            },
            currentDate: selectedDate, // ← Add this line
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

  Widget _buildStableChipGroup(String title, List<String> options, String key) {
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
            children: options.map((option) {
              bool isSelected = (logData[key] as List<String>).contains(option);

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
                  elevation: isSelected ? 10 : 3,
                  shadowColor: vibrantAccent.withOpacity(0.4),
                  pressElevation: 16,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                    side: BorderSide(
                      color: isSelected ? vibrantAccent : Colors.grey.shade300,
                      width: 1.5,
                    ),
                  ),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        (logData[key] as List<String>).add(option);
                      } else {
                        (logData[key] as List<String>).remove(option);
                      }
                    });
                  },
                ),
              );
            }).toList(),
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

    return Scaffold(
      backgroundColor: backgroundSoft,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Your Daily Log', style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveLog,
            color: vibrantAccent,
          ),
        ],
      ),
      body: GestureDetector(
        onTap: _handleScreenTap,
        behavior: HitTestBehavior.translucent,
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 100),
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

                  _buildStableChipGroup('Mood', [
                    'Calm', 'Happy', 'Energetic', 'Frisky', 'Mood swings',
                    'Irritated', 'Sad', 'Anxious', 'Depressed', 'Feeling guilty',
                    'Obsessive thoughts', 'Low energy', 'Apathetic', 'Confused',
                    'Very self-critical'
                  ], 'moods'),

                  _buildStableChipGroup('Symptoms / Feelings', [
                    'Everything is fine', 'Cramps', 'Tender breasts', 'Headache',
                    'Acne', 'Backache', 'Fatigue', 'Cravings', 'Insomnia',
                    'Abdominal pain', 'Vaginal itching', 'Vaginal dryness', 'Bloating'
                  ], 'symptoms'),

                  _buildStableChipGroup('Menstrual Flow', [
                    'Light', 'Medium', 'Heavy', 'Blood Clots'
                  ], 'flow'),

                  _buildStableChipGroup('Vaginal Discharge', [
                    'No discharge', 'Creamy', 'Watery', 'Sticky', 'Egg white',
                    'Spotting', 'Unusual', 'Clumpy white', 'Gray'
                  ], 'discharge'),

                  _buildStableChipGroup('Digestion and Stool', [
                    'Nausea', 'Bloating', 'Constipation', 'Diarrhea'
                  ], 'digestion'),

                  _buildStableChipGroup('Other', [
                    'Travel', 'Meditation', 'Journaling', 'Kegel exercises',
                    'Breathing exercises', 'Disease or injury', 'Alcohol', 'Stress'
                  ], 'other'),

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
                                  double.tryParse(_tempController.text) != null && double.tryParse(_tempController.text)! > 36.8
                                      ? accentGlow.withOpacity(0.25)
                                      : vibrantAccent.withOpacity(0.12),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            padding: const EdgeInsets.all(24),
                            child: TextField(
                              controller: _tempController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                hintText: 'e.g. 36.7',
                                filled: true,
                                fillColor: surfaceWhite,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
                              ),
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
                        FlutterSlider(
                          values: [logData['stress_level'].toDouble()],
                          min: 0.0,
                          max: 5.0,
                          step: FlutterSliderStep(step: 0.1),
                          trackBar: FlutterSliderTrackBar(
                            activeTrackBarHeight: 10,
                            inactiveTrackBarHeight: 10,
                            activeTrackBar: BoxDecoration(color: vibrantAccent, borderRadius: BorderRadius.circular(5)),
                            inactiveTrackBar: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(5)),
                          ),
                          tooltip: FlutterSliderTooltip(
                            textStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            boxStyle: FlutterSliderTooltipBox(decoration: BoxDecoration(color: vibrantAccent, borderRadius: BorderRadius.circular(8))),
                            format: (value) => double.parse(value).toStringAsFixed(1),
                          ),
                          handler: FlutterSliderHandler(
                            decoration: BoxDecoration(
                              color: vibrantAccent,
                              shape: BoxShape.circle,
                              boxShadow: [BoxShadow(color: vibrantAccent.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 4))],
                            ),
                            child: const SizedBox(width: 36, height: 36),
                          ),
                          onDragging: (handlerIndex, lowerValue, upperValue) {
                            setState(() {
                              logData['stress_level'] = lowerValue;
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                        Center(
                          child: Text(
                            '${logData['stress_level'].toStringAsFixed(1)} / 5.0',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textPrimary),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Dropdowns, Weight, Notes — unchanged
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        DropdownButtonFormField<String>(
                          value: logData['physical_activity'],
                          decoration: InputDecoration(
                            labelText: 'Physical Activity',
                            filled: true,
                            fillColor: surfaceWhite,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                          items: [
                            'Didn\'t exercise', 'Yoga', 'Gym', 'Aerobics & dancing',
                            'Swimming', 'Team sports', 'Running', 'Cycling', 'Walking'
                          ].map((a) => DropdownMenuItem(value: a, child: Text(a))).toList(),
                          onChanged: (v) => setState(() => logData['physical_activity'] = v!),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: logData['pregnancy_test'],
                          decoration: InputDecoration(
                            labelText: 'Pregnancy Test',
                            filled: true,
                            fillColor: surfaceWhite,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                          items: ['Didn\'t take tests', 'Positive', 'Negative', 'Faint line']
                              .map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                          onChanged: (v) => setState(() => logData['pregnancy_test'] = v!),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: logData['ovulation_test'],
                          decoration: InputDecoration(
                            labelText: 'Ovulation Test',
                            filled: true,
                            fillColor: surfaceWhite,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                          items: ['Didn\'t take tests', 'Test: positive+', 'Test: negative', 'Ovulation: my method']
                              .map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                          onChanged: (v) => setState(() => logData['ovulation_test'] = v!),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: logData['oral_contraceptives'],
                          decoration: InputDecoration(
                            labelText: 'Oral Contraceptives',
                            filled: true,
                            fillColor: surfaceWhite,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                          items: [
                            'Didn\'t take a contraceptive',
                            'Taken on time',
                            'Yesterday\'s pill'
                          ].map((oc) => DropdownMenuItem(value: oc, child: Text(oc))).toList(),
                          onChanged: (v) => setState(() => logData['oral_contraceptives'] = v!),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: TextField(
                      controller: _weightController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Weight (optional)',
                        hintText: 'kg',
                        filled: true,
                        fillColor: surfaceWhite,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Note', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textPrimary)),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _notesController,
                          minLines: 5,
                          maxLines: null,
                          decoration: InputDecoration(
                            hintText: 'How are you feeling today? Share anything on your heart 💗',
                            filled: true,
                            fillColor: surfaceWhite,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(28),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.all(24),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 120),
                ],
              ),
            ),

            // Floating Save Button
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                child: SafeArea(
                  child: Container(
                    width: double.infinity,
                    height: 56,
                    decoration: BoxDecoration(
                      color: vibrantAccent.withOpacity(0.85),
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: vibrantAccent.withOpacity(0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: _saveLog,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                      ),
                      child: const Text(
                        'Save Today’s Feelings',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}