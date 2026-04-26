import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class OneSignalService {
  static final OneSignalService _instance = OneSignalService._internal();
  factory OneSignalService() => _instance;
  OneSignalService._internal();

  // Loaded from .env for security
  static String get appId => dotenv.env['ONESIGNAL_APP_ID'] ?? "43a5ac61-b9a0-426d-aa7f-40fbba37cde0";
  static String get restApiKey => dotenv.env['ONESIGNAL_REST_API_KEY'] ?? "";

  Future<void> init() async {
    if (kIsWeb) return;

    // Remove this for production
    OneSignal.Debug.setLogLevel(OSLogLevel.verbose);

    OneSignal.initialize(appId);

    // The promptForPushNotificationsWithUserResponse function will show the iOS or Android push notification prompt. 
    // We recommend removing the following code and instead using an In-App Message to prompt for notification permission
    OneSignal.Notifications.requestPermission(true);

    debugPrint("✅ OneSignal Initialized");
  }

  void login(String uid) {
    if (kIsWeb) return;
    OneSignal.login(uid);
    debugPrint("✅ OneSignal: Logged in as $uid");
  }

  void logout() {
    if (kIsWeb) return;
    OneSignal.logout();
    debugPrint("✅ OneSignal: Logged out");
  }

  Future<void> addTag(String key, String value) async {
    if (kIsWeb) return;
    OneSignal.User.addTagWithKey(key, value);
    debugPrint("✅ OneSignal Tag Added: $key = $value");
  }

  Future<void> removeTag(String key) async {
    if (kIsWeb) return;
    OneSignal.User.removeTag(key);
    debugPrint("✅ OneSignal Tag Removed: $key");
  }

  /// Sends a push notification via OneSignal REST API.
  Future<void> sendNotification({
    required List<String> targetExternalIds,
    required String title,
    required String content,
    DateTime? sendAfter,
    Map<String, dynamic>? data,
  }) async {
    if (kIsWeb) return;

    if (restApiKey.isEmpty) {
      debugPrint("⚠️ OneSignal: REST API Key not set in .env. Notification not sent.");
      return;
    }

    try {
      // OneSignal expects format: "2022-01-01 12:00:00 GMT-0500" or ISO 8601
      String? sendAfterStr;
      if (sendAfter != null) {
        // Simple ISO format, OneSignal usually accepts it or requires GMT offset
        sendAfterStr = sendAfter.toUtc().toString();
      }

      final response = await http.post(
        Uri.parse('https://onesignal.com/api/v1/notifications'),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Authorization': 'Basic $restApiKey',
        },
        body: jsonEncode({
          'app_id': appId,
          'include_external_user_ids': targetExternalIds,
          'headings': {'en': title},
          'contents': {'en': content},
          if (sendAfterStr != null) 'send_after': sendAfterStr,
          if (data != null) 'data': data,
        }),
      );

      if (response.statusCode == 200) {
        debugPrint("✅ OneSignal: Notification sent/scheduled to $targetExternalIds ${sendAfter != null ? 'for $sendAfter' : ''}");
      } else {
        debugPrint("❌ OneSignal: Failed to send notification: ${response.body}");
      }
    } catch (e) {
      debugPrint("❌ OneSignal: Error sending notification: $e");
    }
  }
}
