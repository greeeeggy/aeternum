// lib/agent/classroom/classroom_monitor.dart
import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'classroom_service.dart';
import 'classroom_state.dart';
import 'models/classroom_assignment.dart';
import '../../firebase_options.dart';
import '../../services/onesignal_service.dart';

// ── Notification channel — MUST differ from 'com.aeternum.audio' ────────────
const _kChannelId = 'com.aeternum.agent';
const _kChannelName = 'Aeternum Agent';
const _kForegroundNotifId = 888;
const _kPollInterval = Duration(minutes: 15);

// ── Top-level entry point required by flutter_background_service ─────────────
// @pragma ensures the function is not tree-shaken in release builds.
@pragma('vm:entry-point')
void onAgentServiceStart(ServiceInstance service) async {
  // 1. MUST initialize framework and set foreground status WITHIN 5 SECONDS
  WidgetsFlutterBinding.ensureInitialized();
  
  if (service is AndroidServiceInstance) {
    service.setAsForegroundService();
    service.setForegroundNotificationInfo(
      title: 'Aeternum Agent',
      content: 'Watching Google Classroom…',
    );
  }

  // 2. State & Firebase initialization for the background isolate
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await Hive.initFlutter();
  await ClassroomState.ensureOpen();

  final notifPlugin = FlutterLocalNotificationsPlugin();
  final messaging = FirebaseMessaging.instance;

  // 3. Register for Push Notifications via OneSignal Tag
  await OneSignalService().addTag('topic', 'classroom_updates');
  
  // Listen for real-time refresh signals from Firebase Functions
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    debugPrint('🔔 AgentMonitor: Received FCM Push! Refreshing cache...');
    _pollClassroom(notifPlugin);
  });
  
  // 3. Auth initialization AFTER notification is stable
  try {
    debugPrint('AgentMonitor: Initializing authentication...');
    final svc = ClassroomService();
    await svc.fetchCourses(); 
  } catch (e) {
    debugPrint('AgentMonitor: Background auth failure: $e');
  }

  // 4. Notification channel setup
  const channel = AndroidNotificationChannel(
    _kChannelId, _kChannelName,
    description: 'Monitors Google Classroom',
    importance: Importance.high,
  );
  await notifPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);
  
  await notifPlugin.initialize(
    const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    ),
  );

  // 4. Robust polling loop (more resilient than Timer on aggressive OS variants)
  bool isRunning = true;
  service.on('stopService').listen((_) {
    isRunning = false;
    service.stopSelf();
  });

  debugPrint('✅ AgentMonitor: Starting hardened polling loop (Hybrid Mode)');
  while (isRunning) {
    try {
      await _pollClassroom(notifPlugin);
    } catch (e) {
      debugPrint('AgentMonitor Loop Error: $e');
    }
    
    // In Push Mode, we only need to poll infrequently to renew registrations
    // or as a safety net. Every 6 hours is enough for "maintenance".
    // 6 hours = 360 minutes.
    for (int i = 0; i < 360 && isRunning; i++) {
      await Future.delayed(const Duration(minutes: 1));
    }
  }
}


// ── Core polling logic ────────────────────────────────────────────────────────
Future<void> _pollClassroom(FlutterLocalNotificationsPlugin notifPlugin) async {
  try {
    final svc = ClassroomService();
    final courses = await svc.fetchCourses();
    if (courses.isEmpty) {
      debugPrint('AgentMonitor: no courses found (not signed in or no Classroom access)');
      return;
    }

    // Cache course names and prepare assignment map for global caching
    final nameMap = <String, String>{};
    final allAssignmentsMap = <String, List<ClassroomAssignment>>{};

    for (final c in courses) {
      if (c.id != null && c.name != null) {
        nameMap[c.id!] = c.name!;
        // ── Push Registration Renewal ──────────────────────────
        // Google registrations expire in 7 days. We renew them during sync.
        await svc.registerForPushNotifications(c.id!);
      }
    }
    await ClassroomState.setCourseNames(nameMap);

    int notifId = 1000;
    for (final course in courses) {
      final courseId = course.id ?? '';
      if (courseId.isEmpty) continue;
      final courseName = course.name ?? 'Unknown Course';

      // ── New assignments ────────────────────────────────────────
      final assignments = await svc.fetchCoursework(courseId);
      allAssignmentsMap[courseId] = assignments;

      final seenAssign = ClassroomState.getSeenAssignmentIds(courseId);
      final newAssign = assignments.where((a) => !seenAssign.contains(a.id)).toList();

      for (final a in newAssign) {
        await notifPlugin.show(
          notifId++,
          '📚 New assignment — $courseName',
          a.title,
          NotificationDetails(
            android: AndroidNotificationDetails(
              _kChannelId, _kChannelName,
              importance: Importance.high,
              priority: Priority.high,
            ),
          ),
        );
      }
      if (newAssign.isNotEmpty) {
        await ClassroomState.markAssignmentsSeen(
          courseId,
          {...seenAssign, ...newAssign.map((a) => a.id)},
        );
      }

      // ── New announcements ──────────────────────────────────────
      final announcements = await svc.fetchAnnouncements(courseId);
      final seenAnn = ClassroomState.getSeenAnnouncementIds(courseId);
      final newAnn = announcements.where((a) => !seenAnn.contains(a.id)).toList();

      for (final a in newAnn) {
        final preview = a.text.length > 80 ? '${a.text.substring(0, 80)}…' : a.text;
        await notifPlugin.show(
          notifId++,
          '📢 Announcement — $courseName',
          preview,
          NotificationDetails(
            android: AndroidNotificationDetails(
              _kChannelId, _kChannelName,
              importance: Importance.high,
              priority: Priority.high,
            ),
          ),
        );
      }
      if (newAnn.isNotEmpty) {
        await ClassroomState.markAnnouncementsSeen(
          courseId,
          {...seenAnn, ...newAnn.map((a) => a.id)},
        );
      }
    }

    // Update global assignment cache for UI
    if (allAssignmentsMap.isNotEmpty) {
      await ClassroomState.setAssignments(allAssignmentsMap);
    }

    await ClassroomState.setLastSyncTime(DateTime.now().toIso8601String());
    debugPrint('✅ AgentMonitor: poll complete — ${courses.length} course(s) scanned');
  } catch (e) {
    debugPrint('❌ AgentMonitor._pollClassroom error: $e');
  }
}

// ── iOS background handler (required by IosConfiguration) ────────────────────
@pragma('vm:entry-point')
Future<bool> _onIosBackground(ServiceInstance service) async => true;


// ── Public API ────────────────────────────────────────────────────────────────

/// Entry point for configuring and controlling the Classroom background monitor.
/// Call [ClassroomMonitor.initialize()] once from main(), then
/// [ClassroomMonitor.start()] / [ClassroomMonitor.stop()] from the Agent UI.
class ClassroomMonitor {
  ClassroomMonitor._();

  static final _service = FlutterBackgroundService();

  /// Creates the agent notification channel in the main isolate.
  /// Must run before configure() so Android can attach the foreground
  /// notification to a valid channel on API 33+.
  static Future<void> _ensureChannelExists() async {
    final notifPlugin = FlutterLocalNotificationsPlugin();
    await notifPlugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    const channel = AndroidNotificationChannel(
      _kChannelId,
      _kChannelName,
      description: 'Monitors Google Classroom for new assignments',
      importance: Importance.high,
    );
    await notifPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
    debugPrint('✅ ClassroomMonitor: notification channel ensured');
  }

  /// Registers the background service configuration.
  /// Must be called before [start()]. Call once in main() after Hive init.
  static Future<void> initialize() async {
    await _ensureChannelExists();
    await _service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onAgentServiceStart,
        autoStart: true,
        autoStartOnBoot: true,
        isForegroundMode: true,
        notificationChannelId: _kChannelId,
        initialNotificationTitle: 'Aeternum Agent',
        initialNotificationContent: 'Initializing…',
        foregroundServiceNotificationId: _kForegroundNotifId,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: true,
        onForeground: onAgentServiceStart,
        onBackground: _onIosBackground,
      ),
    );
    debugPrint('✅ ClassroomMonitor configured');
  }

  static Future<void> start() async {
    final running = await _service.isRunning();
    if (!running) {
      await _service.startService();
      debugPrint('✅ ClassroomMonitor started');
    }
  }

  static Future<void> stop() async {
    _service.invoke('stopService');
    debugPrint('🛑 ClassroomMonitor stop requested');
  }

  static Future<bool> isRunning() => _service.isRunning();
}
