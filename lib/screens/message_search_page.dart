// lib/screens/message_search_page.dart
import 'dart:core';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/message_database.dart';
import 'messaging_page.dart';
import 'package:markdown_widget/markdown_widget.dart';

class MessageSearchPage extends StatefulWidget {
  final List<LocalThread> localThreads;
  final String? firebasePairId;

  const MessageSearchPage({
    super.key,
    required this.localThreads,
    required this.firebasePairId,
  });

  @override
  State<MessageSearchPage> createState() => _MessageSearchPageState();
}

class SearchResult {
  final LocalThread? localThread;
  final String? firebasePairId;
  final MessageModel message;
  final String threadDisplayName;

  SearchResult({
    this.localThread,
    this.firebasePairId,
    required this.message,
    required this.threadDisplayName,
  });
}

class _MessageSearchPageState extends State<MessageSearchPage> {
  final TextEditingController _searchController = TextEditingController();
  List<SearchResult> _searchResults = [];
  bool _hasSearched = false;

  // Helper: Creates a markdown snippet with highlighted search term
  Widget _buildHighlightedMarkdownSnippet(String text, String query) {
    if (query.isEmpty) {
      return _buildMarkdownSnippet(text);
    }

    const contextChars = 80;
    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final index = lowerText.indexOf(lowerQuery);

    String displayText = text;

    if (index != -1) {
      int start = (index - contextChars).clamp(0, text.length);
      int end = (index + query.length + contextChars).clamp(0, text.length);

      displayText = text.substring(start, end);
      if (start > 0) displayText = '… $displayText';
      if (end < text.length) displayText = '$displayText …';
    }

    // Wrap the search term in bold markdown for highlighting
    final escapedQuery = RegExp.escape(query);
    final regex = RegExp('($escapedQuery)', caseSensitive: false);
    final highlightedText = displayText.replaceAllMapped(
      regex,
          (match) => '**${match.group(0)}**',
    );

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: MarkdownWidget(
        data: highlightedText,
        shrinkWrap: true,
        selectable: false,
        config: MarkdownConfig(
          configs: [
            PreConfig(
              wrapper: (child, code, language) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '[code]',
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontSize: 13,
                      fontFamily: 'monospace',
                    ),
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
              textStyle: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
                height: 1.4,
              ),
            ),
            H1Config(
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            H2Config(
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            H3Config(
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
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
              textColor: Colors.black54,
              sideWith: 2,
              padding: const EdgeInsets.only(left: 8),
              margin: EdgeInsets.zero,
            ),
            // Note: Bold text (used for highlighting) is styled here
            PConfig(
              textStyle: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Build markdown snippet without highlighting (for fallback)
  Widget _buildMarkdownSnippet(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: MarkdownWidget(
        data: text.length > 200 ? '${text.substring(0, 200)}…' : text,
        shrinkWrap: true,
        selectable: false,
        config: MarkdownConfig(
          configs: [
            PreConfig(
              wrapper: (child, code, language) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '[code]',
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontSize: 13,
                      fontFamily: 'monospace',
                    ),
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
              textStyle: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
                height: 1.4,
              ),
            ),
            H1Config(
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            H2Config(
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            H3Config(
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
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
              textColor: Colors.black54,
              sideWith: 2,
              padding: const EdgeInsets.only(left: 8),
              margin: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _performSearch() async {
    final rawQuery = _searchController.text.trim();

    if (rawQuery.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a search term')),
      );
      return;
    }

    final escaped = RegExp.escape(rawQuery);
    final wordRegex = RegExp('\\b$escaped\\b', caseSensitive: false);

    final db = MessageDatabase();
    final allMessages = <MessageModel>[];

    // Load local threads
    for (final thread in widget.localThreads) {
      final msgs = await db.getMessagesByThreadId(thread.threadId);
      allMessages.addAll(msgs);
    }

    // Load firebase messages if available
    if (widget.firebasePairId != null) {
      final firebaseMsgs = await db.getMessagesByThreadId(widget.firebasePairId!);
      allMessages.addAll(firebaseMsgs);
    }

    final matched = allMessages
        .where((msg) => wordRegex.hasMatch(msg.text))
        .toList();

    matched.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    final results = <SearchResult>[];
    for (final msg in matched) {
      String displayName;
      LocalThread? localThread;
      String? firebaseId;

      if (msg.threadType == 'local') {
        final thread = widget.localThreads.firstWhere(
              (t) => t.threadId == msg.threadId,
          orElse: () => LocalThread(
            threadId: msg.threadId,
            title: 'Unknown Thread',
            lastMessageTime: 0,
          ),
        );
        displayName = thread.nickname.isNotEmpty ? thread.nickname : thread.title;
        localThread = thread;
      } else {
        displayName = 'Your Match';
        firebaseId = widget.firebasePairId;
      }

      results.add(SearchResult(
        localThread: localThread,
        firebasePairId: firebaseId,
        message: msg,
        threadDisplayName: displayName,
      ));
    }

    setState(() {
      _searchResults = results;
      _hasSearched = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search Messages'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search messages...',
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onSubmitted: (_) => _performSearch(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _performSearch,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  child: const Text('Search', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
          if (_hasSearched)
            Expanded(
              child: _searchResults.isEmpty
                  ? const Center(child: Text('No results found.'))
                  : ListView.builder(
                itemCount: _searchResults.length,
                itemBuilder: (context, index) {
                  final result = _searchResults[index];
                  final msg = result.message;
                  final msgTime =
                  DateTime.fromMillisecondsSinceEpoch(msg.timestamp);
                  final timeDisplay = _formatTime(msgTime);
                  final dateDisplay =
                  DateFormat('MMM d, yyyy').format(msgTime);

                  return Card(
                    margin: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(12),
                      title: Text(
                        result.threadDisplayName,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          _buildHighlightedMarkdownSnippet(
                            msg.text,
                            _searchController.text.trim(),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '$timeDisplay • $dateDisplay • ${msg.isMe ? "You" : "Them"}',
                            style: const TextStyle(
                                fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ),
                      onTap: () {
                        Navigator.pop(context); // close search
                        if (result.localThread != null) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => MessagingPage(
                                threadId: result.localThread!.threadId,
                                threadType: 'local',
                                myRole: 'user',
                                aiMode: result.localThread!.aiMode ?? 'none',
                                aiName: result.localThread!.aiName ?? '',
                                nickname: result.localThread!.nickname ?? '',
                                title: result.localThread!.title ?? '',
                                highlightMessageId: msg.id,
                              ),
                            ),
                          );
                        } else if (result.firebasePairId != null) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => MessagingPage(
                                threadId: result.firebasePairId!,
                                threadType: 'firebase',
                                myRole: 'user',
                                highlightMessageId: msg.id,
                              ),
                            ),
                          );
                        }
                      },
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
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
    return DateFormat('MMM d').format(time);
  }
}