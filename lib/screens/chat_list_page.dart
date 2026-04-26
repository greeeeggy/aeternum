// lib/screens/chat_list_page.dart
// UPDATED: Fixed timestamp handling for Firebase cached data

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'messaging_page.dart';
import 'message_search_page.dart';
import '../database/message_database.dart';
import 'package:markdown_widget/markdown_widget.dart';

class ChatListPage extends StatefulWidget {
  const ChatListPage({super.key});

  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> {
  late Future<void> _initialDataFuture;
  List<LocalThread> _localThreads = [];
  String? _firebasePairId;

  StreamSubscription<QuerySnapshot>? _firebasePreviewSubscription;
  List<MessageModel> _firebaseMessages = [];

  @override
  void initState() {
    super.initState();
    _initialDataFuture = _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final user = FirebaseAuth.instance.currentUser!;
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    final data = userDoc.data() as Map<String, dynamic>?;
    _firebasePairId = data?['pairId'] as String?;

    _localThreads = await MessageDatabase().getLocalThreads();

    if (_firebasePairId != null) {
      _startFirebasePreviewListener();
    }
  }

  void _startFirebasePreviewListener() {
    _firebasePreviewSubscription = FirebaseFirestore.instance
        .collection('messages')
        .doc(_firebasePairId!)
        .collection('chats')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .listen((snapshot) {
      _firebaseMessages = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;

        // ✅ FIX: Handle both int (from cache) and Timestamp (from Firebase)
        int msgTimestamp;
        final timestampData = data['timestamp'];
        if (timestampData is Timestamp) {
          msgTimestamp = timestampData.millisecondsSinceEpoch;
        } else if (timestampData is int) {
          msgTimestamp = timestampData;
        } else {
          msgTimestamp = DateTime.now().millisecondsSinceEpoch;
        }

        return MessageModel(
          id: doc.id,
          senderUid: data['senderUid'] as String,
          text: data['text'] as String,
          timestamp: msgTimestamp,
          isRead: false,
          isMe: false,
          threadId: _firebasePairId!,
          threadType: 'firebase',
        );
      }).toList();

      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _firebasePreviewSubscription?.cancel();
    super.dispose();
  }

  Future<void> _refreshChatList() async {
    await _loadInitialData();
    if (mounted) setState(() {});
    await Future.delayed(const Duration(milliseconds: 300));
  }

  Future<void> _updateLocalThreadPreview(String threadId) async {
    final db = MessageDatabase();
    final messages = await db.getMessagesByThreadId(threadId);
    final threadIndex = _localThreads.indexWhere((t) => t.threadId == threadId);
    if (threadIndex == -1) return;
    final lastMessageTime = messages.isEmpty
        ? _localThreads[threadIndex].lastMessageTime
        : messages.last.timestamp;
    final updatedThread = _localThreads[threadIndex].copyWith(
      lastMessageTime: lastMessageTime,
    );
    setState(() {
      _localThreads[threadIndex] = updatedThread;
    });
  }

  void _updateFirebaseChatPreview() {
    // Not needed anymore — real-time via listener
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 2,
        backgroundColor: Colors.white,
        centerTitle: true,
        title: Text(
          'Messages',
          style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withOpacity(0.3),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: Icon(Icons.search, color: theme.colorScheme.primary),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => MessageSearchPage(
                      localThreads: _localThreads,
                      firebasePairId: _firebasePairId,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshChatList,
        child: FutureBuilder(
          future: _initialDataFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (_firebasePairId == null && _localThreads.isEmpty) {
              return _buildEmptyState();
            }

            return ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
              itemCount: (_firebasePairId != null ? 1 : 0) + _localThreads.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                if (_firebasePairId != null && index == 0) {
                  return _buildFirebaseChatItem(context, _firebasePairId!);
                }
                final localIndex = _firebasePairId != null ? index - 1 : index;
                return _buildLocalChatItem(context, _localThreads[localIndex]);
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createNewLocalChat,
        label: const Text('New Chat'),
        icon: const Icon(Icons.add),
        elevation: 4,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text(
            "No conversations yet",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildMarkdownPreview(String text) {
    return MarkdownWidget(
      data: text,
      shrinkWrap: true,
      selectable: false,
      config: MarkdownConfig(
        configs: [
          PreConfig(
            wrapper: (child, code, language) {
              return Text(
                '[code]',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              );
            },
          ),
          CodeConfig(
            style: TextStyle(
              backgroundColor: Colors.grey.shade300,
              color: Colors.grey[700],
              fontFamily: 'monospace',
              fontSize: 13,
            ),
          ),
          PConfig(
            textStyle: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
              height: 1.2,
            ),
          ),
          H1Config(
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          H2Config(
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          H3Config(
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          LinkConfig(
            style: TextStyle(
              color: Colors.blue[600],
              fontSize: 14,
              decoration: TextDecoration.none,
            ),
          ),
          BlockquoteConfig(
            sideColor: Colors.grey.shade400,
            textColor: Colors.grey[600]!,
            sideWith: 2,
            padding: const EdgeInsets.only(left: 8),
            margin: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  Widget _buildFirebaseChatItem(BuildContext context, String pairId) {
    String latestMessage = 'Start your conversation...';
    String timeDisplay = '';

    if (_firebaseMessages.isNotEmpty) {
      final lastMsg = _firebaseMessages.last;
      latestMessage = lastMsg.text;
      timeDisplay = _formatTime(DateTime.fromMillisecondsSinceEpoch(lastMsg.timestamp));
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.pink.withOpacity(0.2), width: 1.5),
      ),
      color: Colors.pink.withOpacity(0.02),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Container(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [Colors.pinkAccent, Colors.orangeAccent]),
            ),
            padding: const EdgeInsets.all(2),
            child: const CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(Icons.favorite, color: Colors.pinkAccent),
            ),
          ),
        ),
        title: const Text('Your Match', style: TextStyle(fontWeight: FontWeight.bold)),
        subtitle: SizedBox(
          height: 20,
          child: OverflowBox(
            maxHeight: 20,
            alignment: Alignment.centerLeft,
            child: _buildMarkdownPreview(latestMessage),
          ),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (timeDisplay.isNotEmpty)
              Text(timeDisplay, style: const TextStyle(fontSize: 11, color: Colors.grey)),
            const SizedBox(height: 4),
            const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey),
          ],
        ),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MessagingPage(
              threadId: pairId,
              threadType: 'firebase',
              myRole: 'user',
              onMessagesUpdated: () {},
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLocalChatItem(BuildContext context, LocalThread thread) {
    return FutureBuilder<List<MessageModel>>(
      future: MessageDatabase().getMessagesByThreadId(thread.threadId),
      builder: (context, snapshot) {
        String latestMessage = 'No messages yet';
        String timeDisplay = _formatTime(DateTime.fromMillisecondsSinceEpoch(thread.lastMessageTime));

        if (snapshot.hasData && snapshot.data!.isNotEmpty) {
          latestMessage = snapshot.data!.last.text;
          timeDisplay = _formatTime(DateTime.fromMillisecondsSinceEpoch(snapshot.data!.last.timestamp));
        }

        final isAI = thread.aiMode != 'none';
        final displayName = thread.nickname.isNotEmpty ? thread.nickname : thread.title;

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.withOpacity(0.1)),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: CircleAvatar(
              backgroundColor: isAI ? Colors.deepPurple[50] : Colors.blueGrey[50],
              child: Icon(
                isAI ? Icons.smart_toy_rounded : Icons.description_outlined,
                color: isAI ? Colors.deepPurple : Colors.blueGrey,
              ),
            ),
            title: Text(displayName, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: SizedBox(
              height: 20,
              child: OverflowBox(
                maxHeight: 20,
                alignment: Alignment.centerLeft,
                child: _buildMarkdownPreview(latestMessage),
              ),
            ),
            trailing: Text(
              timeDisplay,
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MessagingPage(
                    threadId: thread.threadId,
                    threadType: 'local',
                    myRole: 'user',
                    aiMode: thread.aiMode,
                    aiName: thread.aiName,
                    onMessagesUpdated: () => _updateLocalThreadPreview(thread.threadId),
                    nickname: thread.nickname,
                    title: thread.title,
                  ),
                ),
              );
            },
            onLongPress: () => _showChatOptions(context, thread),
          ),
        );
      },
    );
  }

  void _showChatOptions(BuildContext context, LocalThread thread) async {
    final options = <PopupMenuEntry<String>>[
      const PopupMenuItem(value: 'rename_nickname', child: Text('Change Nickname')),
      const PopupMenuItem(value: 'delete', child: Text('Delete Chat')),
    ];
    if (thread.aiMode != 'none') {
      options.insert(0, const PopupMenuItem(value: 'rename_ai', child: Text('Rename AI')));
    }
    final selected = await showMenu<String>(
      context: context,
      position: const RelativeRect.fromLTRB(0, 0, 0, 0),
      items: options,
    );
    if (selected == 'rename_ai') {
      _renameAIName(thread);
    } else if (selected == 'rename_nickname') {
      _renameNickname(thread);
    } else if (selected == 'delete') {
      _showDeleteChatDialog(context, thread);
    }
  }

  void _renameAIName(LocalThread thread) async {
    final controller = TextEditingController(text: thread.aiName);
    final newAIName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename AI'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'e.g., Coach, Buddy'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (newAIName != null && newAIName.isNotEmpty) {
      final updatedThread = thread.copyWith(aiName: newAIName);
      await MessageDatabase().saveLocalThread(updatedThread);
      final index = _localThreads.indexWhere((t) => t.threadId == thread.threadId);
      if (index != -1 && mounted) {
        setState(() {
          _localThreads[index] = updatedThread;
        });
      }
    }
  }

  void _renameNickname(LocalThread thread) async {
    final controller = TextEditingController(text: thread.nickname);
    final newNickname = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Nickname'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'e.g., Love, Babe, My Journal'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    final updatedThread = thread.copyWith(nickname: newNickname ?? '');
    await MessageDatabase().saveLocalThread(updatedThread);
    final index = _localThreads.indexWhere((t) => t.threadId == thread.threadId);
    if (index != -1 && mounted) {
      setState(() {
        _localThreads[index] = updatedThread;
      });
    }
  }

  void _createNewLocalChat() async {
    final action = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('New Chat'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'notes'),
            child: const Text('📝 Notes (User Only)'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'ai-always'),
            child: const Text('🤖 AI Companion (Replies to everything)'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'ai-on-demand'),
            child: const Text('🔖 Smart Notes (@AI to trigger)'),
          ),
        ],
      ),
    );
    if (action == null) return;
    final threadId = DateTime.now().millisecondsSinceEpoch.toString();
    String title, aiMode, aiName, nickname;
    switch (action) {
      case 'notes':
        title = 'Notes';
        nickname = 'My Notes';
        aiMode = 'none';
        aiName = '';
        break;
      case 'ai-always':
        title = 'Numina';
        nickname = 'Numina';
        aiMode = 'always';
        aiName = 'Numina';
        break;
      case 'ai-on-demand':
        title = 'Smart Notes';
        nickname = 'Smart Notes';
        aiMode = 'on-demand';
        aiName = 'Aetis';
        break;
      default:
        return;
    }
    final thread = LocalThread(
      threadId: threadId,
      title: title,
      nickname: nickname,
      lastMessageTime: DateTime.now().millisecondsSinceEpoch,
      aiMode: aiMode,
      aiName: aiName,
    );
    await MessageDatabase().saveLocalThread(thread);
    if (mounted) {
      setState(() {
        _localThreads.insert(0, thread);
      });
    }
  }

  void _showDeleteChatDialog(BuildContext context, LocalThread thread) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Chat"),
        content: Text('Delete "${thread.title}" and all its messages?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await MessageDatabase().deleteLocalThread(thread.threadId);
      final index = _localThreads.indexWhere((t) => t.threadId == thread.threadId);
      if (index != -1 && mounted) {
        setState(() {
          _localThreads.removeAt(index);
        });
      }
    }
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(time.year, time.month, time.day);
    if (messageDate == today) {
      final hour = time.hour > 12 ? time.hour - 12 : (time.hour == 0 ? 12 : time.hour);
      final period = time.hour >= 12 ? 'PM' : 'AM';
      return '${hour}:${time.minute.toString().padLeft(2, '0')} $period';
    }
    final yesterday = today.subtract(const Duration(days: 1));
    if (messageDate == yesterday) {
      return 'Yesterday';
    }
    final difference = today.difference(messageDate).inDays;
    if (difference < 7) {
      const days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
      return days[time.weekday % 7];
    }
    return '${time.month}/${time.day}/${time.year % 100}';
  }
}

extension LocalThreadCopyWith on LocalThread {
  LocalThread copyWith({
    String? threadId,
    String? title,
    String? nickname,
    int? lastMessageTime,
    String? aiMode,
    String? aiName,
  }) {
    return LocalThread(
      threadId: threadId ?? this.threadId,
      title: title ?? this.title,
      nickname: nickname ?? this.nickname,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      aiMode: aiMode ?? this.aiMode,
      aiName: aiName ?? this.aiName,
    );
  }
}