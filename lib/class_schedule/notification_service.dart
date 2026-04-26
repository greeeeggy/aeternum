// lib/class_schedule/notification_service.dart
// CORRECTED VERSION - Fires at EXACT times (8:30, 8:45, 8:55 for a 9:00 class)
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tzdata;
import 'class_model.dart';
import '../study_planner/study_event_model.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/onesignal_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  static const platform = MethodChannel('com.aeternum.notifications/battery');
  bool _isInitialized = false;

  Future<void> initialize() async {
    try {
      debugPrint('🔔 Starting BULLETPROOF notification initialization...');

      tzdata.initializeTimeZones();
      debugPrint('✅ Timezones initialized');

      // TODO: Change this to your timezone if not in Philippines
      // Examples: 'America/New_York', 'Europe/London', 'Asia/Tokyo'
      tz.setLocalLocation(tz.getLocation('Asia/Manila'));
      debugPrint('✅ Timezone set to Asia/Manila');

      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      final initialized = await _notifications.initialize(initSettings);
      debugPrint('✅ Notification plugin initialized: $initialized');

      if (initialized == true) {
        final androidPlugin = _notifications
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

        if (androidPlugin != null) {
          final notificationPermission = await androidPlugin.requestNotificationsPermission();
          debugPrint('✅ Basic notification permission: $notificationPermission');

          final canScheduleExactAlarms = await androidPlugin.canScheduleExactNotifications();
          debugPrint('📱 Can schedule exact alarms: $canScheduleExactAlarms');

          if (canScheduleExactAlarms == false) {
            debugPrint('⚠️ EXACT ALARMS NOT ALLOWED - Requesting permission...');
            await androidPlugin.requestExactAlarmsPermission();
            debugPrint('⚠️ User must enable "Alarms & reminders" in system settings!');
          } else {
            debugPrint('✅ Exact alarms permission already granted');
          }

          await _requestBatteryOptimizationExemption();
        }

        _isInitialized = true;
        debugPrint('✅ NotificationService: Successfully initialized');
        debugPrint('🎯 Notifications will now fire at EXACT times!');
      } else {
        debugPrint('❌ NotificationService: Initialization returned false');
      }
    } catch (e) {
      debugPrint('❌ NotificationService: Failed to initialize - $e');
      _isInitialized = false;
    }
  }

  Future<void> _requestBatteryOptimizationExemption() async {
    try {
      final bool? isIgnoringBatteryOptimizations = await platform.invokeMethod('isIgnoringBatteryOptimizations');

      if (isIgnoringBatteryOptimizations == true) {
        debugPrint('✅ Battery optimization already disabled');
      } else {
        debugPrint('⚠️ Battery optimization is ON - Requesting exemption...');
        await platform.invokeMethod('requestIgnoreBatteryOptimizations');
        debugPrint('⚠️ User should allow app to run in background without restrictions');
      }
    } catch (e) {
      debugPrint('⚠️ Could not check/request battery optimization exemption: $e');
    }
  }

  Future<void> sendTestNotification() async {
    if (!_isInitialized) {
      debugPrint('❌ Cannot send test notification - not initialized');
      return;
    }

    try {
      await _notifications.show(
        999999,
        'Test Notification ✅',
        'Notifications are working! You should see class reminders 30min, 15min, and 5min before each class.',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'class_reminders',
            'Class Reminders',
            channelDescription: 'Notifications for upcoming classes',
            category: AndroidNotificationCategory.alarm,
            importance: Importance.max,
            priority: Priority.high,
            fullScreenIntent: true,
            audioAttributesUsage: AudioAttributesUsage.alarm,
          ),
          iOS: DarwinNotificationDetails(),
        ),
      );
      debugPrint('✅ Test notification sent successfully!');
    } catch (e) {
      debugPrint('❌ Test notification failed: $e');
    }
  }

  Future<void> debugPrintScheduledNotifications() async {
    if (!_isInitialized) {
      debugPrint('❌ Cannot list notifications - not initialized');
      return;
    }

    try {
      final pendingNotifications = await _notifications.pendingNotificationRequests();

      debugPrint('📋 ========== SCHEDULED NOTIFICATIONS ==========');
      debugPrint('📋 Total pending notifications: ${pendingNotifications.length}');

      for (final notification in pendingNotifications) {
        debugPrint('  📌 ID: ${notification.id}');
        debugPrint('     Title: ${notification.title}');
        debugPrint('     Body: ${notification.body}');
        debugPrint('  ---');
      }
      debugPrint('📋 ==============================================');
    } catch (e) {
      debugPrint('❌ Error listing notifications: $e');
    }
  }

  Future<void> scheduleAllClassNotifications(List<ClassSchedule> classes) async {
    if (!_isInitialized) {
      debugPrint('⚠️ NotificationService: Not initialized, skipping notification scheduling');
      return;
    }

    try {
      await _notifications.cancelAll();
      debugPrint('🗑️ Cancelled all previous notifications');

      int scheduledCount = 0;
      for (final classItem in classes) {
        final count = await _scheduleClassNotifications(classItem);
        scheduledCount += count;
      }

      debugPrint('✅ Scheduled $scheduledCount notifications for ${classes.length} classes');
      await debugPrintScheduledNotifications();
    } catch (e) {
      debugPrint('❌ Error scheduling notifications: $e');
    }
  }

  int _generateNotificationId(int dayOfWeek, int hour, int minute, int notificationType) {
    final day = dayOfWeek.clamp(0, 6);
    final hr = hour.clamp(0, 23);
    final min = minute.clamp(0, 59);
    final type = notificationType.clamp(1, 3);
    final id = (day * 100000) + (hr * 1000) + (min * 10) + type;
    return id;
  }

  Future<int> _scheduleClassNotifications(ClassSchedule classItem) async {
    if (!_isInitialized) return 0;

    try {
      if (classItem.conflictsWithLunch) {
        debugPrint('⏭️ Skipping ${classItem.subjectName} - conflicts with lunch');
        return 0;
      }

      final classStartHour = classItem.startTime.hour;
      final classStartMinute = classItem.startTime.minute;
      int notificationCount = 0;

      // ========== Schedule 3 separate notifications ==========

      // 30 minutes before
      final thirtyMinsBefore = _subtractMinutes(classStartHour, classStartMinute, 30);
      await _scheduleExactNotification(
        id: _generateNotificationId(
          classItem.dayOfWeek,
          thirtyMinsBefore['hour']!,
          thirtyMinsBefore['minute']!,
          1,
        ),
        day: classItem.dayOfWeek,
        hour: thirtyMinsBefore['hour']!,
        minute: thirtyMinsBefore['minute']!,
        title: 'Class in 30 Minutes',
        body: '${classItem.subjectName} with ${classItem.professorName} starts at ${classItem.getTimeRange().split(' - ')[0]}',
        className: classItem.subjectName,
      );
      notificationCount++;

      // 15 minutes before
      final fifteenMinsBefore = _subtractMinutes(classStartHour, classStartMinute, 15);
      await _scheduleExactNotification(
        id: _generateNotificationId(
          classItem.dayOfWeek,
          fifteenMinsBefore['hour']!,
          fifteenMinsBefore['minute']!,
          2,
        ),
        day: classItem.dayOfWeek,
        hour: fifteenMinsBefore['hour']!,
        minute: fifteenMinsBefore['minute']!,
        title: 'Class in 15 Minutes',
        body: '${classItem.subjectName} with ${classItem.professorName} starts at ${classItem.getTimeRange().split(' - ')[0]}',
        className: classItem.subjectName,
      );
      notificationCount++;

      // 5 minutes before
      final fiveMinsBefore = _subtractMinutes(classStartHour, classStartMinute, 5);
      await _scheduleExactNotification(
        id: _generateNotificationId(
          classItem.dayOfWeek,
          fiveMinsBefore['hour']!,
          fiveMinsBefore['minute']!,
          3,
        ),
        day: classItem.dayOfWeek,
        hour: fiveMinsBefore['hour']!,
        minute: fiveMinsBefore['minute']!,
        title: 'Class in 5 Minutes! 🔔',
        body: '${classItem.subjectName} with ${classItem.professorName} starts NOW at ${classItem.getTimeRange().split(' - ')[0]}',
        className: classItem.subjectName,
      );
      notificationCount++;

      return notificationCount;
    } catch (e) {
      debugPrint('❌ Error scheduling notifications for ${classItem.subjectName}: $e');
      return 0;
    }
  }

  Map<String, int> _subtractMinutes(int hour, int minute, int minutesToSubtract) {
    int newMinute = minute - minutesToSubtract;
    int newHour = hour;
    if (newMinute < 0) {
      newMinute += 60;
      newHour -= 1;
      if (newHour < 0) newHour += 24;
    }
    return {'hour': newHour, 'minute': newMinute};
  }

  /// Schedule a notification that repeats weekly at the EXACT time specified
  Future<void> _scheduleExactNotification({
    required int id,
    required int day,
    required int hour,
    required int minute,
    required String title,
    required String body,
    required String className,
  }) async {
    if (!_isInitialized) return;

    try {
      final now = tz.TZDateTime.now(tz.local);

      // Create the target time for TODAY
      var targetTime = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        hour,
        minute,
        0,
        0,
      );

      // Calculate which day of the week we need
      // now.weekday: Monday=1, Sunday=7
      // our day: Sunday=0, Monday=1, ..., Saturday=6
      int currentDayOfWeek = now.weekday % 7; // Convert to 0-6 where Sunday=0

      // Use ((x % 7) + 7) % 7 to guarantee a non-negative result in Dart
      int daysUntilTarget = ((day - currentDayOfWeek) % 7 + 7) % 7;

      // Calculate the actual scheduled date/time
      tz.TZDateTime scheduledDateTime = targetTime.add(Duration(days: daysUntilTarget));

      // If the computed fire time is already in the past (e.g. reminder window
      // already passed for today), advance by 7 days to the next weekly occurrence.
      if (scheduledDateTime.isBefore(now)) {
        scheduledDateTime = scheduledDateTime.add(const Duration(days: 7));
      }

      debugPrint('');
      debugPrint('🔔 Scheduling notification:');
      debugPrint('   Class: $className');
      debugPrint('   Notification: $title');
      debugPrint('   Target Day: ${_getDayName(day)}');
      debugPrint('   Target Time: ${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}');
      debugPrint('   Current Time: ${now.toString()}');
      debugPrint('   Scheduled For: ${scheduledDateTime.toString()}');
      debugPrint('   Days Until: $daysUntilTarget');
      debugPrint('   Notification ID: $id');

      // ========== KEY FIX: Use matchDateTimeComponents for weekly repeat ==========
      await _notifications.zonedSchedule(
        id,
        title,
        body,
        scheduledDateTime,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'class_reminders',
            'Class Reminders',
            channelDescription: 'Notifications for upcoming classes',
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
            channelShowBadge: true,
            visibility: NotificationVisibility.public,
            fullScreenIntent: true,
            category: AndroidNotificationCategory.alarm,
            audioAttributesUsage: AudioAttributesUsage.alarm,
            styleInformation: BigTextStyleInformation(body),
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        // matchDateTimeComponents removed — the app reschedules on every launch/sync,
        // so OS-level weekly repeat is unnecessary and causes timing drift.
      );

      debugPrint('✅ Notification scheduled successfully!');
      
      // NEW: Schedule OneSignal Push Notification as a secondary reminder
      _scheduleOneSignalPush(scheduledDateTime, title, body);

      debugPrint('');
    } catch (e) {
      debugPrint('❌ Error scheduling notification ID $id: $e');
    }
  }

  String _getDayName(int day) {
    const days = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
    return days[day % 7];
  }

  Future<void> cancelAllNotifications() async {
    if (!_isInitialized) return;

    try {
      await _notifications.cancelAll();
      debugPrint('✅ Cancelled all notifications');
    } catch (e) {
      debugPrint('❌ Error cancelling notifications: $e');
    }
  }

  // ── Study Planner Notifications ──────────────────────────────────────────

  Future<void> scheduleStudyEventNotifications(StudyEvent event) async {
    if (!_isInitialized || event.firestoreId == null) return;

    // Cancel existing notifications for this event first
    await cancelStudyEventNotifications(event);

    if (event.isDone) return; // Don't schedule if done

    final now = DateTime.now();
    final deadline = event.date;

    // Only for Deadline, Exam, Submission
    if (event.type == StudyEventType.busy) return;

    // Schedule 3 days before
    final threeDaysBefore = deadline.subtract(const Duration(days: 3));
    if (threeDaysBefore.isAfter(now)) {
      await _scheduleDateNotification(
        id: event.firestoreId.hashCode + 3,
        scheduledDate: threeDaysBefore,
        title: 'Study Reminder: 3 Days Left',
        body: '${event.title} is due in 3 days! (${event.type.label})',
      );
    }

    // Schedule 1 day before
    final oneDayBefore = deadline.subtract(const Duration(days: 1));
    if (oneDayBefore.isAfter(now)) {
      await _scheduleDateNotification(
        id: event.firestoreId.hashCode + 1,
        scheduledDate: oneDayBefore,
        title: 'Study Reminder: Tomorrow!',
        body: '${event.title} is due tomorrow. Don\'t forget!',
      );
    }
  }

  Future<void> cancelStudyEventNotifications(StudyEvent event) async {
    if (!_isInitialized || event.firestoreId == null) return;
    final idBase = event.firestoreId.hashCode;
    await _notifications.cancel(idBase + 3);
    await _notifications.cancel(idBase + 1);
  }

  Future<void> _scheduleDateNotification({
    required int id,
    required DateTime scheduledDate,
    required String title,
    required String body,
  }) async {
    try {
      final scheduledTZ = tz.TZDateTime.from(scheduledDate, tz.local);
      
      await _notifications.zonedSchedule(
        id,
        title,
        body,
        scheduledTZ,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'study_reminders',
            'Study Reminders',
            channelDescription: 'Reminders for deadlines and exams',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      
      // NEW: Schedule OneSignal Push Notification as a secondary reminder
      _scheduleOneSignalPush(scheduledDate, title, body);

      debugPrint('✅ Scheduled Study Notification $id for $scheduledDate');
    } catch (e) {
      debugPrint('❌ Failed to schedule study notification: $e');
    }
  }

  Future<void> _scheduleOneSignalPush(DateTime scheduledTime, String title, String body) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      // We send it to the current user as a remote backup to local notifications
      await OneSignalService().sendNotification(
        targetExternalIds: [uid],
        title: title,
        content: body,
        sendAfter: scheduledTime,
        data: {'type': 'class_reminder'},
      );
    } catch (e) {
      debugPrint('⚠️ OneSignal push scheduling failed: $e');
    }
  }
}