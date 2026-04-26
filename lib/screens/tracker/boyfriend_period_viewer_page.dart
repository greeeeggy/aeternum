// lib/screens/tracker/boyfriend_period_viewer_page.dart
import 'dart:async';
import 'package:aeternum_app/screens/tracker/symptom_summary_card.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:menstrual_cycle_widget/menstrual_cycle_widget.dart';
import 'package:gal/gal.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cross_file/cross_file.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'partner_sync_service.dart';
import 'symptom_database_helper.dart';
import 'cycle_analytics_service.dart';
import 'aero_chat_bubble.dart';

class BoyfriendPeriodViewerPage extends StatefulWidget {
  const BoyfriendPeriodViewerPage({super.key});

  @override
  State<BoyfriendPeriodViewerPage> createState() => _BoyfriendPeriodViewerPageState();
}

class _BoyfriendPeriodViewerPageState extends State<BoyfriendPeriodViewerPage> {
  Key _calendarKey = UniqueKey();
  bool _isLoading = true;
  bool _hasPartner = false;
  String? _errorMessage;
  StreamSubscription<void>? _syncSub;
  
  final ScrollController _periodsScrollController = ScrollController();
  final ScrollController _trendsScrollController = ScrollController();

  // From girlfriend page – needed for download success feedback
  bool _isSuccessVisible = false;

  // ── Lighter neutral/masculine palette ──
  static const Color backgroundSoft = Color(0xFFF5F7FA);     // very light cool gray-blue
  static const Color vibrantAccent = Color(0xFF0B7285);      // deep teal/blue
  static const Color accentGlow   = Color(0xFF20C997);       // soft teal glow
  static const Color surfaceWhite = Colors.white;            // clean white surfaces
  static const Color textPrimary  = Color(0xFF1F2A44);       // dark charcoal text

  static const Color borderColor  = Color(0xFFDDE4ED);       // light muted border
  static const Color greyText     = Color(0xFF6B7280);       // neutral gray

  void _showSuccessText() {
    if (!mounted) return;
    setState(() => _isSuccessVisible = true);
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _isSuccessVisible = false);
    });
  }

  @override
  void dispose() {
    _periodsScrollController.dispose();
    _trendsScrollController.dispose();
    _syncSub?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();

    // Configure MenstrualCycleWidget with this user's UID as customerId.
    // Use a small post-frame delay so the widget tree is fully ready,
    // then sync. The direct SQLite writes in PartnerSyncService use
    // Encryption.instance.encrypt(uid) directly so they don't depend
    // on this call completing first.
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '0';
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Compute personalized cycle length — this runs after sync so SQLite
      // already has the girlfriend's period dates when we read them.
      final cycleLen = await CycleAnalyticsService().computePersonalizedCycleLength();
      MenstrualCycleWidget.instance?.updateConfiguration(
        customerId: uid,
        cycleLength: cycleLen,
        periodDuration: 5,
      );
    });

    final service = PartnerSyncService();

    if (service.hasSyncedOnce) {
      // Data already in SQLite from a previous visit — show calendar instantly,
      // then kick off a background refresh without a loading spinner.
      setState(() {
        _isLoading = false;
        _hasPartner = true;
      });
      _backgroundRefresh();
    } else {
      // First visit — show the spinner while we sync.
      _syncData();
    }

    // Start Firestore real-time listener (safe to call multiple times —
    // the singleton cancels the previous subscription before attaching).
    service.startListening();

    // When a background sync completes, silently bump the calendar key.
    _syncSub = service.onSyncDone.listen((_) {
      if (mounted) {
        setState(() => _calendarKey = UniqueKey());
      }
    });
  }

  /// Runs a fresh sync in the background without touching _isLoading,
  /// so the calendar stays visible while new data is fetched.
  Future<void> _backgroundRefresh() async {
    try {
      await PartnerSyncService().syncGirlfriendPeriodsToLocal();
      await PartnerSyncService().syncGirlfriendSymptomsToLocal(limit: 60);
      // Recompute cycle length so phase view re-renders with updated data
      final cycleLen = await CycleAnalyticsService().computePersonalizedCycleLength();
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '0';
      MenstrualCycleWidget.instance?.updateConfiguration(
        customerId: uid,
        cycleLength: cycleLen,
        periodDuration: 5,
      );
      // onSyncDone stream will bump _calendarKey automatically
    } catch (e) {
      debugPrint('Background refresh error: $e');
    }
  }

  Future<void> _syncData() async {
    setState(() { _isLoading = true; _errorMessage = null; });

    try {
      await PartnerSyncService().syncGirlfriendPeriodsToLocal();
      await PartnerSyncService().syncGirlfriendSymptomsToLocal(limit: 60);

      // Small delay to let the DB writes fully flush before the calendar mounts
      // and reads from SQLite — prevents the race condition where the widget
      // initializes before insertPeriodLog is committed.
      await Future.delayed(const Duration(milliseconds: 300));

      final recentLogs = await SymptomDatabaseHelper.instance.getAllLogs(limit: 5);
      debugPrint("After sync — local symptoms count: ${recentLogs.length}");
      if (recentLogs.isNotEmpty) {
        debugPrint("Latest symptom date: ${recentLogs.first['date']}");
      }

      // Recompute and push personalized cycle length before the phase view mounts
      final cycleLen = await CycleAnalyticsService().computePersonalizedCycleLength();
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '0';
      MenstrualCycleWidget.instance?.updateConfiguration(
        customerId: uid,
        cycleLength: cycleLen,
        periodDuration: 5,
      );

      if (mounted) {
        setState(() {
          _hasPartner = true;
          _calendarKey = UniqueKey();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Sync error: $e");
      if (mounted) {
        setState(() { _errorMessage = e.toString(); _isLoading = false; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Partner's Cycle"),
        backgroundColor: vibrantAccent,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _backgroundRefresh,
            tooltip: "Refresh data",
          ),
        ],
      ),
      body: Stack(
        children: [
          _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: vibrantAccent),
                  SizedBox(height: 24),
                  Text("Loading partner's cycle...", style: TextStyle(color: vibrantAccent)),
                ],
              ),
            )
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 64, color: Colors.red.shade400),
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 18, color: Colors.red),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: _syncData,
                          icon: const Icon(Icons.refresh),
                          label: const Text("Try Again"),
                          style: ElevatedButton.styleFrom(backgroundColor: vibrantAccent),
                        ),
                      ],
                    ),
                  ),
                )
              : !_hasPartner
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          "No partner linked yet.\nPlease complete pairing first.",
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(color: greyText),
                        ),
                      ),
                    )
                  : RefreshIndicator(
        onRefresh: _backgroundRefresh,
        color: vibrantAccent,
        backgroundColor: backgroundSoft,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              const SizedBox(height: 16),

              Container(
                width: double.infinity,
                color: vibrantAccent.withOpacity(0.1),
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                child: Text(
                  "Viewing your partner's cycle • Read-only",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: vibrantAccent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              Text(
                "Menstrual Cycle Tracker",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: vibrantAccent,
                ),
              ),

              const SizedBox(height: 6),
              Text(
                "Data synced from your partner",
                style: TextStyle(color: greyText),
              ),

              const SizedBox(height: 16),

              Container(
                height: 370,
                margin: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: surfaceWhite,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: borderColor),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: IgnorePointer(
                  ignoring: false,
                  child: Opacity(
                    opacity: 0.9,
                    child: MenstrualCycleMonthlyCalenderView(
                      key: _calendarKey,
                      themeColor: textPrimary,
                      daySelectedColor: vibrantAccent,
                      hideInfoView: false,
                      isShowCloseIcon: false,
                      onDataChanged: null,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 30),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const SymptomSummaryCard(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.notes, size: 20),
                    label: const Text(
                      "Girlfriend's Logged Symptoms",
                      style: TextStyle(fontSize: 18),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: vibrantAccent,
                      foregroundColor: surfaceWhite,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 4,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 40),

              // Cycle History Graph (unchanged from previous version)
              Container(
                height: 300,
                decoration: BoxDecoration(
                  color: surfaceWhite,
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
                          color: vibrantAccent.withOpacity(0.05),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                          border: Border(bottom: BorderSide(color: vibrantAccent.withOpacity(0.1), width: 1)),
                        ),
                        child: Text(
                          'Cycle History',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: vibrantAccent,
                          ),
                        ),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          physics: const ClampingScrollPhysics(),
                          child: MenstrualCycleHistoryGraph(
                            headerTitle: 'Cycle History',
                            headerTitleTextStyle: TextStyle(
                              fontSize: 0,
                              fontWeight: FontWeight.bold,
                              color: vibrantAccent,
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

              // Period Cycle Graph (unchanged)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: backgroundSoft,
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
                          color: vibrantAccent.withOpacity(0.05),
                          border: Border(bottom: BorderSide(color: vibrantAccent.withOpacity(0.1), width: 1)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Period Cycle',
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: vibrantAccent),
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
                                  isShowMoreOptions: true,
                                  loadingText: 'Loading period cycle...',
                                  xAxisTitle: 'Cycle start date',
                                  yAxisTitle: 'Cycle length (days)',
                                  periodDaysColor: vibrantAccent,
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

              // Cycle Trends Graph (unchanged)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: backgroundSoft,
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
                          color: vibrantAccent.withOpacity(0.05),
                          border: Border(bottom: BorderSide(color: vibrantAccent.withOpacity(0.1), width: 1)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Cycle Trends',
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: vibrantAccent),
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
                                  headerTitle: 'Cycle Trends',
                                  headerTitleTextStyle: TextStyle(fontSize: 0, height: 0, color: Colors.transparent),
                                  isShowMoreOptions: true,
                                  themeColor: vibrantAccent,
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

              // Cycle Phases – original phase colors preserved, only central circle & selected day updated
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                child: MenstrualCyclePhaseView(
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
                  centralCircleBackgroundColor: surfaceWhite,          // ← changed
                  centralCircleSize: 140,
                  centralCircleBorderColor: vibrantAccent,             // ← changed
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
                  selectedDayBackgroundColor: surfaceWhite,            // ← changed
                  selectedDayCircleBorderColor: vibrantAccent,         // ← changed
                  selectedDayCircleSize: 26,
                  selectedDayTextColor: vibrantAccent,                 // ← changed
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
          const AeroChatBubble(),
        ],
      ),
    );
  }
}
