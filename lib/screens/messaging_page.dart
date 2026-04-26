// lib/screens/messaging_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:intl/intl.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/messaging_service.dart';
import '../database/message_database.dart';
import '../widgets/message_reaction_overlay.dart';
import 'package:markdown_widget/markdown_widget.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/vs2015.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class MessagingPage extends StatefulWidget {
  final String threadId;
  final String threadType;
  final String myRole;
  final String aiMode;
  final String aiName;
  final VoidCallback? onMessagesUpdated;
  final String nickname;
  final String title;
  final String? highlightMessageId;

  const MessagingPage({
    super.key,
    required this.threadId,
    required this.threadType,
    required this.myRole,
    this.aiMode = 'none',
    this.aiName = '',
    this.onMessagesUpdated,
    this.nickname = '',
    this.title = '',
    this.highlightMessageId,
  });

  @override
  State<MessagingPage> createState() => _MessagingPageState();
}

class _MessagingPageState extends State<MessagingPage> {
  late final MessagingService _messagingService;
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late final stt.SpeechToText _speech;
  bool _isListening = false;

  String? _highlightedMessageId;
  final Map<String, GlobalKey> _messageKeys = {};
  final Set<String> _tappedMessageIds = {};

  // ✅ Added back: reply and edit state for the overlay
  MessageModel? _replyingTo;
  MessageModel? _editingMessage;

  // Avatar photo state (firebase threads only)
  String? _myAvatarBase64;
  String? _myAvatarPhotoUrl;
  String? _partnerAvatarBase64;
  String? _partnerAvatarPhotoUrl;

  // Pre-built ImageProviders — created once, reused on every rebuild to prevent flicker
  ImageProvider? _partnerImageProvider;

  // ✅ Added back: needed to key reactions to the current user

  // Loaded from .env for security
  static String get GROQ_API_KEY => dotenv.env['GROQ_API_KEY_MESSAGING'] ?? "";

  // Models in priority order (will try in this exact sequence)
  final List<String> _modelPriority = [
    'openai/gpt-oss-120b',
    'llama-3.3-70b-versatile',
    'meta-llama/llama-4-maverick-17b-128e-instruct',
    'qwen/qwen3-32b',
    'llama-3.1-8b-instant',
  ];

  int _currentModelIndex = 0;

  @override
  void initState() {
    super.initState();
    _messagingService = MessagingService();
    _speech = stt.SpeechToText();
    _highlightedMessageId = widget.highlightMessageId;

    if (widget.threadType == 'firebase') {
      _messagingService.initChat(widget.threadId);
      _loadAvatarPhotos();
    }
  }

  // Cache keys scoped to this thread so different pairs don't collide
  String get _cacheKeyPartnerBase64 => 'avatar_partner_base64_${widget.threadId}';
  String get _cacheKeyPartnerPhotoUrl => 'avatar_partner_url_${widget.threadId}';
  String get _cacheKeyMyBase64 => 'avatar_my_base64_${widget.threadId}';

  Future<void> _loadAvatarPhotos() async {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null) return;

    // My Gmail photo URL is always available from Firebase Auth directly — no async needed
    _myAvatarPhotoUrl = FirebaseAuth.instance.currentUser?.photoURL;

    // ── STEP 1: Load from cache instantly (synchronous-feeling, no Firestore wait) ──
    final prefs = await SharedPreferences.getInstance();
    final cachedMyBase64 = prefs.getString(_cacheKeyMyBase64);
    final cachedPartnerBase64 = prefs.getString(_cacheKeyPartnerBase64);
    final cachedPartnerPhotoUrl = prefs.getString(_cacheKeyPartnerPhotoUrl);

    // Apply cache immediately so avatar shows on first frame
    if (mounted) {
      setState(() {
        _myAvatarBase64 = cachedMyBase64;
        _partnerAvatarBase64 = cachedPartnerBase64;
        _partnerAvatarPhotoUrl = cachedPartnerPhotoUrl;
        // Build ImageProvider once from cache so it never rebuilds on stream updates
        if (cachedPartnerBase64 != null) {
          _partnerImageProvider = MemoryImage(base64Decode(cachedPartnerBase64));
        } else if (cachedPartnerPhotoUrl != null) {
          _partnerImageProvider = NetworkImage(cachedPartnerPhotoUrl);
        }
      });
    }

    // ── STEP 2: Fetch fresh data from Firestore in the background ──
    try {
      final myDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(myUid)
          .get();
      final myBase64 = myDoc.data()?['appPhotoBase64'] as String?;

      // Find partner UID via couples doc (guaranteed source of truth)
      final coupleDoc = await FirebaseFirestore.instance
          .collection('couples')
          .doc(widget.threadId)
          .get();

      String? partnerUid;
      if (coupleDoc.exists) {
        final members = List<String>.from(coupleDoc.data()?['members'] ?? []);
        partnerUid = members.firstWhere((uid) => uid != myUid, orElse: () => '');
        if (partnerUid!.isEmpty) partnerUid = null;
      }

      String? partnerBase64;
      String? partnerPhotoUrl;
      if (partnerUid != null) {
        final partnerDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(partnerUid)
            .get();
        final data = partnerDoc.data();
        if (data != null) {
          partnerBase64 = data['appPhotoBase64'] as String?;
          partnerPhotoUrl = data['photoURL'] as String?;
        }
      }

      // Update UI with fresh data
      if (mounted) {
        setState(() {
          _myAvatarBase64 = myBase64;
          _partnerAvatarBase64 = partnerBase64;
          _partnerAvatarPhotoUrl = partnerPhotoUrl;
          // Rebuild ImageProvider only when fresh data actually arrives
          if (partnerBase64 != null) {
            _partnerImageProvider = MemoryImage(base64Decode(partnerBase64));
          } else if (partnerPhotoUrl != null) {
            _partnerImageProvider = NetworkImage(partnerPhotoUrl);
          }
        });
      }

      // Persist fresh data to cache for next open
      if (myBase64 != null) { prefs.setString(_cacheKeyMyBase64, myBase64); } else { prefs.remove(_cacheKeyMyBase64); }
      if (partnerBase64 != null) { prefs.setString(_cacheKeyPartnerBase64, partnerBase64); } else { prefs.remove(_cacheKeyPartnerBase64); }
      if (partnerPhotoUrl != null) { prefs.setString(_cacheKeyPartnerPhotoUrl, partnerPhotoUrl); } else { prefs.remove(_cacheKeyPartnerPhotoUrl); }

    } catch (e) {
      debugPrint('Avatar photo load error: $e');
    }
  }

  void _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    // ✅ If editing, delegate to _performEdit instead
    if (_editingMessage != null) {
      await _performEdit(text);
      return;
    }


    _textController.clear();

    if (widget.threadType == 'local') {
      final msg = MessageModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        senderUid: 'local_user',
        text: text,
        timestamp: DateTime.now().millisecondsSinceEpoch,
        isRead: true,
        isMe: true,
        threadId: widget.threadId,
        threadType: widget.threadType,
        aiMode: widget.aiMode,
        aiName: widget.aiName,
        replyToId: _replyingTo?.id,
      );
      await MessageDatabase().insertMessage(msg, widget.threadId, widget.threadType);

      setState(() {
        _replyingTo = null;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onMessagesUpdated?.call();
        _scrollToBottom(animate: true);
      });

      bool shouldCallAI = false;
      if (widget.aiMode == 'always') {
        shouldCallAI = true;
      } else if (widget.aiMode == 'on-demand' && widget.aiName.isNotEmpty) {
        final mention = '@${widget.aiName.trim()}';
        if (text.startsWith(mention) || text.toLowerCase().contains('$mention,')) {
          shouldCallAI = true;
        }
      }

      if (shouldCallAI) {
        _callAIAndSaveResponse(text);
      }
    } else {
      await _messagingService.sendMessage(text, replyToId: _replyingTo?.id);

      setState(() {
        _replyingTo = null;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onMessagesUpdated?.call();
        _scrollToBottom(animate: true);
      });
    }
  }

  Offset _getSmartOverlayPosition(GlobalKey messageKey) {
    final renderBox =
    messageKey.currentContext!.findRenderObject() as RenderBox;

    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    final screenHeight = MediaQuery.of(context).size.height;

    final bool isNearBottom =
        position.dy + size.height > screenHeight * 0.6;

    if (isNearBottom) {
      // ✅ Show overlay ABOVE the message
      return Offset(
        position.dx + size.width / 2,
        position.dy - 12, // slightly above bubble
      );
    } else {
      // ✅ Show overlay BELOW the message
      return Offset(
        position.dx + size.width / 2,
        position.dy + size.height + 12,
      );
    }
  }


  // ✅ Added back: handles saving an edited message
  Future<void> _performEdit(String newText) async {
    if (_editingMessage == null) return;

    if (widget.threadType == 'firebase') {
      await _messagingService.editMessage(_editingMessage!.id, newText);
      print('✏️ Firebase message edited: ${_editingMessage!.id}');
    } else {
      final updatedMsg = _editingMessage!.copyWith(text: newText);
      await MessageDatabase().updateMessage(updatedMsg);
      print('✏️ Local message edited: ${_editingMessage!.id}');

      if (mounted) {
        setState(() {});
      }
    }

    setState(() {
      _editingMessage = null;
    });
    _textController.clear();
  }

  // ✅ Added back: handles adding/removing a reaction
  Future<void> _handleReaction(MessageModel msg, String emoji) async {
    final myUid = _messagingService.myUid;
    final currentReaction = msg.reactions[myUid];

    if (widget.threadType == 'firebase') {
      if (currentReaction == emoji) {
        await _messagingService.removeReaction(msg.id);
      } else {
        await _messagingService.addReaction(msg.id, emoji);
      }
    } else {
      final updatedReactions = Map<String, String>.from(msg.reactions);

      if (currentReaction == emoji) {
        updatedReactions.remove(myUid);
      } else {
        updatedReactions[myUid] = emoji;
      }

      final updatedMsg = msg.copyWith(reactions: updatedReactions);
      await MessageDatabase().updateMessage(updatedMsg);

      if (mounted) {
        setState(() {});
      }
    }
  }


  // ✅ Added back: tombstone delete triggered from the overlay
  Future<void> _handleUnsend(MessageModel msg) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Message"),
        content: const Text("Are you sure you want to delete this message? This cannot be undone."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (widget.threadType == 'firebase') {
        await _messagingService.deleteMessage(msg.id);
        print('🗑️ Firebase message deleted: ${msg.id}');
      } else {
        final tombstone = MessageModel(
          id: msg.id,
          senderUid: msg.senderUid,
          text: '',
          timestamp: msg.timestamp,
          isRead: msg.isRead,
          isMe: msg.isMe,
          threadId: msg.threadId,
          threadType: msg.threadType,
          isDeleted: true,
        );

        await MessageDatabase().updateMessage(tombstone);
        print('🗑️ Local message deleted (tombstone created): ${msg.id}');
      }
    }
  }

  // ✅ Added back: edit is only allowed within 1 hour of sending
  bool _canEditMessage(MessageModel msg) {
    if (!msg.isMe) return false;
    if (msg.isDeleted) return false;

    final now = DateTime.now().millisecondsSinceEpoch;
    final hourInMillis = 60 * 60 * 1000;

    return (now - msg.timestamp) < hourInMillis;
  }

  // ✅ Added back: shows the reaction bar + action menu overlay on long-press
  void _showReactionOverlay(MessageModel msg, Offset tapPosition) {
    // AI/system messages get no overlay at all
    final isAIMessage = msg.senderUid == 'ai' || msg.senderUid == 'system';
    if (isAIMessage) return;

    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (context) => MessageReactionOverlay(
        tapPosition: tapPosition,
        messageId: msg.id,
        isMyMessage: msg.isMe,
        currentUserReaction: msg.reactions[_messagingService.myUid],
          onReactionSelected: (emoji) => _handleReaction(msg, emoji),
        onReply: () {
          setState(() {
            _replyingTo = msg;
          });
        },
        onEdit: (msg.isMe && _canEditMessage(msg))
            ? () {
          setState(() {
            _editingMessage = msg;
            _textController.text = msg.text;
          });
        }
            : null,
        onUnsend: msg.isMe ? () => _handleUnsend(msg) : null,
        onDismiss: () => Navigator.pop(context),
      ),
    );
  }

  Future<void> _callAIAndSaveResponse(String userMessage) async {
    try {
      String cleanPrompt = userMessage;
      if (widget.aiMode == 'on-demand') {
        final pattern = RegExp(r'^@\w+\s*[,!]*\s*');
        cleanPrompt = pattern.hasMatch(userMessage)
            ? userMessage.substring(pattern.firstMatch(userMessage)!.end)
            : userMessage;
      }

      final allMessages =
      await MessageDatabase().getMessagesByThreadId(widget.threadId);
      final recentHistory = allMessages.reversed.take(10).toList().reversed.toList();
      final messages = <Map<String, dynamic>>[];

      String systemInstruction = "You are a helpful assistant.";
      if (widget.aiName == "Aetis") {
        systemInstruction =
        "You help users organize, summarize, and clarify notes. Be concise and practical.";
      } else if (widget.aiName == "Numina") {
        systemInstruction =
        "You are a friendly, engaging AI companion. Keep responses warm and conversational.";
      }

      messages.add({'role': 'system', 'content': systemInstruction});
      for (final m in recentHistory) {
        if (m.senderUid == 'ai') {
          messages.add({'role': 'assistant', 'content': m.text});
        } else if (m.isMe) {
          messages.add({'role': 'user', 'content': m.text});
        }
      }
      messages.add({
        'role': 'user',
        'content': cleanPrompt.trim().isEmpty ? 'Hello!' : cleanPrompt.trim()
      });

      String? aiReply;
      String? usedModel;

      for (int attempt = 0; attempt < _modelPriority.length; attempt++) {
        final modelIndex = (_currentModelIndex + attempt) % _modelPriority.length;
        final currentModel = _modelPriority[modelIndex];

        try {
          print('Trying model: $currentModel');

          final url = 'https://api.groq.com/openai/v1/chat/completions';
          final requestBody = {
            'model': currentModel,
            'messages': messages,
            'temperature': 0.7,
            'max_tokens': 2500,
            'top_p': 1,
            'stream': false
          };

          final response = await http.post(
            Uri.parse(url),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $GROQ_API_KEY',
            },
            body: jsonEncode(requestBody),
          ).timeout(const Duration(seconds: 15));

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            if (data['choices'] != null &&
                data['choices'].isNotEmpty &&
                data['choices'][0]['message'] != null &&
                data['choices'][0]['message']['content'] != null) {
              aiReply = data['choices'][0]['message']['content'];
              usedModel = currentModel;

              _currentModelIndex = modelIndex;
              print('✓ Success with model: $currentModel');
              break;
            }
          } else if (response.statusCode == 429) {
            print('✗ Rate limit (429) on $currentModel, trying next...');
            continue;
          } else if (response.statusCode == 400) {
            print('✗ Bad request (400) on $currentModel, trying next...');
            continue;
          } else {
            print('✗ Error ${response.statusCode} on $currentModel, trying next...');
            continue;
          }
        } catch (e) {
          print('✗ Exception with $currentModel: $e, trying next...');
          continue;
        }
      }

      if (aiReply == null) {
        throw Exception('All AI models failed or are rate limited');
      }

      final aiMsg = MessageModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        senderUid: 'ai',
        text: aiReply,
        timestamp: DateTime.now().millisecondsSinceEpoch,
        isRead: true,
        isMe: false,
        threadId: widget.threadId,
        threadType: 'local',
        aiMode: widget.aiMode,
        aiName: widget.aiName,
      );

      await MessageDatabase().insertMessage(aiMsg, widget.threadId, 'local');

      if (usedModel != _modelPriority[0]) {
        print('ℹ Using fallback model: $usedModel');
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onMessagesUpdated?.call();
        _scrollToBottom(animate: true);
      });

    } catch (e) {
      print('❌ All models failed: $e');
      final errorMsg = MessageModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        senderUid: 'system',
        text: '⚠️ AI services unavailable. All models are rate limited.',
        timestamp: DateTime.now().millisecondsSinceEpoch,
        isRead: true,
        isMe: false,
        threadId: widget.threadId,
        threadType: 'local',
        aiMode: widget.aiMode,
        aiName: widget.aiName,
      );
      await MessageDatabase().insertMessage(errorMsg, widget.threadId, 'local');

      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onMessagesUpdated?.call();
        _scrollToBottom(animate: true);
      });
    }
  }

  void _scrollToBottom({bool animate = false}) {
    if (!_scrollController.hasClients) return;

    if (animate) {
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } else {
      _scrollController.jumpTo(0.0);
    }
  }

  void _scrollToHighlightedMessage() {
    if (_highlightedMessageId == null) return;

    final delays = [80, 250, 500, 900, 1400];

    for (final delay in delays) {
      Future.delayed(Duration(milliseconds: delay), () {
        if (!mounted) return;

        final key = _messageKeys[_highlightedMessageId];
        if (key != null && key.currentContext != null && _scrollController.hasClients) {
          Scrollable.ensureVisible(
            key.currentContext!,
            duration: const Duration(milliseconds: 450),
            curve: Curves.easeInOut,
            alignment: 0.1,
          );
        }
      });
    }
  }

  void _startListening() async {
    bool available = await _speech.initialize(
      onStatus: (status) {
        if (status == "notListening") {
          setState(() => _isListening = false);
        }
      },
      onError: (errorNotification) {
        setState(() => _isListening = false);
      },
    );
    if (available) {
      setState(() => _isListening = true);
      _speech.listen(
        onResult: (result) {
          if (result.confidence > 0.3) {
            _textController.text = result.recognizedWords;
          }
        },
      );
    }
  }

  void _stopListening() {
    _speech.stop();
    setState(() => _isListening = false);
  }

  @override
  void dispose() {
    _messagingService.dispose();
    _textController.dispose();
    _scrollController.dispose();
    _speech.stop();

    if (widget.threadType == 'local') {
      MessageDatabase().disposeThreadStream(widget.threadId);
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: Column(
        children: [
          // ✅ Added back: reply and edit banners
          if (_replyingTo != null) _buildReplyBanner(),
          if (_editingMessage != null) _buildEditBanner(),
          Expanded(child: _buildMessageList()),
          _buildInputField(),
        ],
      ),
    );
  }

  // ✅ Added back: blue banner shown while replying
  Widget _buildReplyBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        border: Border(bottom: BorderSide(color: Colors.blue.shade200)),
      ),
      child: Row(
        children: [
          Icon(Icons.reply, size: 20, color: Colors.blue.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Replying to',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  _replyingTo!.text.length > 50
                      ? '${_replyingTo!.text.substring(0, 50)}...'
                      : _replyingTo!.text,
                  style: const TextStyle(fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: () => setState(() => _replyingTo = null),
          ),
        ],
      ),
    );
  }

  // ✅ Added back: orange banner shown while editing
  Widget _buildEditBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        border: Border(bottom: BorderSide(color: Colors.orange.shade200)),
      ),
      child: Row(
        children: [
          Icon(Icons.edit, size: 20, color: Colors.orange.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Editing message',
              style: TextStyle(
                fontSize: 14,
                color: Colors.orange.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: () {
              setState(() {
                _editingMessage = null;
                _textController.clear();
              });
            },
          ),
        ],
      ),
    );
  }

  void _showAIModelSettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'AI Model Settings',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Choose your preferred AI model',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                children: [
                  _buildModelOption(
                    modelId: 'openai/gpt-oss-120b',
                    displayName: 'GPT-OSS 120B',
                    description: 'Most powerful model. Best for complex reasoning, creative writing, and detailed analysis.',
                    icon: Icons.psychology,
                    color: Colors.purple,
                    badges: ['120B params', 'Best Quality'],
                  ),
                  _buildModelOption(
                    modelId: 'llama-3.3-70b-versatile',
                    displayName: 'LLaMA 3.3 70B',
                    description: 'Versatile and balanced. Great for general conversations, coding help, and explanations.',
                    icon: Icons.auto_awesome,
                    color: Colors.blue,
                    badges: ['70B params', 'Versatile'],
                  ),
                  _buildModelOption(
                    modelId: 'meta-llama/llama-4-maverick-17b-128e-instruct',
                    displayName: 'LLaMA 4 Maverick',
                    description: 'Fast and efficient. Good for quick responses, summaries, and everyday tasks.',
                    icon: Icons.speed,
                    color: Colors.orange,
                    badges: ['17B params', 'Fast'],
                  ),
                  _buildModelOption(
                    modelId: 'qwen/qwen3-32b',
                    displayName: 'Qwen 3 32B',
                    description: 'Multilingual specialist. Excellent for translation, language learning, and diverse content.',
                    icon: Icons.translate,
                    color: Colors.teal,
                    badges: ['32B params', 'Multilingual'],
                  ),
                  _buildModelOption(
                    modelId: 'llama-3.1-8b-instant',
                    displayName: 'LLaMA 3.1 8B Instant',
                    description: 'Ultra-fast responses. Perfect for simple questions, casual chat, and high-volume usage.',
                    icon: Icons.flash_on,
                    color: Colors.green,
                    badges: ['8B params', 'Instant', 'High Quota'],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue.shade700),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'If your chosen model hits rate limits, the system will automatically fallback to the next available model.',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.blue.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModelOption({
    required String modelId,
    required String displayName,
    required String description,
    required IconData icon,
    required Color color,
    required List<String> badges,
  }) {
    final isSelected = _modelPriority.first == modelId;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isSelected ? color.withOpacity(0.1) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? color : Colors.grey.shade300,
          width: isSelected ? 2 : 1,
        ),
        boxShadow: isSelected
            ? [
          BoxShadow(
            color: color.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          )
        ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            setState(() {
              _modelPriority.remove(modelId);
              _modelPriority.insert(0, modelId);
              _currentModelIndex = 0;
            });
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Switched to $displayName'),
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              displayName,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isSelected ? color : Colors.black87,
                              ),
                            ),
                          ),
                          if (isSelected)
                            Icon(Icons.check_circle, color: color, size: 24),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: badges.map((badge) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            badge,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: color.withOpacity(0.8),
                            ),
                          ),
                        )).toList(),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Converts LaTeX expressions in AI text to readable plain text,
  /// then passes the result to MarkdownWidget for rendering.

  /// Converts LaTeX expressions in AI text to readable Unicode, then renders as markdown.
  Widget _buildAIMessageContent(String text, bool isHighlighted) {
    return _buildMarkdownChunk(_preprocessLatex(text), isHighlighted);
  }

  /// Pre-processes LaTeX math expressions into clean readable Unicode text.
  String _preprocessLatex(String text) {
    var result = text;
    result = result.replaceAllMapped(
      RegExp(r'\$\$([\s\S]+?)\$\$'),
      (m) => _latexToReadable(m.group(1)!.trim()),
    );
    result = result.replaceAllMapped(
      RegExp(r'\\\[([\s\S]+?)\\\]'),
      (m) => _latexToReadable(m.group(1)!.trim()),
    );
    result = result.replaceAllMapped(
      RegExp(r'\\\(([^)]+?)\\\)'),
      (m) => _latexToReadable(m.group(1)!.trim()),
    );
    result = result.replaceAllMapped(
      RegExp(r'\$([^\$\n]+?)\$'),
      (m) => _latexToReadable(m.group(1)!.trim()),
    );
    result = _latexToReadable(result);
    return result;
  }

  /// Converts LaTeX commands to readable Unicode equivalents.
  String _latexToReadable(String latex) {
    var s = latex;
    s = s.replaceAllMapped(RegExp(r'\\frac\{([^}]+)\}\{([^}]+)\}'), (m) => '(${m.group(1)})/(${m.group(2)})');
    s = s.replaceAllMapped(RegExp(r'\^\{([^}]+)\}'), (m) => '^${m.group(1)}');
    s = s.replaceAllMapped(RegExp(r'_\{([^}]+)\}'), (m) => '_${m.group(1)}');
    s = s.replaceAllMapped(RegExp(r'\\sqrt\{([^}]+)\}'), (m) => '√(${m.group(1)})');
    s = s
      .replaceAll(r'\approx', '≈').replaceAll(r'\neq', '≠').replaceAll(r'\leq', '≤')
      .replaceAll(r'\geq', '≥').replaceAll(r'\times', '×').replaceAll(r'\div', '÷')
      .replaceAll(r'\pm', '±').replaceAll(r'\infty', '∞').replaceAll(r'\sum', '∑')
      .replaceAll(r'\prod', '∏').replaceAll(r'\int', '∫').replaceAll(r'\pi', 'π')
      .replaceAll(r'\theta', 'θ').replaceAll(r'\alpha', 'α').replaceAll(r'\beta', 'β')
      .replaceAll(r'\gamma', 'γ').replaceAll(r'\delta', 'δ').replaceAll(r'\lambda', 'λ')
      .replaceAll(r'\mu', 'μ').replaceAll(r'\sigma', 'σ').replaceAll(r'\omega', 'ω')
      .replaceAll(r'\Delta', 'Δ').replaceAll(r'\Sigma', 'Σ').replaceAll(r'\cdot', '·')
      .replaceAll(r'\ldots', '…').replaceAll(r'\dots', '…')
      .replaceAll(r'\left(', '(').replaceAll(r'\right)', ')').replaceAll(r'\left[', '[')
      .replaceAll(r'\right]', ']').replaceAll(r'\left|', '|').replaceAll(r'\right|', '|')
      .replaceAll(r'\text{', '').replaceAll(r'\mathrm{', '').replaceAll(r'\mathbf{', '').replaceAll(r'\mathit{', '');
    s = s.replaceAllMapped(RegExp(r'\\[a-zA-Z]+\{([^}]*)\}'), (m) => m.group(1)!);
    s = s.replaceAll(RegExp(r'\\[a-zA-Z]+'), '');
    s = s.replaceAll('{', '').replaceAll('}', '');
    return s.trim();
  }

  Widget _buildMarkdownChunk(String text, bool isHighlighted) {
    return MarkdownWidget(
      data: text,
      shrinkWrap: true,
      selectable: true,
      config: MarkdownConfig(
        configs: [
          PreConfig(
            wrapper: (child, code, language) => _buildCodeBlock(code, language),
          ),
          CodeConfig(
            style: TextStyle(
              backgroundColor: Colors.grey.shade200,
              color: Colors.red.shade700,
              fontFamily: 'monospace',
              fontSize: 14,
            ),
          ),
          TableConfig(
            wrapper: (table) => SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: table,
            ),
            defaultColumnWidth: const IntrinsicColumnWidth(),
            border: TableBorder.all(color: Colors.grey.shade400, width: 1),
          ),
          PConfig(
            textStyle: const TextStyle(fontSize: 16, color: Colors.black87, height: 1.5),
          ),
          H1Config(style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87)),
          H2Config(style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87)),
          H3Config(style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
          LinkConfig(
            style: TextStyle(color: Colors.blue.shade700, decoration: TextDecoration.underline),
            onTap: (url) async {
              final uri = Uri.parse(url);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
          ),
          BlockquoteConfig(
            sideColor: Colors.grey.shade400,
            textColor: Colors.black54,
            sideWith: 3,
            padding: const EdgeInsets.only(left: 12, top: 8, bottom: 8),
            margin: const EdgeInsets.symmetric(vertical: 8),
          ),
          ListConfig(
            marker: (isOrdered, depth, index) {
              if (isOrdered) return Text('\${index + 1}. ');
              if (depth == 0) return const Text('• ');
              if (depth == 1) return const Text('◦ ');
              return const Text('▪ ');
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCodeBlock(String code, String? language) {
    final scrollController = ScrollController();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        children: [
          Scrollbar(
            controller: scrollController,
            thumbVisibility: false,
            child: SingleChildScrollView(
              controller: scrollController,
              scrollDirection: Axis.horizontal,
              child: Container(
                constraints: BoxConstraints(
                  minWidth: MediaQuery.of(context).size.width - 48,
                ),
                child: HighlightView(
                  code,
                  language: language ?? 'plaintext',
                  theme: vs2015Theme,
                  padding: const EdgeInsets.fromLTRB(12, 32, 12, 12),
                  textStyle: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: code));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Code copied to clipboard'),
                      duration: Duration(seconds: 2),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.copy, size: 14, color: Colors.white70),
                      SizedBox(width: 4),
                      Text(
                        'Copy',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white70,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    String titleText;
    if (widget.threadType == 'local') {
      titleText = widget.nickname.isNotEmpty
          ? widget.nickname
          : (widget.title.isNotEmpty ? widget.title : 'Chat');
    } else {
      titleText = 'Your Match';
    }
    return AppBar(
      backgroundColor: Colors.white,
      foregroundColor: Colors.black,
      title: Text(
        titleText,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.tune),
          onPressed: _showAIModelSettings,
        ),
      ],
    );
  }

  Widget _buildMessageList() {
    final Stream<List<MessageModel>> messageStream = widget.threadType == 'local'
        ? MessageDatabase().watchMessagesByThreadId(widget.threadId)
        : _messagingService.messages;

    return StreamBuilder<List<MessageModel>>(
      stream: messageStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text("No messages yet"));
        }

        final messages = snapshot.data!;

        for (final msg in messages) {
          _messageKeys.putIfAbsent(msg.id, () => GlobalKey());
        }

        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (_highlightedMessageId != null &&
              messages.any((m) => m.id == _highlightedMessageId)) {
            _scrollToHighlightedMessage();
          } else if (!_scrollController.hasClients ||
              _scrollController.position.pixels <= 100) {
            // Only auto-scroll if the user is already near the bottom (or first load)
            _scrollToBottom(animate: false);
          }
        });

        return ListView.builder(
          reverse: true,
          controller: _scrollController,
          padding: const EdgeInsets.only(top: 8, bottom: 8),
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final msg = messages[messages.length - 1 - index];
            final isHighlighted = msg.id == _highlightedMessageId;

            // isLastInGroup: true when the message visually below (more recent)
            // has a different sender — or this is the most recent message.
            // AI/system messages are excluded from grouping.
            final isAI = msg.senderUid == 'ai' || msg.senderUid == 'system';
            bool isLastInGroup;
            if (isAI) {
              isLastInGroup = false;
            } else if (index == 0) {
              isLastInGroup = true;
            } else {
              final msgBelow = messages[messages.length - index];
              isLastInGroup = msgBelow.senderUid != msg.senderUid;
            }

            return _buildMessageBubble(
              msg,
              isHighlighted,
              isLastInGroup: isLastInGroup,
              key: _messageKeys[msg.id]!,
            );
          },
        );
      },
    );
  }

  Widget _buildAvatarWidget({required bool isMe, required bool visible}) {
    const double radius = 14.0;
    if (!visible) return const SizedBox(width: radius * 2);

    // Use the pre-built, stable ImageProvider — never recreate on rebuild
    final imageProvider = _partnerImageProvider;

    return CircleAvatar(
      radius: radius,
      backgroundImage: imageProvider,
      backgroundColor: Colors.grey.shade300,
      child: imageProvider == null
          ? Icon(Icons.person, size: radius, color: Colors.grey.shade600)
          : null,
    );
  }

  Widget _buildMessageBubble(
      MessageModel msg,
      bool isHighlighted, {
        required Key key,
        bool isLastInGroup = false,
      }) {

    // ✅ Deleted messages render as a permanent tombstone placeholder
    if (msg.isDeleted) {
      return Container(
        key: key,
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        child: Align(
          alignment: msg.isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.block, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 6),
                Text(
                  'Message deleted',
                  style: TextStyle(
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final isMe = msg.isMe;
    final sender = msg.senderUid;
    final time = DateFormat('hh:mm a')
        .format(DateTime.fromMillisecondsSinceEpoch(msg.timestamp));

    final isAI = sender == 'ai' || sender == 'system';

    // AI messages - no long-press overlay
    if (isAI) {
      return Container(
        key: key,
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.smart_toy, size: 14, color: Colors.purple.shade700),
                      const SizedBox(width: 4),
                      Text(
                        widget.aiName.isNotEmpty ? widget.aiName : 'Numina',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.purple.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  time,
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: isHighlighted ? Colors.yellow.shade100 : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              padding: isHighlighted ? const EdgeInsets.all(8) : EdgeInsets.zero,
              child: _buildAIMessageContent(msg.text, isHighlighted),
            ),
          ],
        ),
      );
    }

    // Smart timestamp: time only if today, full date+time if older
    final msgDate = DateTime.fromMillisecondsSinceEpoch(msg.timestamp);
    final now = DateTime.now();
    final isToday = msgDate.year == now.year &&
        msgDate.month == now.month &&
        msgDate.day == now.day;
    final smartTimestamp = isToday
        ? DateFormat('h:mm a').format(msgDate)
        : DateFormat('MMM d, yyyy h:mm a').format(msgDate);

    final isTapped = _tappedMessageIds.contains(msg.id);

    // ✅ User messages: long-press opens the reaction overlay (reactions, reply, edit, delete)
    return GestureDetector(
      key: key,
      onTap: () {
        setState(() {
          if (_tappedMessageIds.contains(msg.id)) {
            _tappedMessageIds.remove(msg.id);
          } else {
            _tappedMessageIds.add(msg.id);
          }
        });
      },
      onLongPressStart: (details) {
        final smartPosition =
        _getSmartOverlayPosition(_messageKeys[msg.id]!);
        _showReactionOverlay(msg, smartPosition);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Partner avatar — left side
                if (!isMe && widget.threadType == 'firebase') ...[  
                  _buildAvatarWidget(isMe: false, visible: isLastInGroup),
                  const SizedBox(width: 6),
                ],
                // Message bubble
                Container(
                  constraints: const BoxConstraints(maxWidth: 250),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isHighlighted
                              ? Colors.yellow.shade300
                              : (isMe ? const Color(0xFF007AFF) : Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: isHighlighted
                              ? [
                            BoxShadow(
                              color: Colors.yellow.shade700.withOpacity(0.5),
                              blurRadius: 10,
                              spreadRadius: 2,
                            )
                          ]
                              : null,
                        ),
                        child: Text(
                          msg.text,
                          style: TextStyle(
                            color: isHighlighted
                                ? Colors.black87
                                : (isMe ? Colors.white : Colors.black87),
                            fontSize: 16,
                            height: 1.4,
                          ),
                        ),
                      ),
                      // ✅ Reaction badges rendered below the bubble
                      if (msg.reactions.isNotEmpty)
                        Positioned(
                          left: isMe ? 12 : null,
                          right: isMe ? null : 12,
                          bottom: -15,
                          child: _buildReactionBadge(msg.reactions),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            // Timestamp — only shown when tapped
            if (isTapped) ...[  
              const SizedBox(height: 4),
              Text(
                smartTimestamp,
                style: TextStyle(
                  fontSize: 10,
                  color: isMe ? const Color(0xFF64B5F6) : Colors.grey,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ✅ Added back: renders the emoji pill badges below a message
  Widget _buildReactionBadge(Map<String, String> reactions) {
    final reactionCounts = <String, int>{};
    for (final emoji in reactions.values) {
      reactionCounts[emoji] = (reactionCounts[emoji] ?? 0) + 1;
    }

    final topReactions = reactionCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final displayReactions = topReactions.take(3).toList();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < displayReactions.length; i++) ...[
            if (i > 0) const SizedBox(width: 2),
            Text(
              displayReactions[i].key,
              style: const TextStyle(fontSize: 14),
            ),
            if (displayReactions[i].value > 1)
              Text(
                ' ${displayReactions[i].value}',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildInputField() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (widget.threadType == 'local')
            IconButton(
              icon: Icon(_isListening ? Icons.mic : Icons.mic_none),
              color: _isListening ? Colors.red : null,
              onPressed: _isListening ? _stopListening : _startListening,
            ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(20),
              ),
              child: TextField(
                controller: _textController,
                maxLines: null,
                minLines: 1,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  hintText: _editingMessage != null
                      ? 'Edit message...'
                      : (_replyingTo != null
                      ? 'Reply...'
                      : 'Type a message...'),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          IconButton(
            icon: Icon(
              _editingMessage != null ? Icons.check : Icons.send,
              color: const Color(0xFF007AFF),
            ),
            onPressed: _sendMessage,
          ),
        ],
      ),
    );

  }
}