// lib/screens/tracker/full_period_tracker_page.dart

import 'package:flutter/material.dart';
import 'package:menstrual_cycle_widget/menstrual_cycle_widget.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'period_tracker_service.dart';
import 'cycle_analytics_service.dart';
import 'symptom_logging_screen.dart'; // ← Added import
import 'eri_chat_bubble.dart';
import 'package:gal/gal.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cross_file/cross_file.dart'; // This defines XFile
import 'package:fluttertoast/fluttertoast.dart';
import 'package:connectivity_plus/connectivity_plus.dart'; // ← NEW: Added for offline support

class FullPeriodTrackerPage extends StatefulWidget {
  const FullPeriodTrackerPage({Key? key}) : super(key: key);

  @override
  State<FullPeriodTrackerPage> createState() => _FullPeriodTrackerPageState();
}

class _FullPeriodTrackerPageState extends State<FullPeriodTrackerPage> {
  Key _calendarKey  = UniqueKey();
  Key _historyKey    = UniqueKey();
  Key _periodsKey    = UniqueKey();
  Key _trendsKey     = UniqueKey();
  Key _phaseKey      = UniqueKey();
  
  final ScrollController _periodsScrollController = ScrollController();
  final ScrollController _trendsScrollController = ScrollController();

  final PeriodTrackerService _trackerService = PeriodTrackerService();

  bool _isBoyfriend = false;        // true → read-only mode
  bool _isLoadingRole = true;       // shows loader until role is known
  bool _isSyncing    = true;        // shows loader until first sync completes
  bool _isSuccessVisible = false;

  void _showSuccessText() {
    if (!mounted) return;
    setState(() => _isSuccessVisible = true);
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _isSuccessVisible = false);
    });
  }

  @override
  void initState() {
    super.initState();
    _loadUserRole();

    // Run sync first — keep spinner up until done so the calendar ONLY mounts
    // after SQLite has data. This prevents the calendar from ever being
    // destroyed mid-interaction by an async key change.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await _trackerService.initializeSync();
      // Compute personalized cycle length and push it into the widget
      // so MenstrualCyclePhaseView renders the correct number of days.
      final cycleLen = await CycleAnalyticsService().computePersonalizedCycleLength();
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '0';
      MenstrualCycleWidget.instance?.updateConfiguration(
        customerId: uid,
        cycleLength: cycleLen,
        periodDuration: 5,
      );
      if (mounted) setState(() => _isSyncing = false);
    });
  }

  Future<void> _loadUserRole() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() {
          _isBoyfriend = true;
          _isLoadingRole = false;
        });
      }
      return;
    }

    try {
      final DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data() as Map<String, dynamic>;
        final String? role = data['role'] as String?;

        if (mounted) {
          setState(() {
            _isBoyfriend = (role == 'boyfriend');
            _isLoadingRole = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isBoyfriend = false;
            _isLoadingRole = false;
          });
        }
      }
    } catch (e) {
      print('Error loading role: $e');
      if (mounted) {
        setState(() {
          _isBoyfriend = false;
          _isLoadingRole = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _periodsScrollController.dispose();
    _trendsScrollController.dispose();
    _trackerService.dispose();
    super.dispose();
  }

  // Bumps only the 4 graph widgets — NOT the calendar.
  // The calendar mounts once (after sync) and is never recreated async.
  // Only _handleRefresh (user pull gesture) may also change _calendarKey.
  void _refreshAllWidgets() {
    if (!mounted) return;
    final route = ModalRoute.of(context);
    if (route == null || !route.isCurrent) return;
    setState(() {
      _historyKey  = UniqueKey();
      _periodsKey  = UniqueKey();
      _trendsKey   = UniqueKey();
      _phaseKey    = UniqueKey();
    });
  }

  Future<void> _handleRefresh() async {
    _trackerService.resetForRefresh();
    await _loadUserRole();
    await _trackerService.initializeSync();
    // Recompute personalized cycle length after a manual refresh
    final cycleLen = await CycleAnalyticsService().computePersonalizedCycleLength();
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '0';
    MenstrualCycleWidget.instance?.updateConfiguration(
      customerId: uid,
      cycleLength: cycleLen,
      periodDuration: 5,
    );
    // Pull-to-refresh is a user swipe gesture — safe to also bump _calendarKey
    // since the user cannot be tapping calendar cells while pulling down.
    if (mounted) {
      final route = ModalRoute.of(context);
      if (route != null && route.isCurrent) {
        setState(() {
          _calendarKey = UniqueKey();
          _historyKey  = UniqueKey();
          _periodsKey  = UniqueKey();
          _trendsKey   = UniqueKey();
          _phaseKey    = UniqueKey();
        });
      }
    }
    await Future.delayed(const Duration(milliseconds: 400));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Period Tracker'),
        backgroundColor: Colors.pink,
      ),
      body: (_isLoadingRole || _isSyncing)
          ? const Center(child: CircularProgressIndicator(color: Colors.pink,))
          : Stack(
              children: [
                _buildCalendarView(),
                EriChatBubble(isBoyfriend: _isBoyfriend),
              ],
            ),
    );
  }

  Widget _buildCalendarView() {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _handleRefresh,
        color: Colors.pink,
        backgroundColor: Colors.white,
        strokeWidth: 3.0,
        displacement: 60.0,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              const SizedBox(height: 16),
              Text(
                'Menstrual Cycle Tracker',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.pink.shade800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _isBoyfriend
                    ? 'Viewing your girlfriend\'s cycle'
                    : 'Tap days to mark or unmark your period',
                style: TextStyle(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 16),
              Container(
                height: 370,
                margin: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade300),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: IgnorePointer(
                  ignoring: _isBoyfriend,
                  child: Opacity(
                    opacity: _isBoyfriend ? 0.7 : 1.0,
                    child: MenstrualCycleMonthlyCalenderView(
                      key: _calendarKey,
                      themeColor: Colors.pink,
                      daySelectedColor: Colors.redAccent,
                      hideInfoView: true,
                      isShowCloseIcon: false,
                      onDataChanged: _isBoyfriend
                          ? null
                          : (value) async {
                        // Only trigger a Firebase sync — do NOT call
                        // _refreshCalendar here. Forcing a UniqueKey rebuild
                        // destroys the calendar and re-fires onDataChanged,
                        // which creates an infinite loop and causes the
                        // visually-selected days to reset (making users
                        // re-tap already-logged days → duplicate DB rows).
                        _trackerService.onLocalDataChanged();
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 30),

              // ← NEW: Log your Symptoms button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: _isBoyfriend
                        ? null
                        : () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const SymptomLoggingScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.notes, size: 20),
                    label: const Text(
                      'Log your Symptoms',
                      style: TextStyle(fontSize: 18),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.pink.shade600,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 4,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 40),

              // ← Cycle History Graph with FIXED header (internal title made invisible)
              Container(
                height: 300,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                margin: const EdgeInsets.symmetric(horizontal: 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Column(
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.pink.shade50,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                          border: Border(bottom: BorderSide(color: Colors.pink.shade100, width: 1)),
                        ),
                        child: Text(
                          'Cycle History',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.pink.shade800,
                          ),
                        ),
                      ),

                      Expanded(
                        child: SingleChildScrollView(
                          physics: const ClampingScrollPhysics(),
                          child: MenstrualCycleHistoryGraph(
                            key: _historyKey,
                            headerTitle: 'Cycle History',
                            headerTitleTextStyle: TextStyle(
                              fontSize: 0,
                              fontWeight: FontWeight.bold,
                              color: Colors.transparent,
                              height: 0,
                              textBaseline: null,
                            ),
                            viewCycleHistoryLength: 30,
                            loadingText: 'Loading cycle history...',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 60),

              // ← NEW: Period Cycle Graph
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.pink.shade50,
                          border: Border(bottom: BorderSide(color: Colors.pink.shade100, width: 1)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Period Cycle',
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.pink.shade800),
                            ),
                            if (_isSuccessVisible)
                              const Text(
                                'Download successful',
                                style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                          ],
                        ),
                      ),

                      Container(
                        height: 420,
                        width: double.infinity,
                        child: Scrollbar(
                          controller: _periodsScrollController,
                          thumbVisibility: true,
                          child: SingleChildScrollView(
                            controller: _periodsScrollController,
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              child: SizedBox(
                                width: 1000,
                                child: MenstrualCyclePeriodsGraph(
                                  key: _periodsKey,
                                  isShowMoreOptions: true,
                                  loadingText: 'Loading period cycle...',
                                  xAxisTitle: 'Cycle start date',
                                  yAxisTitle: 'Cycle length (days)',
                                  periodDaysColor: Colors.pink,
                                  onImageDownloadCallback: (imagePath) async {
                                    if (imagePath == null) return;
                                    try {
                                      final cleanPath = imagePath.toString().replaceAll("File: '", "").replaceAll("'", "");
                                      await Gal.putImage(cleanPath);
                                      _showSuccessText();
                                      Fluttertoast.showToast(msg: 'Saved to Gallery!');
                                    } catch (e) {
                                      Fluttertoast.showToast(msg: 'Image Save Failed');
                                    }
                                  },
                                  onPdfDownloadCallback: (pdfPath) async {
                                    if (pdfPath == null) return;
                                    try {
                                      final cleanPath = pdfPath.toString().replaceAll("File: '", "").replaceAll("'", "");
                                      await Share.shareXFiles(
                                        [XFile(cleanPath)],
                                        text: 'Period Cycle Report',
                                      );
                                      _showSuccessText();
                                    } catch (e) {
                                      Fluttertoast.showToast(msg: 'PDF Export Failed');
                                    }
                                  },
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 60),

              // ← NEW: Cycle Trends Graph
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.pink.shade50,
                          border: Border(bottom: BorderSide(color: Colors.pink.shade100, width: 1)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Cycle Trends',
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.pink.shade800),
                            ),
                            if (_isSuccessVisible)
                              const Text(
                                'Download successful',
                                style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                          ],
                        ),
                      ),

                      Container(
                        height: 420,
                        width: double.infinity,
                        child: Scrollbar(
                          controller: _trendsScrollController,
                          thumbVisibility: true,
                          child: SingleChildScrollView(
                            controller: _trendsScrollController,
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              child: SizedBox(
                                width: 1000,
                                child: MenstrualCycleTrendsGraph(
                                  key: _trendsKey,
                                  headerTitle: 'Cycle Trends',
                                  headerTitleTextStyle: const TextStyle(fontSize: 0, height: 0, color: Colors.transparent),
                                  isShowMoreOptions: true,
                                  themeColor: Colors.pink,
                                  loadingText: 'Loading trends...',

                                  onImageDownloadCallback: (imagePath) async {
                                    if (imagePath == null) return;
                                    try {
                                      final cleanPath = imagePath.toString().replaceAll("File: '", "").replaceAll("'", "");
                                      await Gal.putImage(cleanPath);
                                      _showSuccessText();
                                      Fluttertoast.showToast(msg: 'Saved to Gallery!');
                                    } catch (e) {
                                      Fluttertoast.showToast(msg: 'Image Save Failed');
                                    }
                                  },

                                  onPdfDownloadCallback: (pdfPath) async {
                                    if (pdfPath == null) return;
                                    try {
                                      final cleanPath = pdfPath.toString().replaceAll("File: '", "").replaceAll("'", "");
                                      await Share.shareXFiles(
                                        [XFile(cleanPath)],
                                        text: 'Cycle Trends Report',
                                      );
                                      _showSuccessText();
                                    } catch (e) {
                                      Fluttertoast.showToast(msg: 'PDF Export Failed');
                                    }
                                  },

                                  xAxisTitle: 'Cycle start date',
                                  yAxisTitle: 'Cycle length (days)',
                                  normalRangeHintTitle: 'Normal range',
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 60),

              // ← NEW: Cycle Phases
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                child: MenstrualCyclePhaseView(
                  key: _phaseKey,
                  size: 400,
                  isAutoSetData: true,
                  theme: MenstrualCycleTheme.arcs,
                  phaseTextBoundaries: PhaseTextBoundaries.outside,
                  viewType: MenstrualCycleViewType.circleText,
                  isRemoveBackgroundPhaseColor: false,

                  titleTextColor: Colors.pink.shade900,
                  titleTextSize: 35,
                  titleFontWeight: FontWeight.bold,

                  spaceBtnTitleMessage: 8,

                  centralCircleBackgroundColor: Colors.white,
                  centralCircleSize: 140,
                  centralCircleBorderColor: Colors.pink.shade400,
                  centralCircleBorderSize: 4,

                  menstruationColor: Colors.red.shade600,
                  menstruationTextColor: Colors.red.shade700,
                  menstruationBackgroundColor: Colors.red.shade100.withOpacity(0.4),
                  menstruationName: 'Menstruation',

                  follicularPhaseColor: Colors.orange.shade500,
                  follicularTextColor: Colors.orange.shade700,
                  follicularBackgroundColor: Colors.orange.shade100.withOpacity(0.4),
                  follicularPhaseName: 'Follicular',

                  ovulationColor: Colors.green.shade600,
                  ovulationTextColor: Colors.green.shade800,
                  ovulationBackgroundColor: Colors.green.shade100.withOpacity(0.4),
                  ovulationName: 'Ovulation',

                  lutealPhaseColor: Colors.purple.shade500,
                  lutealPhaseTextColor: Colors.purple.shade700,
                  lutealPhaseBackgroundColor: Colors.purple.shade100.withOpacity(0.4),
                  lutealPhaseName: 'Luteal',

                  dayFontSize: 12,
                  dayTextColor: Colors.grey.shade900,
                  dayFontWeight: FontWeight.w500,
                  dayTitleFontSize: 5,
                  isShowDayTitle: true,

                  selectedDayBackgroundColor: Colors.white,
                  selectedDayCircleBorderColor: Colors.pink.shade800,
                  selectedDayCircleSize: 26,
                  selectedDayTextColor: Colors.pink,
                  selectedDayFontSize: 20,

                  outsidePhasesTextSize: 14,
                  outsideTextCharSpace: 4,
                  outsideTextSpaceFromArc: 25,

                  phasesTextSize: 12,
                ),
              ),

              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }
}