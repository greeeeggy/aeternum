import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:menstrual_cycle_widget/menstrual_cycle_widget.dart';

import 'firebase_options.dart';
import 'screens/login_page.dart';
import 'screens/role_selection_page.dart';
import 'screens/onboarding_page.dart';
import 'screens/set_special_dates_page.dart';
import 'screens/tracker/full_period_tracker_page.dart';

// NEW imports for navigation structure
import 'screens/root_screen.dart';

import 'package:intl/date_symbol_data_local.dart';

import 'screens/tracker/symptom_sync_service.dart';
import 'services/version_service.dart';
import 'screens/update_required_screen.dart';

// AUDIO SERVICE IMPORTS
import 'package:audio_service/audio_service.dart';
import 'features/music_audio_service.dart';

// AGENT IMPORTS
import 'package:hive_flutter/hive_flutter.dart';
import 'agent/classroom/classroom_state.dart';
import 'agent/classroom/classroom_monitor.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'services/onesignal_service.dart';
import 'class_schedule/notification_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint("📩 Background message received: ${message.messageId}");
}

const String _secretKeyStorageKey = 'mc_widget_secret_key';
const String _ivKeyStorageKey = 'mc_widget_iv_key';

/// Initializes MenstrualCycleWidget before any page builds.
/// This ensures getCustomerId() never returns null/'0' during sync.
Future<void> _initMenstrualCycleWidget() async {
  const storage = FlutterSecureStorage();
  String? secretKey = await storage.read(key: _secretKeyStorageKey);
  String? ivKey = await storage.read(key: _ivKeyStorageKey);

  if (secretKey == null || ivKey == null) {
    final key = encrypt.Key.fromSecureRandom(32);
    final iv = encrypt.IV.fromSecureRandom(16);
    secretKey = key.base64;
    ivKey = iv.base64;
    await storage.write(key: _secretKeyStorageKey, value: secretKey);
    await storage.write(key: _ivKeyStorageKey, value: ivKey);
  }

  MenstrualCycleWidget.init(secretKey: secretKey, ivKey: ivKey);
  debugPrint('✅ MenstrualCycleWidget initialized in main()');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load environment variables for security
  await dotenv.load(fileName: ".env");

  await initializeDateFormatting();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Initialize MenstrualCycleWidget here so getCustomerId() is always valid
  // before BoyfriendPeriodViewerPage syncs data into SQLite.
  await _initMenstrualCycleWidget();

  // ── Hive & Agent background service ─────────────────────────────────────
  await Hive.initFlutter();
  await ClassroomState.ensureOpen();
  await ClassroomMonitor.initialize();
  await OneSignalService().init();
  await NotificationService().initialize();
  // ────────────────────────────────────────────────────────────────────────

  FirebaseFirestore.instance.settings = const Settings(persistenceEnabled: true);

  if (kIsWeb) {
    await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
  }

  if (!kIsWeb) {
    try {
      debugPrint('🎵 Starting Audio Service initialization...');

      final audioHandler = await AudioService.init(
        builder: () {
          debugPrint('🎵 Creating AudioPlayerHandler...');
          return AudioPlayerHandler();
        },
        config: const AudioServiceConfig(
          androidNotificationChannelId: 'com.aeternum.audio',
          androidNotificationChannelName: 'Music Playback',
          androidNotificationOngoing: true,
          androidShowNotificationBadge: true,
          androidNotificationIcon: 'mipmap/ic_launcher',
          fastForwardInterval: Duration(seconds: 10),
          rewindInterval: Duration(seconds: 10),
        ),
      );

      final musicService = MusicAudioService();
      await musicService.initialize(audioHandler);

      debugPrint('✅ Audio Service initialized successfully');


    } catch (e) {
      debugPrint('❌ Audio Service initialization error: $e');
    }
  } else {
    debugPrint('🌐 Web platform - Audio Service skipped');
  }

  runApp(const InitialConfigGate(child: AeternumApp()));
}

class InitialConfigGate extends StatefulWidget {
  final Widget child;
  const InitialConfigGate({super.key, required this.child});

  @override
  State<InitialConfigGate> createState() => _InitialConfigGateState();
}

class _InitialConfigGateState extends State<InitialConfigGate> {
  bool _isChecking = true;
  VersionInfo? _updateInfo;

  @override
  void initState() {
    super.initState();
    _performStartupCheck();
  }

  Future<void> _performStartupCheck() async {
    try {
      final versionService = VersionService();
      final info = await versionService.checkForUpdates();
      
      if (mounted) {
        setState(() {
          if (info != null && info.isUpdateAvailable) {
            _updateInfo = info;
          }
          _isChecking = false;
        });
      }
    } catch (e) {
      debugPrint('Startup check failed: $e');
      if (mounted) {
        setState(() => _isChecking = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // If still checking, show a minimal themed loading state
    if (_isChecking) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: const Color(0xFFFBF8F8),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(color: Colors.pink),
                const SizedBox(height: 24),
                Text(
                  'Aeternum is checking for updates...',
                  style: TextStyle(color: Colors.pink.shade300, fontSize: 16),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // If an update is available, show the update screen with skip option
    if (_updateInfo != null) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: UpdateRequiredScreen(
          version: _updateInfo!.latestVersion,
          releaseNotes: _updateInfo!.releaseNotes,
          downloadUrl: _updateInfo!.downloadUrl,
          onSkip: () {
            setState(() {
              _updateInfo = null;
            });
          },
        ),
      );
    }

    // Otherwise, proceed to the main app
    return widget.child;
  }
}

class AeternumApp extends StatelessWidget {
  const AeternumApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Aeternum',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.pink,
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.pink),
        scaffoldBackgroundColor: const Color(0xFFFBF8F8),
        extensions: <ThemeExtension<dynamic>>[
          PeriodTrackerTheme(
            selectedColor: Colors.pink,
            selectedTextColor: Colors.white,
            todayTextColor: Colors.pink,
          ),
        ],
      ),
      home: const AuthWrapper(),
      routes: {
        '/login': (context) => const LoginPage(),
        '/role_selection': (context) => const RoleSelectionPage(),
        '/onboarding': (context) => const OnboardingPage(),
        '/set_special_dates': (context) => const SetSpecialDatesPage(),
        '/home': (context) => const RootScreen(),
        '/period_tracker': (context) => const FullPeriodTrackerPage(),
      },
    );
  }
}

// Custom theme for period tracker (unchanged)
class PeriodTrackerTheme extends ThemeExtension<PeriodTrackerTheme> {
  final Color selectedColor;
  final Color selectedTextColor;
  final Color todayTextColor;

  const PeriodTrackerTheme({
    required this.selectedColor,
    required this.selectedTextColor,
    required this.todayTextColor,
  });

  @override
  ThemeExtension<PeriodTrackerTheme> copyWith({
    Color? selectedColor,
    Color? selectedTextColor,
    Color? todayTextColor,
  }) {
    return PeriodTrackerTheme(
      selectedColor: selectedColor ?? this.selectedColor,
      selectedTextColor: selectedTextColor ?? this.selectedTextColor,
      todayTextColor: todayTextColor ?? this.todayTextColor,
    );
  }

  @override
  ThemeExtension<PeriodTrackerTheme> lerp(
      ThemeExtension<PeriodTrackerTheme>? other,
      double t,
      ) {
    if (other is! PeriodTrackerTheme) return this;
    return PeriodTrackerTheme(
      selectedColor: Color.lerp(selectedColor, other.selectedColor, t)!,
      selectedTextColor: Color.lerp(selectedTextColor, other.selectedTextColor, t)!,
      todayTextColor: Color.lerp(todayTextColor, other.todayTextColor, t)!,
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  Future<bool> _needsRole(User user) async {
    await Future.delayed(const Duration(milliseconds: 100));
    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    return doc.data()?['role'] == null;
  }

  Future<bool> _needsOnboard(User user) async {
    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final nicknames = doc.data()?['nicknames'] as List<dynamic>? ?? [];
    return nicknames.isEmpty;
  }

  Future<bool> _needsDates(User user) async {
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final pairId = userDoc.data()?['pairId'] as String?;
    if (pairId == null) return true;

    final coupleDoc = await FirebaseFirestore.instance.collection('couples').doc(pairId).get();
    return coupleDoc.data()?['anniversaryDate'] == null;
  }

  Future<void> _initializePeriodTracker(User user) async {
    await SymptomSyncService().initialize();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final user = authSnapshot.data;
        if (user == null) {
          return const LoginPage();
        }

        // Fire-and-forget initialization
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          await _initializePeriodTracker(user);
        });

        return FutureBuilder<bool>(
          future: _needsRole(user),
          builder: (context, roleSnap) {
            if (!roleSnap.hasData) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }
            if (roleSnap.data!) {
              return const RoleSelectionPage();
            }

            return FutureBuilder<bool>(
              future: _needsOnboard(user),
              builder: (context, onboardSnap) {
                if (!onboardSnap.hasData) {
                  return const Scaffold(body: Center(child: CircularProgressIndicator()));
                }
                if (onboardSnap.data!) {
                  return const OnboardingPage();
                }

                return FutureBuilder<bool>(
                  future: _needsDates(user),
                  builder: (context, datesSnap) {
                    if (!datesSnap.hasData) {
                      return const Scaffold(body: Center(child: CircularProgressIndicator()));
                    }
                    return datesSnap.data!
                        ? const RootScreen()
                        : const RootScreen();
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}