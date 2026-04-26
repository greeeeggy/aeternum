// lib/services/messaging_service.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../database/message_database.dart';
import 'onesignal_service.dart';

class MessagingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final MessageDatabase _localDb = MessageDatabase();
  final String _myUid = FirebaseAuth.instance.currentUser!.uid;
  final StreamController<List<MessageModel>> _messageStreamController =
  StreamController<List<MessageModel>>.broadcast();
  Stream<List<MessageModel>> get messages => _messageStreamController.stream;
  String get myUid => _myUid;


  late String _currentThreadId;
  StreamSubscription<QuerySnapshot>? _messagesSubscription;

  Future<void> initChat(String threadId) async {
    _currentThreadId = threadId;

    final cachedMessages = await _localDb.getMessagesByThreadId(threadId);
    _messageStreamController.add(cachedMessages);

    _messagesSubscription = _firestore
        .collection('messages')
        .doc(_currentThreadId)
        .collection('chats')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .listen((snapshot) {
      final List<MessageModel> messages = [];
      for (final doc in snapshot.docs) {
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

        // ✅ Parse reactions from Firebase
        Map<String, String> reactions = {};
        if (data['reactions'] != null && data['reactions'] is Map) {
          reactions = Map<String, String>.from(data['reactions']);
        }

        // ✅ Check if message is deleted (tombstone)
        final isDeleted = data['isDeleted'] as bool? ?? false;

        final msg = MessageModel(
          id: doc.id,
          senderUid: data['senderUid'] as String,
          text: data['text'] as String? ?? '',
          timestamp: msgTimestamp,
          isRead: (data['readBy'] as List?)?.contains(_myUid) ?? false,
          isMe: data['senderUid'] == _myUid,
          threadId: _currentThreadId,
          threadType: 'firebase',
          reactions: reactions,
          isDeleted: isDeleted,
          replyToId: data['replyToId'] as String?,
        );
        messages.add(msg);
      }

      _localDb.replaceMessagesForThread(_currentThreadId, messages);
      _messageStreamController.add(messages);
    });
  }

  Future<void> sendMessage(String text, {String? replyToId}) async {
    final docRef = _firestore
        .collection('messages')
        .doc(_currentThreadId)
        .collection('chats')
        .doc();

    await docRef.set({
      'senderUid': _myUid,
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
      'readBy': [_myUid],
      'reactions': {},
      'isDeleted': false,
      if (replyToId != null) 'replyToId': replyToId,
    });

    // NEW: Trigger OneSignal Notification to partner
    _triggerOneSignalNotification(text);
  }

  Future<void> _triggerOneSignalNotification(String text) async {
    try {
      final coupleDoc = await _firestore.collection('couples').doc(_currentThreadId).get();
      if (coupleDoc.exists) {
        final members = List<String>.from(coupleDoc.data()?['members'] ?? []);
        final partnerUid = members.firstWhere((uid) => uid != _myUid, orElse: () => '');
        if (partnerUid.isNotEmpty) {
          await OneSignalService().sendNotification(
            targetExternalIds: [partnerUid],
            title: 'New Message',
            content: text,
            data: {'threadId': _currentThreadId},
          );
        }
      }
    } catch (e) {
      print('Error triggering OneSignal notification: $e');
    }
  }

  Future<void> addReaction(String messageId, String emoji) async {
    try {
      await _firestore
          .collection('messages')
          .doc(_currentThreadId)
          .collection('chats')
          .doc(messageId)
          .update({
        'reactions.$_myUid': emoji,
      });
    } catch (e) {
      print('Error adding reaction: $e');
    }
  }

  Future<void> removeReaction(String messageId) async {
    try {
      await _firestore
          .collection('messages')
          .doc(_currentThreadId)
          .collection('chats')
          .doc(messageId)
          .update({
        'reactions.$_myUid': FieldValue.delete(),
      });
    } catch (e) {
      print('Error removing reaction: $e');
    }
  }

  Future<void> editMessage(String messageId, String newText) async {
    try {
      await _firestore
          .collection('messages')
          .doc(_currentThreadId)
          .collection('chats')
          .doc(messageId)
          .update({
        'text': newText,
      });
    } catch (e) {
      print('Error editing message: $e');
    }
  }

  // ✅ UPDATED: Hard delete (create tombstone in Firebase)
  Future<void> deleteMessage(String messageId) async {
    try {
      await _firestore
          .collection('messages')
          .doc(_currentThreadId)
          .collection('chats')
          .doc(messageId)
          .update({
        'isDeleted': true,
        'text': '', // Clear text to save storage
        'reactions': {}, // Clear reactions to save storage
        'replyToId': FieldValue.delete(), // Remove reply reference
      });
      print('✅ Firebase message tombstone created: $messageId');
    } catch (e) {
      print('Error deleting message: $e');
    }
  }

  void dispose() {
    _messagesSubscription?.cancel();
    _messageStreamController.close();
  }
}