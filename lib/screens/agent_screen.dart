// lib/screens/agent_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../agent/classroom/classroom_monitor.dart';
import '../agent/classroom/classroom_state.dart';
import '../agent/classroom/classroom_service.dart';
import '../agent/classroom/models/classroom_assignment.dart';
import '../services/onesignal_service.dart';

/// Phase 1 — Aeternum Agent screen.
/// Shows Classroom connection status, last sync time, course list,
/// and controls to start/stop the background monitor.
class AgentScreen extends StatefulWidget {
  const AgentScreen({super.key});

  @override
  State<AgentScreen> createState() => _AgentScreenState();
}

class _AgentScreenState extends State<AgentScreen> {
  bool _loading = false;
  bool _syncing = false;
  String? _lastSync;
  Map<String, String> _courseNames = {};
  Map<String, List<ClassroomAssignment>> _courseAssignments = {};
  String? _expandedCourseId;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadInitialState();
    _setupNotifications();
  }

  Future<void> _setupNotifications() async {
    final messaging = FirebaseMessaging.instance;
    
    // 1. Request Runtime Permissions (Crucial for Android 13+)
    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    debugPrint('🔔 Notification permission status: ${settings.authorizationStatus}');
    
    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      // 2. Subscribe to Classroom Updates via OneSignal Tag
      await OneSignalService().addTag('topic', 'classroom_updates');
      debugPrint('✅ Subscribed to topic: classroom_updates (OneSignal)');
    }

    // 3. Listen for foreground FCM messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('🔔 Agent UI: Received Push Update! Refreshing...');
      _performAutoSync();
      
      // Show an in-app snackbar for visibility during testing
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('📚 Classroom Update Received!'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });
  }

  Future<void> _loadInitialState() async {
    try {
      await ClassroomState.ensureOpen();
      
      final cachedCourses = ClassroomState.getCourseNames();
      final cachedAssignments = ClassroomState.getAssignments();
      final cachedSyncTime = ClassroomState.getLastSyncTime();

      setState(() {
        _courseNames = cachedCourses;
        _courseAssignments = cachedAssignments;
        _lastSync = cachedSyncTime;
        
        // Only show full-screen loader if we have NO data to show yet
        _loading = _courseNames.isEmpty;
      });
      
      // Automatically trigger a background sync on entry
      _performAutoSync();
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'Failed to load initial state: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _performAutoSync() async {
    setState(() => _syncing = true);
    try {
      final svc = ClassroomService();
      final courses = await svc.fetchCourses();
      
      final nameMap = <String, String>{};
      final assignmentsMap = <String, List<ClassroomAssignment>>{};

      for (final c in courses) {
        if (c.id != null && c.name != null) {
          nameMap[c.id!] = c.name!;
          final list = await svc.fetchCoursework(c.id!);
          assignmentsMap[c.id!] = list;
        }
      }

      await ClassroomState.setCourseNames(nameMap);
      await ClassroomState.setAssignments(assignmentsMap);
      await ClassroomState.setLastSyncTime(DateTime.now().toIso8601String());

      if (mounted) {
        setState(() {
          _courseNames = nameMap;
          _courseAssignments = assignmentsMap;
          _lastSync = ClassroomState.getLastSyncTime();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().contains('DEVELOPER_ERROR')
              ? 'Developer Error: SHA-1 mismatch. Please check your Google Cloud Console.'
              : 'Sync failed: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _syncing = false;
          _loading = false;
        });
      }
    }
  }

  Future<void> _handleManualSignIn() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final svc = ClassroomService();
      await svc.signIn();
      await _performAutoSync();
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'Sign-in failed: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleSignOut() async {
    try {
      final svc = ClassroomService();
      await svc.signOut();
      await ClassroomState.setCourseNames({});
      await ClassroomState.setAssignments({});
      setState(() {
        _courseNames = {};
        _courseAssignments = {};
        _lastSync = null;
      });
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'Sign-out failed: $e');
    }
  }


  Future<void> _fetchAssignments(String courseId) async {
    if (_expandedCourseId == courseId) {
      setState(() => _expandedCourseId = null);
      return;
    }

    setState(() {
      _expandedCourseId = courseId;
      _errorMessage = null;
    });

    if (_courseAssignments.containsKey(courseId)) return;

    try {
      final svc = ClassroomService();
      final assignments = await svc.fetchCoursework(courseId);
      setState(() {
        _courseAssignments[courseId] = assignments;
      });
    } catch (e) {
      setState(() => _errorMessage = 'Failed to fetch assignments: $e');
    }
  }

  Future<void> _openUsageSettings() async {
    try {
      const intent = AndroidIntent(
        action: 'android.settings.ACTION_USAGE_ACCESS_SETTINGS',
      );
      await intent.launch();
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'Could not open settings: $e');
    }
  }

  void _showPersistenceGuide() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Text('Stay Active', 
          style: GoogleFonts.nunito(fontWeight: FontWeight.w800, color: const Color(0xFF7B4FA0))),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _guideItem('1. Enable Autostart', 'Go to App Info > Autostart and turn it ON.'),
              const SizedBox(height: 12),
              _guideItem('2. Battery Optimization', 'Set Battery Saver to "No Restrictions".'),
              const SizedBox(height: 12),
              _guideItem('3. Lock in Recents', 'Open Recent Tasks, long-press this app, and tap the Lock icon.'),
              const SizedBox(height: 12),
              _guideItem('4. Usage Data Access', 'Permit usage access to help the system keep the Agent alive.'),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _openUsageSettings,
                  icon: const Icon(Icons.settings_applications_rounded, size: 18),
                  label: Text('Open Usage Settings', style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF9B6FD4),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),
              Text('Note: Debugging via "flutter run" will always kill the agent on swipe. Test in Release mode for true persistence.',
                style: GoogleFonts.nunito(fontSize: 10, color: Colors.grey[600], fontStyle: FontStyle.italic)),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _handleSignOut();
                  },
                  icon: const Icon(Icons.logout_rounded, size: 16),
                  label: Text('Sign Out / Reset Classroom', 
                    style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w700)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red[400],
                    side: BorderSide(color: Colors.red[100]!),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Got it', style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _guideItem(String title, String desc) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w800, color: const Color(0xFF2A1A1A))),
        Text(desc, style: GoogleFonts.nunito(fontSize: 12, color: const Color(0xFF9B8090))),
      ],
    );
  }

  Future<void> _launchAssignment(ClassroomAssignment a) async {
    if (a.alternateLink == null) return;
    try {
      final uri = Uri.parse(a.alternateLink!);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        setState(() => _errorMessage = 'Could not open classroom link.');
      }
    } catch (e) {
      setState(() => _errorMessage = 'Error opening link: $e');
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF4F0),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Color(0xFF4A3340)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Aeternum Agent',
          style: GoogleFonts.playfairDisplay(
            color: const Color(0xFF2A1A1A),
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _performAutoSync,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  _buildStatusCard(),
                  const SizedBox(height: 16),
                  if (_errorMessage != null) _buildErrorCard(),
                  if (_errorMessage != null) const SizedBox(height: 16),
                  _buildPendingTasksCard(),
                  const SizedBox(height: 16),
                  _buildCoursesCard(),
                  const SizedBox(height: 24),
                  _buildPhaseNote(),
                ],
              ),
            ),
    );
  }


  // ── Status card ───────────────────────────────────────────────────────────

  Widget _buildStatusCard() {
    final syncLabel = _lastSync == null
        ? 'Never synced'
        : 'Last sync: ${DateFormat('MMM d, h:mm a').format(DateTime.parse(_lastSync!).toLocal())}';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7B5EA7).withOpacity(0.12),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF9B6FD4), Color(0xFF7B4FA0)],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.smart_toy_rounded,
                color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Aeternum Agent',
                    style: GoogleFonts.nunito(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF2A1A1A),
                    )),
                Row(
                  children: [
                    Text(_syncing ? 'Syncing...' : syncLabel,
                        style: GoogleFonts.nunito(
                          fontSize: 11,
                          color: const Color(0xFF9B8090),
                          fontWeight: FontWeight.w500,
                        )),
                    if (_syncing)
                      const Padding(
                        padding: EdgeInsets.only(left: 8.0),
                        child: SizedBox(
                            width: 10,
                            height: 10,
                            child: CircularProgressIndicator(strokeWidth: 1.5)),
                      ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: _showPersistenceGuide,
                      child: const Icon(Icons.info_outline_rounded,
                          size: 14, color: Color(0xFF9B6FD4)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          _buildStatusDot(),
        ],
      ),
    );
  }


  Widget _buildStatusDot() {
    return Container(
      width: 12, height: 12,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF4CAF50),
        boxShadow: [BoxShadow(color: const Color(0xFF4CAF50).withOpacity(0.4),
                blurRadius: 6, spreadRadius: 1)],
      ),
    );
  }

  // ── Error card ────────────────────────────────────────────────────────────

  Widget _buildErrorCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF0F0),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFCDD2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              color: Color(0xFFE57373), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(_errorMessage!,
                style: GoogleFonts.nunito(
                    fontSize: 12, color: const Color(0xFFC62828))),
          ),
        ],
      ),
    );
  }

  // ── Pending Tasks Card ────────────────────────────────────────────────────

  Widget _buildPendingTasksCard() {
    final allAssignments = _courseAssignments.values.expand((x) => x).toList();
    final pending = allAssignments.where((a) => !a.isSubmitted).toList();

    // Sort by due date (soonest first). If no due date, move to end.
    pending.sort((a, b) {
      if (a.dueDate == null && b.dueDate == null) return 0;
      if (a.dueDate == null) return 1;
      if (b.dueDate == null) return -1;
      return a.dueDate!.compareTo(b.dueDate!);
    });

    if (pending.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBFA),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFFFEBEE), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withOpacity(0.03),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.assignment_late_rounded,
                  color: Color(0xFFE57373), size: 20),
              const SizedBox(width: 10),
              Text('Pending Tasks',
                  style: GoogleFonts.nunito(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFFC62828),
                  )),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEBEE),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('${pending.length} left',
                    style: GoogleFonts.nunito(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFFD32F2F),
                    )),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...pending.take(5).map((a) {
            final courseName = _courseNames[a.courseId] ?? 'Classroom';
            return InkWell(
              onTap: () => _launchAssignment(a),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                     Row(
                      children: [
                        Expanded(
                          child: Text(
                            a.title,
                            style: GoogleFonts.nunito(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF2A1A1A),
                            ),
                          ),
                        ),
                        if (a.dueDate != null)
                          Text(
                            DateFormat('MMM d').format(a.dueDate!),
                            style: GoogleFonts.nunito(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFFE57373),
                            ),
                          ),
                      ],
                    ),
                    Text(
                      courseName,
                      style: GoogleFonts.nunito(
                        fontSize: 11,
                        color: const Color(0xFF9B8090),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (a.description != null && a.description!.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F4),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          a.description!.trim(),
                          style: GoogleFonts.nunito(
                            fontSize: 11,
                            color: const Color(0xFF4A3340),
                            height: 1.4,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
            );
          }),
          if (pending.length > 5)
            Center(
              child: Text(
                'View all in courses below...',
                style: GoogleFonts.nunito(
                  fontSize: 11,
                  color: const Color(0xFF9B8090),
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Courses card ──────────────────────────────────────────────────────────

  Widget _buildCoursesCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tracked Courses',
              style: GoogleFonts.nunito(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF4A3340),
              )),
          const SizedBox(height: 12),
          if (_courseNames.isEmpty)
            Text(
              'No courses found yet. The Agent will automatically sync your Classroom data when active.',
              style: GoogleFonts.nunito(
                  fontSize: 12, color: const Color(0xFF9B8090)),
            )
          else
            ..._courseNames.entries.map((entry) {
              final courseId = entry.key;
              final name = entry.value;
              final isExpanded = _expandedCourseId == courseId;

              return Column(
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.school_rounded,
                        size: 20, color: Color(0xFF9B6FD4)),
                    title: Text(name,
                        style: GoogleFonts.nunito(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF2A1A1A),
                        )),
                      trailing: Icon(
                      isExpanded
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      color: const Color(0xFF9B8090),
                    ),
                    onTap: () => _fetchAssignments(courseId),
                  ),
                  if (isExpanded) _buildAssignmentList(courseId),
                  if (entry.key != _courseNames.keys.last)
                    const Divider(height: 1, color: Color(0xFFF3EEFA)),
                ],
              );
            }),
          if (_courseNames.isEmpty && !_loading)
            Padding(
              padding: const EdgeInsets.only(top: 12.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _handleManualSignIn,
                  icon: const Icon(Icons.account_circle_rounded, size: 20),
                  label: Text('Connect Google Classroom', 
                    style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF9B6FD4),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAssignmentList(String courseId) {
    final list = _courseAssignments[courseId];

    if (list == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8.0),
        child: Center(
            child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2))),
      );
    }

    if (list.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Text('No assignments found for this course.',
            style: GoogleFonts.nunito(
                fontSize: 12, color: const Color(0xFF9B8090))),
      );
    }

    return Column(
      children: list.map<Widget>((a) {
        final hasGrade = a.assignedGrade != null;
        final scoreText = hasGrade
            ? '${a.assignedGrade?.toStringAsFixed(0)}/${a.maxPoints?.toStringAsFixed(0)}'
            : '';

        return InkWell(
          onTap: () => _launchAssignment(a),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            margin: const EdgeInsets.only(left: 12, bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFBF8F8),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(a.title,
                          style: GoogleFonts.nunito(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF2A1A1A),
                          )),
                      if (a.dueDate != null)
                        Text(
                          'Due: ${DateFormat('MMM d').format(a.dueDate!)}',
                          style: GoogleFonts.nunito(
                              fontSize: 10, color: const Color(0xFF9B8090)),
                        ),
                    ],
                  ),
                ),
                if (a.isSubmitted)
                  const Icon(Icons.check_circle_rounded,
                      color: Color(0xFF4CAF50), size: 16),
                if (hasGrade) ...[
                  const SizedBox(width: 8),
                  Text(
                    scoreText,
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF7B4FA0),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── Phase note ────────────────────────────────────────────────────────────

  Widget _buildPhaseNote() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF3EEFA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD1B3EC)),
      ),
      child: Text(
        '✨ Phase 1 — Classroom Monitor active. AI summaries and voice control coming in Phase 2 & 3.',
        style: GoogleFonts.nunito(
          fontSize: 12,
          color: const Color(0xFF5A3A7A),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
