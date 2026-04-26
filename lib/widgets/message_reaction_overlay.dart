// lib/widgets/message_reaction_overlay.dart
import 'package:flutter/material.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';

class MessageReactionOverlay extends StatefulWidget {
  final Offset tapPosition;
  final String messageId;
  final bool isMyMessage;
  final String? currentUserReaction;
  final Function(String emoji) onReactionSelected;
  final VoidCallback onReply;
  final VoidCallback? onEdit;
  final VoidCallback? onUnsend;
  final VoidCallback onDismiss;

  const MessageReactionOverlay({
    super.key,
    required this.tapPosition,
    required this.messageId,
    required this.isMyMessage,
    this.currentUserReaction,
    required this.onReactionSelected,
    required this.onReply,
    this.onEdit,
    this.onUnsend,
    required this.onDismiss,
  });

  @override
  State<MessageReactionOverlay> createState() => _MessageReactionOverlayState();
}

class _MessageReactionOverlayState extends State<MessageReactionOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  final List<String> _defaultEmojis = ['❤️', '😂', '😮', '😢', '😡', '👍'];
  late List<String> _customEmojis = [];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 180),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _showEmojiPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Pick an emoji',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: EmojiPicker(
                onEmojiSelected: (category, emoji) {
                  Navigator.pop(context);
                  final emojiChar = emoji.emoji;

                  if (!_defaultEmojis.contains(emojiChar) &&
                      !_customEmojis.contains(emojiChar)) {
                    setState(() {
                      if (_customEmojis.length >= 2) {
                        _customEmojis.removeAt(0);
                      }
                      _customEmojis.add(emojiChar);
                    });
                  }

                  widget.onReactionSelected(emojiChar);
                  widget.onDismiss();
                },
                config: const Config(
                  height: 256,
                  checkPlatformCompatibility: true,
                  emojiViewConfig: EmojiViewConfig(
                    emojiSizeMax: 28,
                    columns: 7,
                    backgroundColor: Colors.white,
                  ),
                  categoryViewConfig: CategoryViewConfig(
                    indicatorColor: Color(0xFF007AFF),
                    iconColorSelected: Color(0xFF007AFF),
                  ),
                  bottomActionBarConfig: BottomActionBarConfig(
                    enabled: false,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    double reactionBarTop = widget.tapPosition.dy - 70;
    if (reactionBarTop < 100) {
      reactionBarTop = widget.tapPosition.dy + 60;
    }

    final actionMenuTop = reactionBarTop + 60;

    final allEmojis = [..._defaultEmojis, ..._customEmojis];

    return GestureDetector(
      onTap: widget.onDismiss,
      child: Container(
        color: Colors.black26,
        child: Stack(
          children: [
            // Reaction Bar
            Positioned(
              top: reactionBarTop,
              left: (screenSize.width - 360) / 2,
              child: FadeTransition(
                opacity: _opacityAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: Container(
                    height: 56,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2C2C2E),
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ...allEmojis.map((emoji) => _buildReactionButton(emoji)),
                        _buildAddButton(),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Action Menu
            Positioned(
              top: actionMenuTop,
              left: (screenSize.width - 200) / 2,
              child: FadeTransition(
                opacity: _opacityAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: Container(
                    width: 200,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildActionItem(
                          icon: Icons.reply,
                          label: 'Reply',
                          onTap: () {
                            widget.onReply();
                            widget.onDismiss();
                          },
                        ),
                        if (widget.isMyMessage && widget.onEdit != null) ...[
                          const Divider(height: 1),
                          _buildActionItem(
                            icon: Icons.edit,
                            label: 'Edit',
                            onTap: () {
                              widget.onEdit!();
                              widget.onDismiss();
                            },
                          ),
                        ],
                        if (widget.isMyMessage && widget.onUnsend != null) ...[
                          const Divider(height: 1),
                          _buildActionItem(
                            icon: Icons.delete_outline,
                            label: 'Delete',
                            color: Colors.red,
                            onTap: () {
                              widget.onDismiss();
                              widget.onUnsend!();
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReactionButton(String emoji) {
    final isSelected = widget.currentUserReaction == emoji;

    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 100),
      tween: Tween(begin: 1.0, end: isSelected ? 1.1 : 1.0),
      builder: (context, scale, child) {
        return Transform.scale(
          scale: scale,
          child: GestureDetector(
            onTapDown: (_) {},
            onTapUp: (_) {
              widget.onReactionSelected(emoji);
              widget.onDismiss();
            },
            child: Container(
              width: 44,
              height: 44,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withOpacity(0.2)
                    : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  emoji,
                  style: const TextStyle(fontSize: 24),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAddButton() {
    return GestureDetector(
      onTap: _showEmojiPicker,
      child: Container(
        width: 44,
        height: 44,
        margin: const EdgeInsets.only(left: 2),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.add,
          color: Colors.white,
          size: 20,
        ),
      ),
    );
  }

  Widget _buildActionItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Icon(icon, size: 20, color: color ?? Colors.black87),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  color: color ?? Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}