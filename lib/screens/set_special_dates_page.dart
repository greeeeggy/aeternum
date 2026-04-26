import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SetSpecialDatesPage extends StatefulWidget {
  const SetSpecialDatesPage({super.key});

  @override
  State<SetSpecialDatesPage> createState() => _SetSpecialDatesPageState();
}

class _SetSpecialDatesPageState extends State<SetSpecialDatesPage> {
  DateTime? _anniversaryDate;
  DateTime? _monthsaryDate;
  final user = FirebaseAuth.instance.currentUser;
  bool _hoveredAnniv = false;
  bool _hoveredMonthsary = false;

  void _pickDate(String type) async {
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFE96D88),
              onPrimary: Colors.white,
              onSurface: Colors.black87,
              surface: Colors.white,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFE96D88),
                textStyle: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            dialogTheme: DialogThemeData(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
              backgroundColor: Colors.white,
            ),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFFCE4EC), Color(0xFFE8F5E8)],
                    ),
                  ),
                  child: Stack(
                    children: [
                      ...List.generate(20, (index) {
                        return Positioned(
                          left: (index % 5) * 80.0,
                          top: (index ~/ 5) * 60.0 + (index % 3) * 20.0,
                          child: Opacity(
                            opacity: 0.05 + (index % 4) * 0.1,
                            child: const Icon(
                              Icons.favorite,
                              size: 20,
                              color: Color(0xFFE96D88),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
              child!,
            ],
          ),
        );
      },
    );
    if (pickedDate != null) {
      setState(() {
        if (type == 'anniversary') _anniversaryDate = pickedDate;
        if (type == 'monthsary') _monthsaryDate = pickedDate;
      });
    }
  }

  Future<void> _saveDates() async {
    if (_anniversaryDate == null || _monthsaryDate == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select both dates 💕'),
            backgroundColor: Color(0xFFE96D88),
          ),
        );
      }
      return;
    }

    final localUser = user;
    if (localUser == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Auth session lost—relogin?')),
        );
      }
      return;
    }

    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(localUser.uid).get();
      final data = userDoc.data();
      final pairId = data?['pairId'] as String?;
      if (pairId == null) {
        throw Exception('No couple pair—complete role setup first.');
      }

      // NEW: Sync dates to couples + complete onboarding
      await FirebaseFirestore.instance.collection('couples').doc(pairId).set({
        'anniversaryDate': Timestamp.fromDate(_anniversaryDate!),
        'monthsaryDate': Timestamp.fromDate(_monthsaryDate!),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // In _saveDates(), replace the user set:
      await FirebaseFirestore.instance.collection('users').doc(localUser.uid).set({
        'datesSynced': true,  // Keep if useful (e.g., for Home UI)
      }, SetOptions(merge: true));

      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/home');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: const AssetImage('assets/images/romantic_bg.jpg'),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              Colors.white.withOpacity(0.4),
              BlendMode.dstATop,
            ),
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              AppBar(
                title: const Text(
                  "Set Your Special Dates 💕",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                backgroundColor: Colors.transparent,
                elevation: 0,
                iconTheme: const IconThemeData(color: Color(0xFFE96D88)),
                titleTextStyle: const TextStyle(
                  color: Color(0xFFE96D88),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.favorite,
                          size: 80,
                          color: Color(0xFFE96D88),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          "Choose your special days 💖",
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFE96D88),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 40),
                        MouseRegion(
                          onEnter: (_) => setState(() => _hoveredAnniv = true),
                          onExit: (_) => setState(() => _hoveredAnniv = false),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            transform: Matrix4.identity()..scale(_hoveredAnniv ? 1.02 : 1.0),
                            child: Card(
                              elevation: _hoveredAnniv ? 12 : 8,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                              color: _hoveredAnniv ? Colors.white : Colors.white.withOpacity(0.9),
                              child: ListTile(
                                leading: const Icon(Icons.cake, color: Color(0xFFE96D88), size: 30),
                                title: const Text("Anniversary Date", style: TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text(
                                  _anniversaryDate == null
                                      ? "Tap to pick your anniversary ❤️"
                                      : "Selected: ${_anniversaryDate!.toLocal().toString().split(' ')[0]}",
                                  style: TextStyle(color: Colors.grey[700]),
                                ),
                                trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Color(0xFFE96D88)),
                                onTap: () => _pickDate('anniversary'),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        MouseRegion(
                          onEnter: (_) => setState(() => _hoveredMonthsary = true),
                          onExit: (_) => setState(() => _hoveredMonthsary = false),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            transform: Matrix4.identity()..scale(_hoveredMonthsary ? 1.02 : 1.0),
                            child: Card(
                              elevation: _hoveredMonthsary ? 12 : 8,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                              color: _hoveredMonthsary ? Colors.white : Colors.white.withOpacity(0.9),
                              child: ListTile(
                                leading: const Icon(Icons.calendar_month, color: Color(0xFFE96D88), size: 30),
                                title: const Text("Monthsary Date", style: TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text(
                                  _monthsaryDate == null
                                      ? "Tap to pick your monthly celebration 💕"
                                      : "Selected: ${_monthsaryDate!.toLocal().toString().split(' ')[0]}",
                                  style: TextStyle(color: Colors.grey[700]),
                                ),
                                trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Color(0xFFE96D88)),
                                onTap: () => _pickDate('monthsary'),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 40),
                        ElevatedButton(
                          onPressed: _saveDates,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE96D88),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                            padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 14),
                            elevation: 8,
                            shadowColor: const Color(0x40E96D88),
                          ),
                          child: const Text(
                            "Save Special Dates & Continue 💞",
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}