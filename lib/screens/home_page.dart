// lib/screens/home_page.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:menstrual_cycle_widget/menstrual_cycle_widget.dart';

import 'rotating_greeting.dart'; // ← Import the new widget
import 'tracker/boyfriend_period_viewer_page.dart';
import 'tracker/full_period_tracker_page.dart';
import 'settings_page.dart';
import '../class_schedule/class_schedule_database.dart';
import '../class_schedule/class_model.dart';
import '../class_schedule/class_scheduler.dart';
import '../budget_planner/budget_service.dart';
import '../budget_planner/budget_planner_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, this.onShowTracker});

  final VoidCallback? onShowTracker;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String? _role;
  String? _pairId;
  String? _partnerUid;

  List<String> _nicknames = [];

  // Special dates (anniversary & monthsary)
  DateTime? _anniversaryDate;
  DateTime? _monthsaryDate;
  bool _specialDatesLoaded = false;

  // Today's class schedule (split by ownerUid)
  List<ClassSchedule> _myTodayClasses = [];
  List<ClassSchedule> _partnerTodayClasses = [];
  Map<String, String> _groupDisplayNames = {}; // firestoreId -> displayName
  bool _todayClassesLoaded = false;

  // Budget snapshot (monthly)
  double _monthlyBalance = 0.0;
  double _monthlyExpenses = 0.0;
  bool _budgetLoaded = false;

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  static const String _secretKeyStorageKey = 'mc_widget_secret_key';
  static const String _ivKeyStorageKey = 'mc_widget_iv_key';

  @override
  void initState() {
    super.initState();
    _initMenstrualCycleWidgetSecurely();
    _loadTodayClasses();
    _loadBudgetSnapshot();
  }

  /// Initialize MenstrualCycleWidget with per-device secure keys
  Future<void> _initMenstrualCycleWidgetSecurely() async {
    String? secretKey = await _secureStorage.read(key: _secretKeyStorageKey);
    String? ivKey = await _secureStorage.read(key: _ivKeyStorageKey);

    if (secretKey == null || ivKey == null) {
      final key = encrypt.Key.fromSecureRandom(32);
      final iv = encrypt.IV.fromSecureRandom(16);

      secretKey = key.base64;
      ivKey = iv.base64;

      await _secureStorage.write(key: _secretKeyStorageKey, value: secretKey);
      await _secureStorage.write(key: _ivKeyStorageKey, value: ivKey);
    }

    MenstrualCycleWidget.init(secretKey: secretKey, ivKey: ivKey);
  }

  /// Load partner's nicknames (only nicknames — rotation happens in widget)
  Future<void> _loadPartnerNicknames() async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null || _pairId == null || _role == null) return;

    try {
      // Get the couple document to find partner's UID
      final coupleDoc = await FirebaseFirestore.instance
          .collection('couples')
          .doc(_pairId)
          .get();

      if (!coupleDoc.exists) return;

      final members = coupleDoc.data()?['members'] as List<dynamic>? ?? [];
      final partnerUid = members.firstWhere(
            (uid) => uid != currentUid,
        orElse: () => null,
      ) as String?;

      if (partnerUid == null) return;

      setState(() {
        _partnerUid = partnerUid;
      });

      // Fetch partner's nicknames
      final partnerDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(partnerUid)
          .get();

      if (!partnerDoc.exists) return;

      final partnerData = partnerDoc.data()!;
      final List<dynamic> rawNicknames = partnerData['nicknames'] ?? [];

      final cleanedNicknames = rawNicknames
          .map((e) => (e as String?)?.trim())
          .where((s) => s != null && s.isNotEmpty)
          .cast<String>()
          .toList();

      if (cleanedNicknames.isNotEmpty) {
        setState(() {
          _nicknames = cleanedNicknames;
        });
      }
    } catch (e) {
      debugPrint("Error loading partner nicknames: $e");
    }
  }

  // ────────────────────────────────────────────────────────────────
  // Home Feature Loaders
  // ────────────────────────────────────────────────────────────────

  Future<void> _loadSpecialDates(String pairId) async {
    try {
      final coupleDoc = await FirebaseFirestore.instance
          .collection('couples')
          .doc(pairId)
          .get();
      if (!coupleDoc.exists) return;
      final data = coupleDoc.data()!;
      final annivTs = data['anniversaryDate'] as Timestamp?;
      final monthsaryTs = data['monthsaryDate'] as Timestamp?;
      if (mounted) {
        setState(() {
          _anniversaryDate = annivTs?.toDate();
          _monthsaryDate = monthsaryTs?.toDate();
        });
      }
    } catch (e) {
      debugPrint('Error loading special dates: $e');
    }
  }

  Future<void> _loadTodayClasses() async {
    try {
      final myUid = FirebaseAuth.instance.currentUser?.uid ?? '';
      final db = ClassScheduleDatabase();

      // Build group display-name lookup
      final groups = await db.getAllGroups();
      final groupNames = <String, String>{
        for (final g in groups)
          if (g.firestoreId != null) g.firestoreId!: g.displayName,
      };

      // Flutter weekday: Mon=1…Sun=7 → app stores Sun=0, Mon=1…Sat=6
      final todayDow = DateTime.now().weekday % 7;
      final all = await db.getAllClasses();
      final todayAll = all
          .where((c) => c.dayOfWeek == todayDow)
          .toList()
        ..sort((a, b) => a.startMinutes.compareTo(b.startMinutes));

      final mine = todayAll.where((c) => c.ownerUid == myUid).toList();
      final partner = todayAll.where((c) => c.ownerUid != myUid && c.ownerUid != null && c.ownerUid!.isNotEmpty).toList();

      if (mounted) {
        setState(() {
          _myTodayClasses = mine;
          _partnerTodayClasses = partner;
          _groupDisplayNames = groupNames;
          _todayClassesLoaded = true;
        });
      }
    } catch (e) {
      debugPrint('Error loading today\'s classes: $e');
    }
  }

  Future<void> _loadBudgetSnapshot() async {
    try {
      final service = BudgetService();
      final now = DateTime.now();
      final dates = service.calculatePeriodDates('monthly', focusedDate: now);
      final start = dates['startDate']!;
      final end = dates['endDate']!;
      final balance = await service.getNetBalance(start, end);
      final expenses = await service.getTotalExpenses(start, end);
      if (mounted) {
        setState(() {
          _monthlyBalance = balance;
          _monthlyExpenses = expenses;
          _budgetLoaded = true;
        });
      }
    } catch (e) {
      debugPrint('Error loading budget snapshot: $e');
    }
  }

  /// Load girlfriend's cycle data (used by both roles)
  Future<Map<String, dynamic>> _loadGfCycleData(String pairId, String? gfUid) async {
    if (gfUid == null) return {'status': 'No partner found'};

    try {
      final cyclesSnap = await FirebaseFirestore.instance
          .collection('cycles')
          .doc('${pairId}_$gfUid')
          .get();

      final cyclesData = cyclesSnap.data() ?? {};
      final cycles = cyclesData['cycles'] as List<dynamic>? ?? [];

      if (cycles.isEmpty) return {'status': 'No data yet'};

      const avgCycle = 28;
      final lastStartTimestamp = cycles.last['startDate'] as Timestamp?;
      final lastStartDate = lastStartTimestamp?.toDate() ?? DateTime.now().subtract(const Duration(days: 28));

      final nextPeriod = lastStartDate.add(const Duration(days: avgCycle));
      final daysUntil = nextPeriod.difference(DateTime.now()).inDays.clamp(0, avgCycle);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        MenstrualCycleWidget.instance?.updateConfiguration(
          cycleLength: avgCycle,
          periodDuration: 5,
          lastPeriodDate: lastStartDate,
        );
      });

      return {
        'lastStartDate': lastStartDate,
        'nextPeriod': nextPeriod,
        'currentPhase': _computePhase(DateTime.now(), lastStartDate, avgCycle),
        'daysUntil': daysUntil,
        'cycleLen': avgCycle,
      };
    } catch (e) {
      return {'status': 'Error loading data'};
    }
  }

  String _computePhase(DateTime now, DateTime lastStart, int cycleLen) {
    final daysSince = now.difference(lastStart).inDays;
    if (daysSince < 5) return 'Menstrual';
    if (daysSince < 14) return 'Follicular';
    if (daysSince < 16) return 'Ovulation';
    if (daysSince < cycleLen) return 'Luteal';
    return 'Next Cycle Expected';
  }

  /// Navigate to full tracker page
  void _navigateToTracker() {
    if (_role == 'boyfriend') {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => const BoyfriendPeriodViewerPage(),
        ),
      );
    } else {
      // Always push a fresh FullPeriodTrackerPage so sync runs on mount
      // and all widgets render with up-to-date data immediately.
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => const FullPeriodTrackerPage(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBF8F8),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const SettingsPage(),
            ),
          );
          // or if using named routes:
          // Navigator.pushNamed(context, '/settings');
        },
        backgroundColor: Colors.white,
        foregroundColor: Colors.grey.shade800,
        elevation: 4,
        highlightElevation: 8,
        shape: const CircleBorder(),
        child: const Icon(Icons.settings_outlined, size: 28),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(FirebaseAuth.instance.currentUser?.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text("User data not found"));
          }

          final userData = snapshot.data!.data() as Map<String, dynamic>? ?? {};
          _role = userData['role'] as String?;
          _pairId = userData['pairId'] as String?;

          // Load partner's nicknames once we have role & pairId
          if (_nicknames.isEmpty && _role != null && _pairId != null) {
            _loadPartnerNicknames();
          }

          // Load special dates once pairId is known (one-shot)
          if (!_specialDatesLoaded && _pairId != null) {
            _specialDatesLoaded = true;
            _loadSpecialDates(_pairId!);
          }

          if (_role == null) {
            return const Center(child: Text("Role not set."));
          }

          return CustomScrollView(
            slivers: [
              // App Bar with rotating nickname greeting
              SliverAppBar(
                expandedHeight: 100.0,
                floating: false,
                pinned: true,
                backgroundColor: Colors.white,
                elevation: 1,
                flexibleSpace: FlexibleSpaceBar(
                  centerTitle: false,
                  titlePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                  title: _nicknames.isEmpty
                      ? const Text(
                    "Hello, Love",
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                    ),
                  )
                      : RotatingGreeting(
                          nicknames: _nicknames,
                          isGirlfriend: _role == 'girlfriend',
                        ),

                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Role-based cycle preview (tap to open full tracker)
                      GestureDetector(
                        onTap: _navigateToTracker,
                        child: _role == 'girlfriend'
                            ? _buildGfCycleRingPreview()
                            : _buildBfSupportCardPreview(_pairId!, _partnerUid),
                      ),

                      const SizedBox(height: 16),
                      _buildSpecialDatesCard(),

                      const SizedBox(height: 16),
                      _buildTodayScheduleCard(),

                      const SizedBox(height: 16),
                      _buildBudgetSnapshotCard(),

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────
  // Preview Widgets
  // ────────────────────────────────────────────────────────────────

  Widget _buildGfCycleRingPreview() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _loadGfCycleData(_pairId!, FirebaseAuth.instance.currentUser?.uid),
      builder: (context, snapshot) {
        final data = snapshot.data ?? {};
        final phase = data['currentPhase'] ?? "Loading...";
        final daysUntil = data['daysUntil'] ?? 0;
        final cycleLen = (data['cycleLen'] as int?) ?? 28;
        final daysProgress = (cycleLen - daysUntil).clamp(0, cycleLen);
        final progress = daysProgress / cycleLen;

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFFFF85A1), Color(0xFFF9AD8D)]),
            borderRadius: BorderRadius.circular(25),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "PERIOD TRACKER (Tap for full view)",
                style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        phase,
                        style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        daysUntil > 0 ? "Next period in $daysUntil days" : "Period is NOW",
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ],
                  ),
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 80,
                        height: 80,
                        child: CircularProgressIndicator(
                          value: progress,
                          strokeWidth: 8,
                          backgroundColor: Colors.white.withOpacity(0.3),
                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                      Text(
                        "$daysProgress/$cycleLen",
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBfSupportCardPreview(String pairId, String? gfUid) {
    if (gfUid == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text("Loading partner data..."),
        ),
      );
    }

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('predictions').doc(gfUid).get(),
      builder: (context, predSnapshot) {
        String tip = "Cycle prediction loading. Check back after she logs today.";

        if (predSnapshot.connectionState == ConnectionState.waiting) {
          tip = "Fetching personalized support tip...";
        } else if (predSnapshot.hasError) {
          tip = "Error fetching prediction.";
        } else if (predSnapshot.hasData && predSnapshot.data!.exists) {
          final data = predSnapshot.data!.data() as Map<String, dynamic>;
          tip = data['predicted_support_tip'] ?? "Prediction data is missing.";
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.pink.shade100),
            borderRadius: BorderRadius.circular(25),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "PARTNER SUPPORT (ML Insight)",
                style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 5),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.favorite, color: Colors.pinkAccent, size: 30),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      tip,
                      style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                'Tap to see the full predicted cycle.',
                style: TextStyle(fontStyle: FontStyle.italic, color: Colors.pink, fontSize: 12),
              ),
            ],
          ),
        );
      },
    );
  }

  // ────────────────────────────────────────────────────────────────
  // New Home Section Widgets
  // ────────────────────────────────────────────────────────────────

  /// Anniversary & Monthsary countdown card
  Widget _buildSpecialDatesCard() {
    final now = DateTime.now();

    int? _daysUntilNext(DateTime? base) {
      if (base == null) return null;
      // Find this year's next occurrence
      DateTime candidate = DateTime(now.year, base.month, base.day);
      if (candidate.isBefore(DateTime(now.year, now.month, now.day))) {
        candidate = DateTime(now.year + 1, base.month, base.day);
      }
      return candidate.difference(DateTime(now.year, now.month, now.day)).inDays;
    }

    final annivDays = _daysUntilNext(_anniversaryDate);
    final monthsaryDays = _monthsaryDate != null
        ? () {
            // Monthsary: same day-of-month, next month
            final day = _monthsaryDate!.day;
            DateTime candidate = DateTime(now.year, now.month, day);
            if (candidate.isBefore(DateTime(now.year, now.month, now.day))) {
              candidate = now.month < 12
                  ? DateTime(now.year, now.month + 1, day)
                  : DateTime(now.year + 1, 1, day);
            }
            return candidate
                .difference(DateTime(now.year, now.month, now.day))
                .inDays;
          }()
        : null;

    final bool hasData = annivDays != null || monthsaryDays != null;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFFD6E0)),
        boxShadow: [
          BoxShadow(
            color: Colors.pink.withOpacity(0.07),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.favorite_rounded, color: Color(0xFFE96D88), size: 18),
              const SizedBox(width: 6),
              const Text(
                'SPECIAL DATES',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFE96D88),
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (!hasData)
            Text(
              'No special dates set yet. Tap Settings to add them 💕',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
            )
          else
            Row(
              children: [
                if (annivDays != null)
                  Expanded(
                    child: _buildDateCountdown(
                      icon: Icons.cake_rounded,
                      label: 'Anniversary',
                      days: annivDays,
                      color: const Color(0xFFFF85A1),
                    ),
                  ),
                if (annivDays != null && monthsaryDays != null)
                  const SizedBox(width: 12),
                if (monthsaryDays != null)
                  Expanded(
                    child: _buildDateCountdown(
                      icon: Icons.calendar_month_rounded,
                      label: 'Monthsary',
                      days: monthsaryDays,
                      color: const Color(0xFFF9AD8D),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildDateCountdown({
    required IconData icon,
    required String label,
    required int days,
    required Color color,
  }) {
    final String dayText = days == 0 ? 'Today! 🎉' : '$days day${days == 1 ? '' : 's'}';
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color.withOpacity(0.85),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            dayText,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: days == 0 ? color : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  /// Today's class schedule preview — split by owner
  Widget _buildTodayScheduleCard() {
    final dayNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    final todayName = dayNames[DateTime.now().weekday % 7];
    final bothEmpty = _myTodayClasses.isEmpty && _partnerTodayClasses.isEmpty;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ClassScheduler()),
      ),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFD6E8FF)),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Card header ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.school_rounded, color: Color(0xFF5B9BD5), size: 18),
                    const SizedBox(width: 6),
                    const Text(
                      'TODAY\'S CLASSES',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF5B9BD5),
                        letterSpacing: 1.1,
                      ),
                    ),
                  ],
                ),
                Text(
                  todayName,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ── Content ──
            if (!_todayClassesLoaded)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF5B9BD5)),
                  ),
                ),
              )
            else if (bothEmpty)
              Text(
                'No classes today — enjoy your day! 🌸',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Your schedule ──
                  if (_myTodayClasses.isNotEmpty) ...([
                    _buildScheduleOwnerLabel('YOUR SCHEDULE', const Color(0xFF5B9BD5)),
                    const SizedBox(height: 8),
                    _buildClassList(_myTodayClasses),
                  ]),

                  // ── Divider between sections ──
                  if (_myTodayClasses.isNotEmpty && _partnerTodayClasses.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Divider(color: Colors.grey.shade200, height: 1),
                    ),

                  // ── Partner's schedule ──
                  if (_partnerTodayClasses.isNotEmpty) ...([
                    _buildScheduleOwnerLabel('PARTNER\'S SCHEDULE', const Color(0xFFE96D88)),
                    const SizedBox(height: 8),
                    _buildClassList(_partnerTodayClasses),
                  ]),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleOwnerLabel(String text, Color color) {
    return Row(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: color,
            letterSpacing: 0.9,
          ),
        ),
      ],
    );
  }

  Widget _buildClassList(List<ClassSchedule> classes) {
    const maxVisible = 3;
    final visible = classes.take(maxVisible).toList();
    final overflow = classes.length - maxVisible;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...visible.map((cls) {
          final groupName = cls.groupId != null
              ? _groupDisplayNames[cls.groupId]
              : null;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 38,
                  decoration: BoxDecoration(
                    color: cls.color,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              cls.subjectName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: Colors.black87,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (groupName != null) ...([
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: cls.color.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                groupName,
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  color: cls.color,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ]),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        cls.getTimeRange(),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
        if (overflow > 0)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              '+$overflow more — tap to view all',
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF5B9BD5),
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
      ],
    );
  }

  /// Monthly budget snapshot card
  Widget _buildBudgetSnapshotCard() {
    final isPositive = _monthlyBalance >= 0;
    final balanceColor = isPositive ? const Color(0xFF4CAF50) : const Color(0xFFE53935);

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const BudgetPlannerPage()),
      ),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFD6F0E0)),
          boxShadow: [
            BoxShadow(
              color: Colors.green.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFF4CAF50), size: 18),
                    const SizedBox(width: 6),
                    const Text(
                      'BUDGET THIS MONTH',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF4CAF50),
                        letterSpacing: 1.1,
                      ),
                    ),
                  ],
                ),
                const Icon(Icons.chevron_right_rounded, size: 18, color: Colors.grey),
              ],
            ),
            const SizedBox(height: 14),
            if (!_budgetLoaded)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF4CAF50)),
                  ),
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: _buildBudgetStat(
                      label: 'Spent',
                      value: '₱${_monthlyExpenses.toStringAsFixed(0)}',
                      color: const Color(0xFFE53935),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildBudgetStat(
                      label: 'Net Balance',
                      value:
                          '${isPositive ? '+' : ''}₱${_monthlyBalance.toStringAsFixed(0)}',
                      color: balanceColor,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBudgetStat({
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color.withOpacity(0.8),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

}