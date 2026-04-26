// lib/screens/tracker/aero_ai_service.dart

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'cycle_analytics_service.dart';
import 'ai_context_builder.dart';
import 'symptom_database_helper.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Chat message model
// ─────────────────────────────────────────────────────────────────────────────

class AeroChatMessage {
  final String text;
  final bool isUser;
  final DateTime time;

  AeroChatMessage({
    required this.text,
    required this.isUser,
    DateTime? time,
  }) : time = time ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'text': text,
        'isUser': isUser,
        'time': time.millisecondsSinceEpoch,
      };

  factory AeroChatMessage.fromJson(Map<String, dynamic> json) =>
      AeroChatMessage(
        text: json['text'] as String,
        isUser: json['isUser'] as bool,
        time: DateTime.fromMillisecondsSinceEpoch(json['time'] as int),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Service  (singleton — lives for the app's lifetime)
// ─────────────────────────────────────────────────────────────────────────────

class AeroAiService {
  static final AeroAiService _instance = AeroAiService._internal();
  factory AeroAiService() => _instance;
  AeroAiService._internal();

  static String get _apiKey => dotenv.env['GROQ_API_KEY_AERO'] ?? "";
  static const String _apiUrl =
      'https://api.groq.com/openai/v1/chat/completions';
  static const String _prefsKey = 'aero_chat_messages';

  // Same model priority list as Eri
  final List<String> _modelPriority = [
    'openai/gpt-oss-120b',
    'llama-3.3-70b-versatile',
    'meta-llama/llama-4-maverick-17b-128e-instruct',
    'qwen/qwen3-32b',
    'moonshotai/kimi-k2-instruct',
    'meta-llama/llama-4-scout-17b-16e-instruct',
    'groq/compound',
    'llama-3.1-8b-instant',
    'canopylabs/orpheus-v1-english',
    'allam-2-7b',
  ];
  int _currentModelIndex = 0;

  // ── Persistent message list ─────────────────────────────────────────────────
  final List<AeroChatMessage> messages = [];
  bool _messagesLoaded = false;

  // Groq conversation history (in-memory only)
  final List<Map<String, String>> _history = [];
  static const int _maxHistoryTurns = 12;

  // Cycle context cache
  String? _cachedSystemContext;
  bool _isBuilding = false;

  // ── Public API ──────────────────────────────────────────────────────────────

  bool get isContextReady => _cachedSystemContext != null;

  /// Loads persisted messages from SharedPreferences.
  Future<void> loadMessages() async {
    if (_messagesLoaded) return;
    _messagesLoaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw != null && raw.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
        messages.clear();
        for (final item in decoded) {
          messages.add(AeroChatMessage.fromJson(item as Map<String, dynamic>));
        }
        _rebuildHistory();
      }
    } catch (e) {
      debugPrint('Aero: failed to load persisted messages: $e');
    }
  }

  /// Pre-builds cycle analytics context. Call before first message.
  Future<void> buildContext() async {
    if (_cachedSystemContext != null || _isBuilding) return;
    _isBuilding = true;
    try {
      final analytics = await CycleAnalyticsService().buildAnalytics();
      final recentLogs =
          await SymptomDatabaseHelper.instance.getAllLogs(limit: 10);
      final latestLogs = recentLogs.take(7).toList();
      final cycleContext = AiContextBuilder.build(analytics);
      final recentContext = AiContextBuilder.buildRecentLogsSnippet(latestLogs);
      _cachedSystemContext = _buildSystemPrompt(cycleContext, recentContext);
    } finally {
      _isBuilding = false;
    }
  }

  /// Sends [userMessage], appends both turns to [messages], persists them,
  /// and returns the assistant reply string.
  Future<String> sendMessage(String userMessage) async {
    if (_cachedSystemContext == null) await buildContext();

    final userMsg = AeroChatMessage(text: userMessage.trim(), isUser: true);
    messages.add(userMsg);
    _history.add({'role': 'user', 'content': userMessage.trim()});
    await _persist();

    final apiMessages = <Map<String, dynamic>>[
      {'role': 'system', 'content': _cachedSystemContext!},
      ...(_history.length > _maxHistoryTurns
          ? _history.sublist(_history.length - _maxHistoryTurns)
          : List<Map<String, String>>.from(_history)),
    ];

    String? reply;
    for (int attempt = 0; attempt < _modelPriority.length; attempt++) {
      final idx = (_currentModelIndex + attempt) % _modelPriority.length;
      final model = _modelPriority[idx];
      try {
        final response = await http
            .post(
              Uri.parse(_apiUrl),
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $_apiKey',
              },
              body: jsonEncode({
                'model': model,
                'messages': apiMessages,
                'temperature': 0.65,
                'max_tokens': 1024,
                'top_p': 1,
                'stream': false,
              }),
            )
            .timeout(const Duration(seconds: 20));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          reply = data['choices']?[0]?['message']?['content'] as String?;
          if (reply != null && reply.isNotEmpty) {
            _currentModelIndex = idx;
            break;
          }
        } else if (response.statusCode == 429 || response.statusCode == 400) {
          continue;
        }
      } catch (_) {
        continue;
      }
    }

    final assistantText = reply ??
        "Having a little trouble connecting right now. Try again in a sec.";

    final assistantMsg = AeroChatMessage(text: assistantText, isUser: false);
    messages.add(assistantMsg);
    _history.add({'role': 'assistant', 'content': assistantText});
    await _persist();

    return assistantText;
  }

  /// Clears all messages + history + context.
  Future<void> resetConversation() async {
    messages.clear();
    _history.clear();
    _cachedSystemContext = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsKey);
    } catch (_) {}
  }

  /// Invalidates cached context so it rebuilds on next use.
  void invalidateContext() {
    _cachedSystemContext = null;
  }

  // ── Private helpers ─────────────────────────────────────────────────────────

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(messages.map((m) => m.toJson()).toList());
      await prefs.setString(_prefsKey, encoded);
    } catch (e) {
      debugPrint('Aero: failed to persist messages: $e');
    }
  }

  void _rebuildHistory() {
    _history.clear();
    final relevant = messages.length > _maxHistoryTurns
        ? messages.sublist(messages.length - _maxHistoryTurns)
        : messages;
    for (final m in relevant) {
      _history.add({
        'role': m.isUser ? 'user' : 'assistant',
        'content': m.text,
      });
    }
  }

  // ── System prompt ──────────────────────────────────────────────────────────

  String _buildSystemPrompt(String cycleContext, String recentContext) {
    return '''
✅ SYSTEM INSTRUCTIONS — AERO (Partner Cycle Assistant)

You are Aero, a knowledgeable and chill AI assistant built specifically for boyfriends and male partners. Your job is to help the user understand their girlfriend\'s menstrual cycle, what she might be going through at any point, and how to be the best possible support for her.

1. Identity
When asked "Who are you?" or similar questions about identity, respond clearly:
"I\'m Aero, your personal cycle assistant. I\'m here to help you understand what your girlfriend\'s body is going through and how you can show up for her."
Do not claim to be a doctor or medical professional.
Do not invent affiliations.

2. Tone and Style
Aero\'s personality: straightforward, friendly, like a knowledgeable buddy who just happens to know a lot about this stuff.
Talk to the user like a friend — not robotic, not overly clinical. Plain language. Real talk.
Be real and direct. The user is a guy trying to understand and support his girlfriend — meet him where he is.
Do NOT be condescending or lecture him. Be a helpful wingman.
Avoid emojis unless the user uses them first.
Never judge or shame the user for not knowing something.

3. Scope of Assistance
You may help with: explaining what phase of the cycle the girlfriend is in and what that means for her mood/energy/body, PMS explanations in plain terms, how to be supportive during different cycle phases, what symptoms mean and why they happen, how to communicate better during tough cycle days, what foods or gestures might help, general cycle education from a partner\'s perspective, ovulation and cycle timing basics.
Politely redirect questions that have nothing to do with supporting a partner through their cycle.

4. Referring to the Cycle Data
Always refer to the cycle data as "your girlfriend\'s cycle" or "her cycle."
Use the synced data to give accurate, personalized insight.
When data is limited, acknowledge it honestly — don\'t guess or fabricate.

5. Medical Safety Boundaries
Include a gentle heads-up when relevant: "If she\'s dealing with something severe or unusual, it\'s worth seeing a doctor."
Do NOT diagnose conditions, prescribe meds, or replace medical care.
If the user describes alarming symptoms (extreme pain, very heavy bleeding, fainting, etc.) — take it seriously, be supportive, and recommend she see a healthcare professional.

6. Response Structure
Answer directly and clearly. Keep it conversational.
Lead with the most useful info, then explain the "why" if helpful.
Keep responses concise unless the user asks for more detail.
Never be preachy. One light safety note is fine if health is involved. Don\'t repeat it.

7. Accuracy Rules
If unsure: say so. Don\'t guess. Suggest she consult a doctor for anything medical.
Never fabricate stats or studies.

8. Refusal Rules
Don\'t provide medication dosages, diagnoses, or harmful guidance. Redirect to a doctor.

9. Personality Consistency
Aero is always: calm, confident, helpful, no-nonsense, supportive without being over the top.
Aero doesn\'t change tone based on user frustration.

10. Using the Provided Cycle Data
You have been given the girlfriend\'s actual logged cycle and symptom data below.
Use this to give real, personalized answers.
Absence of a logged symptom does NOT mean she didn\'t experience it.

=== GIRLFRIEND\'S CYCLE DATA ===

$cycleContext

$recentContext
''';
  }
}
