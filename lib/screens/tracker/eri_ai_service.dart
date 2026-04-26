// lib/screens/tracker/eri_ai_service.dart

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

class EriChatMessage {
  final String text;
  final bool isUser;
  final DateTime time;

  EriChatMessage({
    required this.text,
    required this.isUser,
    DateTime? time,
  }) : time = time ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'text': text,
        'isUser': isUser,
        'time': time.millisecondsSinceEpoch,
      };

  factory EriChatMessage.fromJson(Map<String, dynamic> json) => EriChatMessage(
        text: json['text'] as String,
        isUser: json['isUser'] as bool,
        time: DateTime.fromMillisecondsSinceEpoch(json['time'] as int),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Service  (singleton — lives for the app's lifetime)
// ─────────────────────────────────────────────────────────────────────────────

class EriAiService {
  static final EriAiService _instance = EriAiService._internal();
  factory EriAiService() => _instance;
  EriAiService._internal();

  static String get _apiKey => dotenv.env['GROQ_API_KEY_ERI'] ?? "";
  static const String _apiUrl =
      'https://api.groq.com/openai/v1/chat/completions';
  static const String _prefsKey = 'eri_chat_messages';

  // Model priority — first is default, falls through on 429 / exhaustion
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
  // Loaded from SharedPreferences on first access; written after every message.
  final List<EriChatMessage> messages = [];
  bool _messagesLoaded = false;

  // Groq conversation history (in-memory only — reconstructed from messages)
  final List<Map<String, String>> _history = [];
  static const int _maxHistoryTurns = 12;

  // Cycle context cache
  String? _cachedSystemContext;
  bool _isBuilding = false;

  // ── Public API ──────────────────────────────────────────────────────────────

  bool get isContextReady => _cachedSystemContext != null;

  /// Loads persisted messages from SharedPreferences.
  /// Must be awaited before reading [messages] in the UI.
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
          messages.add(EriChatMessage.fromJson(item as Map<String, dynamic>));
        }
        // Reconstruct history for the API from loaded messages
        _rebuildHistory();
      }
    } catch (e) {
      debugPrint('Eri: failed to load persisted messages: $e');
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
  Future<String> sendMessage(
    String userMessage, {
    bool isBoyfriend = false,
  }) async {
    if (_cachedSystemContext == null) await buildContext();

    final userMsg = EriChatMessage(text: userMessage.trim(), isUser: true);
    messages.add(userMsg);
    _history.add({'role': 'user', 'content': userMessage.trim()});
    await _persist();

    // Build API payload
    final apiMessages = <Map<String, dynamic>>[
      {
        'role': 'system',
        'content': isBoyfriend
            ? _buildBoyfriendSystemPrompt(_cachedSystemContext!)
            : _cachedSystemContext!,
      },
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
        "I'm having a little trouble connecting right now. Please try again in a moment.";

    final assistantMsg = EriChatMessage(text: assistantText, isUser: false);
    messages.add(assistantMsg);
    _history.add({'role': 'assistant', 'content': assistantText});
    await _persist();

    return assistantText;
  }

  /// Clears all messages + history + context. Called by the reload button.
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
      debugPrint('Eri: failed to persist messages: $e');
    }
  }

  /// Rebuilds the Groq history list from the loaded message log.
  void _rebuildHistory() {
    _history.clear();
    // Only include the last _maxHistoryTurns messages for the API
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

  // ── System prompts ──────────────────────────────────────────────────────────

  String _buildSystemPrompt(String cycleContext, String recentContext) {
    return '''
✅ SYSTEM INSTRUCTIONS — ERI (Period Assistant)

You are Eri, a supportive and educational AI Period Assistant.

1. Identity
When asked "Who are you?" or similar questions about identity, respond clearly:
"I am Eri, your personal AI Period Assistant. I'm here to help you understand your menstrual cycle, symptoms, and reproductive health in a supportive and educational way."
Do not claim to be a doctor, medical professional, or licensed healthcare provider.
Do not invent affiliations.

2. Scope of Assistance
You may help with: menstrual cycle education, period tracking explanations, ovulation basics, PMS explanations, hormonal phase education, symptom discussion (mild to moderate), general reproductive health education, lifestyle tips related to menstrual wellness, emotional support related to periods.
You may explain concepts clearly and simply.
You may rephrase medical information in user-friendly language.
Politely redirect any questions unrelated to menstrual or reproductive health by saying you are specialized for period-related topics only.

3. Medical Safety Boundaries
You must include a gentle disclaimer when giving health-related advice: "If symptoms are severe or unusual, it\'s best to consult a healthcare professional."
You must NOT: diagnose medical conditions, prescribe medication, provide dosage instructions, replace professional medical care, or provide emergency medical instructions.
If the user describes severe pain, fainting, heavy bleeding (soaking pad/tampon hourly), pregnancy complications, suicidal thoughts, or medical emergencies — respond with supportive language and strongly encourage seeking immediate medical care.

4. Tone and Style
Eri should be: warm, calm, supportive, non-judgmental, informative but simple.
Never dramatic. Never overly clinical.
Avoid emojis unless the user uses them first.
Avoid slang. Avoid moral judgment.

5. Data Sensitivity
Treat menstrual data as sensitive health information.
Do not ask for unnecessary personal details.
Only ask clarifying questions when medically relevant.

6. Response Structure
When answering: start with a direct answer, then provide a short explanation, then optional supportive guidance, end with a light safety reminder if health-related.
Keep responses concise unless the user asks for detailed explanation.

7. Accuracy Rules
If unsure about a medical claim: say you are not certain, avoid guessing, suggest consulting a healthcare professional.
Never fabricate statistics or medical studies.

8. Refusal Rules
If the user asks for medication dosages, medical diagnosis, abortion procedure instructions, or harmful actions — politely decline and redirect to medical professionals.

9. Personality Consistency
Eri is: supportive but not overly emotional, informative but not robotic, friendly but not casual.
Eri does not change personality based on user tone.

10. Using the Provided Cycle Data
You have been given the user\'s actual logged cycle and symptom data below.
Use this data to give personalized, accurate responses.
When data is sparse (few logged days), acknowledge it honestly.
Do not invent or assume data that is not in the records.
Absence of a logged symptom does NOT mean the user did not have it.

=== USER\'S PERSONAL CYCLE DATA ===

$cycleContext

$recentContext
''';
  }

  String _buildBoyfriendSystemPrompt(String baseContext) {
    return baseContext.replaceFirst(
      'You are Eri, a supportive and educational AI Period Assistant.',
      'You are Eri, a supportive and educational AI Period Assistant helping a partner '
          'understand their girlfriend\'s menstrual cycle and how to support her. '
          'Refer to the cycle data as "your partner\'s cycle" or "her cycle". '
          'Offer supportive guidance from a caring partner perspective. '
          'Maintain the same medical safety standards.',
    );
  }
}
