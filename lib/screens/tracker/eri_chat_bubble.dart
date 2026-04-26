// lib/screens/tracker/eri_chat_bubble.dart
//
// Usage: wrap full_period_tracker_page.dart body in a Stack and add:
//   EriChatBubble(isBoyfriend: _isBoyfriend)
//
// Messages are persisted to SharedPreferences so they survive app restarts.
// The reload (refresh) icon clears the conversation completely.
// Eri responses render full Markdown + LaTeX.

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:markdown_widget/markdown_widget.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/vs2015.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'eri_ai_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Colours
// ─────────────────────────────────────────────────────────────────────────────
const Color _kPink      = Color(0xFFE91E63);
const Color _kPinkLight = Color(0xFFF8BBD9);
const Color _kPinkDark  = Color(0xFFC2185B);
const Color _kBg        = Color(0xFFFFF0F5);
const Color _kSurface   = Colors.white;
const Color _kText      = Color(0xFF212121);
const Color _kGrey      = Color(0xFF9E9E9E);

// ─────────────────────────────────────────────────────────────────────────────
// EriChatBubble  ·  floating button
// ─────────────────────────────────────────────────────────────────────────────

class EriChatBubble extends StatefulWidget {
  final bool isBoyfriend;
  const EriChatBubble({super.key, this.isBoyfriend = false});

  @override
  State<EriChatBubble> createState() => _EriChatBubbleState();
}

class _EriChatBubbleState extends State<EriChatBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bounce;
  late final Animation<double>   _bounceAnim;

  // ── Draggable position ──────────────────────────────────────────────────────
  Offset? _pos;                        // (left, top) in screen coords
  bool    _isDragging = false;         // prevents tap firing after a drag
  static const String _kPrefX  = 'eri_bubble_x';
  static const String _kPrefY  = 'eri_bubble_y';
  static const double _kBubbleW = 80.0;  // safe width estimate for clamping
  static const double _kBubbleH = 98.0;  // pill + gap + avatar

  @override
  void initState() {
    super.initState();
    _bounce = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _bounceAnim = Tween<double>(begin: 0, end: -8).animate(
      CurvedAnimation(parent: _bounce, curve: Curves.easeInOut),
    );
    _loadPosition();
  }

  Future<void> _loadPosition() async {
    final prefs = await SharedPreferences.getInstance();
    final x = prefs.getDouble(_kPrefX);
    final y = prefs.getDouble(_kPrefY);
    if (mounted && x != null && y != null) {
      setState(() => _pos = Offset(x, y));
    }
  }

  Future<void> _savePosition(Offset pos) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kPrefX, pos.dx);
    await prefs.setDouble(_kPrefY, pos.dy);
  }

  /// Keeps the bubble fully on screen with a small margin.
  Offset _clamp(Offset pos, Size screen) {
    const m = 8.0;
    return Offset(
      pos.dx.clamp(m, screen.width  - _kBubbleW - m),
      pos.dy.clamp(m, screen.height - _kBubbleH - m),
    );
  }

  /// True when the bubble centre lands within 90 px of the screen centre.
  bool _isInCenter(Offset pos, Size screen) {
    final bx = pos.dx + _kBubbleW / 2;
    final by = pos.dy + _kBubbleH / 2;
    return (bx - screen.width  / 2).abs() < 90 &&
           (by - screen.height / 2).abs() < 90;
  }

  /// Snaps to the nearest screen-edge quadrant when dropped in the center zone.
  Offset _snapFromCenter(Offset pos, Size screen) {
    final bx = pos.dx + _kBubbleW / 2;
    final by = pos.dy + _kBubbleH / 2;
    final toRight  = bx >= screen.width  / 2;
    final toBottom = by >= screen.height / 2;
    return Offset(
      toRight  ? screen.width  - _kBubbleW - 16 : 16.0,
      toBottom ? screen.height * 0.72 : screen.height * 0.15,
    );
  }

  @override
  void dispose() {
    _bounce.dispose();
    super.dispose();
  }

  void _open() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      // Re-using the same sheet widget keeps state via the singleton service.
      builder: (_) => _EriChatSheet(isBoyfriend: widget.isBoyfriend),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.of(context).size;
    // Default: right side, ~55 % down — always visible and above the nav bar
    _pos ??= Offset(screen.width - _kBubbleW - 16, screen.height * 0.55);

    return Positioned(
      left: _pos!.dx,
      top:  _pos!.dy,
      child: GestureDetector(
        onPanStart: (_) {
          _isDragging = false;
          _bounce.stop(); // pause bounce while dragging
        },
        onPanUpdate: (details) {
          _isDragging = true;
          setState(() => _pos = _clamp(_pos! + details.delta, screen));
        },
        onPanEnd: (_) {
          _bounce.repeat(reverse: true);
          if (!_isDragging) {
            // No movement — treat as a tap
            _open();
          } else {
            if (_isInCenter(_pos!, screen)) {
              setState(() => _pos = _snapFromCenter(_pos!, screen));
            }
            _savePosition(_pos!);
          }
        },
        child: AnimatedBuilder(
          animation: _bounceAnim,
          builder: (_, __) => Transform.translate(
            offset: Offset(0, _bounceAnim.value),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Tooltip pill
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _kPinkDark,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                          color: _kPink.withOpacity(0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 3)),
                    ],
                  ),
                  child: const Text('Ask Eri',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ),
                const SizedBox(height: 6),
                // Avatar circle
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [_kPinkLight, _kPink],
                      center: Alignment.topLeft,
                      radius: 1.4,
                    ),
                    boxShadow: [
                      BoxShadow(
                          color: _kPink.withOpacity(0.5),
                          blurRadius: 16,
                          offset: const Offset(0, 6)),
                    ],
                  ),
                  child: const _EriAvatar(size: 64),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Eri Avatar  ·  pure-Flutter CustomPainter with blink + head-tilt
// ─────────────────────────────────────────────────────────────────────────────

class _EriAvatar extends StatefulWidget {
  final double size;
  final bool   isThinking;
  const _EriAvatar({this.size = 48, this.isThinking = false});

  @override
  State<_EriAvatar> createState() => _EriAvatarState();
}

class _EriAvatarState extends State<_EriAvatar> with TickerProviderStateMixin {
  late final AnimationController _blinkCtrl;
  late final AnimationController _tiltCtrl;
  late final Animation<double>   _blinkAnim;
  late final Animation<double>   _tiltAnim;

  @override
  void initState() {
    super.initState();
    _blinkCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 150));
    _blinkAnim = Tween<double>(begin: 1.0, end: 0.05)
        .animate(CurvedAnimation(parent: _blinkCtrl, curve: Curves.easeInOut));
    _scheduleBlink();

    _tiltCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2200))
      ..repeat(reverse: true);
    _tiltAnim = Tween<double>(begin: -0.08, end: 0.08)
        .animate(CurvedAnimation(parent: _tiltCtrl, curve: Curves.easeInOut));
  }

  void _scheduleBlink() async {
    while (mounted) {
      await Future.delayed(
          Duration(milliseconds: 2500 + math.Random().nextInt(2000)));
      if (!mounted) break;
      await _blinkCtrl.forward();
      await Future.delayed(const Duration(milliseconds: 80));
      if (!mounted) break;
      await _blinkCtrl.reverse();
    }
  }

  @override
  void dispose() {
    _blinkCtrl.dispose();
    _tiltCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_blinkAnim, _tiltAnim]),
      builder: (_, __) => Transform.rotate(
        angle: _tiltAnim.value,
        child: CustomPaint(
          size: Size(widget.size, widget.size),
          painter: _EriAvatarPainter(
              eyeScaleY: _blinkAnim.value, isThinking: widget.isThinking),
        ),
      ),
    );
  }
}

class _EriAvatarPainter extends CustomPainter {
  final double eyeScaleY;
  final bool   isThinking;
  _EriAvatarPainter({required this.eyeScaleY, required this.isThinking});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r  = size.width * 0.42;

    canvas.drawCircle(Offset(cx, cy), r, Paint()..color = const Color(0xFFF5E6EA));

    final cheek = Paint()..color = const Color(0xFFFFB3C6).withOpacity(0.55);
    canvas.drawCircle(Offset(cx - r * .45, cy + r * .2), r * .22, cheek);
    canvas.drawCircle(Offset(cx + r * .45, cy + r * .2), r * .22, cheek);

    final eyeR = r * .14;
    final eyePaint = Paint()..color = const Color(0xFF3D2C3A);
    for (final xo in [-r * .30, r * .30]) {
      canvas.save();
      canvas.translate(cx + xo, cy - r * .08);
      canvas.scale(1.0, eyeScaleY);
      canvas.drawCircle(Offset.zero, eyeR, eyePaint);
      canvas.drawCircle(Offset(eyeR * .3, -eyeR * .3), eyeR * .35,
          Paint()..color = Colors.white.withOpacity(0.8));
      canvas.restore();
    }

    final mp = Paint()
      ..color = const Color(0xFFE91E63)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * .025
      ..strokeCap = StrokeCap.round;
    final p = Path();
    if (isThinking) {
      p..moveTo(cx - r * .22, cy + r * .38)
       ..quadraticBezierTo(cx, cy + r * .30, cx + r * .22, cy + r * .38);
    } else {
      p..moveTo(cx - r * .28, cy + r * .32)
       ..quadraticBezierTo(cx, cy + r * .58, cx + r * .28, cy + r * .32);
    }
    canvas.drawPath(p, mp);

    final hair = Paint()..color = const Color(0xFF7B3F6E);
    canvas.drawCircle(Offset(cx - r * .72, cy - r * .60), r * .20, hair);
    canvas.drawCircle(Offset(cx + r * .72, cy - r * .60), r * .20, hair);
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r * .88),
      math.pi * 1.15, math.pi * .70, false,
      Paint()
        ..color = const Color(0xFF7B3F6E)
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * .065
        ..strokeCap = StrokeCap.round,
    );

    canvas.drawCircle(Offset(cx, cy), r,
        Paint()
          ..color = _kPink.withOpacity(0.25)
          ..style = PaintingStyle.stroke
          ..strokeWidth = size.width * .02);
  }

  @override
  bool shouldRepaint(_EriAvatarPainter o) =>
      o.eyeScaleY != eyeScaleY || o.isThinking != isThinking;
}

// ─────────────────────────────────────────────────────────────────────────────
// Chat Sheet
// ─────────────────────────────────────────────────────────────────────────────

class _EriChatSheet extends StatefulWidget {
  final bool isBoyfriend;
  const _EriChatSheet({required this.isBoyfriend});

  @override
  State<_EriChatSheet> createState() => _EriChatSheetState();
}

class _EriChatSheetState extends State<_EriChatSheet> {
  final EriAiService          _svc        = EriAiService();
  final TextEditingController _controller = TextEditingController();
  final ScrollController      _scroll     = ScrollController();
  final FocusNode             _focus      = FocusNode();

  // Loading states
  bool _isLoading         = false; // waiting for API reply
  bool _isInitialising    = false; // loading messages + context on first open

  static const List<String> _chips = [
    'Is my cycle normal?',
    'What phase am I in?',
    'What patterns do I have?',
    'Why do I feel this before my period?',
    'How do I track ovulation?',
    'What does stress do to my cycle?',
  ];

  // ── Lifecycle ───────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    setState(() => _isInitialising = true);
    // Load persisted messages first, then build context if needed
    await _svc.loadMessages();
    if (!_svc.isContextReady) await _svc.buildContext();
    if (mounted) {
      setState(() => _isInitialising = false);
      // Scroll to bottom after messages are loaded
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _scrollToBottom(jump: true));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  // ── Send ────────────────────────────────────────────────────────────────────

  Future<void> _send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _isLoading || _isInitialising) return;

    _controller.clear();
    // NOTE: Do NOT append to _svc.messages here.
    // EriAiService.sendMessage() appends BOTH the user message and the reply,
    // so we only need to trigger a rebuild after it returns.
    setState(() => _isLoading = true);
    _scrollToBottom();

    try {
      await _svc.sendMessage(trimmed, isBoyfriend: widget.isBoyfriend);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        _scrollToBottom();
      }
    }
  }

  // ── Reload (clear) ──────────────────────────────────────────────────────────

  Future<void> _reload() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear conversation?'),
        content: const Text(
            'This will delete your entire chat history with Eri. This cannot be undone.'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel', style: TextStyle(color: _kGrey))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Clear',
                  style: TextStyle(
                      color: _kPinkDark, fontWeight: FontWeight.bold))),
        ],
      ),
    );
    if (confirmed != true) return;

    await _svc.resetConversation();
    if (mounted) {
      setState(() {
        _isLoading = false;
        _isInitialising = false;
      });
      // Rebuild context silently in the background
      _svc.buildContext();
    }
  }

  // ── Scroll ──────────────────────────────────────────────────────────────────

  void _scrollToBottom({bool jump = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      final target = _scroll.position.maxScrollExtent + 120;
      if (jump) {
        _scroll.jumpTo(target);
      } else {
        _scroll.animateTo(target,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut);
      }
    });
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final msgs        = _svc.messages;

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: _kBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          _buildHandle(),
          _buildHeader(),
          if (_isInitialising)
            _buildLoader()
          else ...[
            Expanded(child: _buildMessageList(msgs)),
            if (msgs.isEmpty) _buildChips(),
          ],
          _buildInputBar(bottomInset),
        ],
      ),
    );
  }

  // ── Drag handle ─────────────────────────────────────────────────────────────

  Widget _buildHandle() {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Center(
        child: Container(
          width: 36, height: 4,
          decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2)),
        ),
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 8, 8, 12),
      decoration: BoxDecoration(
        color: _kSurface,
        boxShadow: [
          BoxShadow(
              color: _kPink.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Row(
        children: [
          const SizedBox(width: 36, height: 36, child: _EriAvatar(size: 36)),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Eri',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _kPinkDark)),
              Text('Period Assistant',
                  style: TextStyle(fontSize: 12, color: _kGrey)),
            ],
          ),
          const Spacer(),
          // Reload / clear conversation button
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            color: _kGrey,
            tooltip: 'Clear conversation',
            onPressed: _isInitialising ? null : _reload,
          ),
        ],
      ),
    );
  }

  // ── Loader (initial load) ───────────────────────────────────────────────────

  Widget _buildLoader() {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
                width: 56,
                height: 56,
                child: _EriAvatar(size: 56, isThinking: true)),
            const SizedBox(height: 14),
            Text('Analyzing your cycle data…',
                style: TextStyle(
                    color: _kPinkDark,
                    fontSize: 14,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 10),
            SizedBox(
              width: 180,
              child: LinearProgressIndicator(
                backgroundColor: _kPinkLight,
                color: _kPink,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Message list ─────────────────────────────────────────────────────────────

  Widget _buildMessageList(List<EriChatMessage> msgs) {
    if (msgs.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
                width: 100, height: 100, child: _EriAvatar(size: 100)),
            const SizedBox(height: 16),
            Text("Hi! I'm Eri",
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: _kPinkDark)),
            const SizedBox(height: 6),
            Text(
              widget.isBoyfriend
                  ? "Ask me about your partner's cycle"
                  : 'Your personal period assistant',
              style: TextStyle(fontSize: 14, color: _kGrey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      itemCount: msgs.length + (_isLoading ? 1 : 0),
      itemBuilder: (_, i) {
        if (i == msgs.length) return _buildTypingIndicator();
        return _buildBubble(msgs[i]);
      },
    );
  }

  // ── Single bubble ────────────────────────────────────────────────────────────

  Widget _buildBubble(EriChatMessage msg) {
    final isUser = msg.isUser;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            const SizedBox(
                width: 32, height: 32, child: _EriAvatar(size: 32)),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser ? _kPink : _kSurface,
                borderRadius: BorderRadius.only(
                  topLeft:     const Radius.circular(20),
                  topRight:    const Radius.circular(20),
                  bottomLeft:  Radius.circular(isUser ? 20 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 20),
                ),
                boxShadow: [
                  BoxShadow(
                      color: (isUser ? _kPink : Colors.black).withOpacity(0.12),
                      blurRadius: 8,
                      offset: const Offset(0, 2)),
                ],
              ),
              // User → plain text;  Eri → Markdown + LaTeX
              child: isUser
                  ? Text(msg.text,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 15, height: 1.45))
                  : _buildEriContent(msg.text),
            ),
          ),
          if (isUser) const SizedBox(width: 4),
        ],
      ),
    );
  }

  // ── Markdown + LaTeX renderer ────────────────────────────────────────────────

  Widget _buildEriContent(String raw) {
    return _buildMarkdown(_preprocessLatex(raw));
  }

  // Convert LaTeX delimiters to readable Unicode before Markdown render
  String _preprocessLatex(String text) {
    var r = text;
    r = r.replaceAllMapped(RegExp(r'\$\$([\s\S]+?)\$\$'),
        (m) => _latex(m.group(1)!.trim()));
    r = r.replaceAllMapped(RegExp(r'\\\[([\s\S]+?)\\\]'),
        (m) => _latex(m.group(1)!.trim()));
    r = r.replaceAllMapped(RegExp(r'\\\(([^)]+?)\\\)'),
        (m) => _latex(m.group(1)!.trim()));
    r = r.replaceAllMapped(RegExp(r'\$([^\$\n]+?)\$'),
        (m) => _latex(m.group(1)!.trim()));
    return _latex(r);
  }

  String _latex(String s) {
    s = s.replaceAllMapped(RegExp(r'\\frac\{([^}]+)\}\{([^}]+)\}'),
        (m) => '(${m.group(1)})/(${m.group(2)})');
    s = s.replaceAllMapped(RegExp(r'\^\{([^}]+)\}'), (m) => '^${m.group(1)}');
    s = s.replaceAllMapped(RegExp(r'_\{([^}]+)\}'),  (m) => '_${m.group(1)}');
    s = s.replaceAllMapped(RegExp(r'\\sqrt\{([^}]+)\}'),
        (m) => '√(${m.group(1)})');
    const Map<String, String> subs = {
      r'\approx': '≈', r'\neq': '≠',   r'\leq': '≤',  r'\geq': '≥',
      r'\times':  '×', r'\div': '÷',   r'\pm':  '±',  r'\infty': '∞',
      r'\sum':    '∑', r'\prod': '∏',  r'\int': '∫',  r'\pi': 'π',
      r'\theta':  'θ', r'\alpha': 'α', r'\beta': 'β', r'\gamma': 'γ',
      r'\delta':  'δ', r'\lambda': 'λ',r'\mu':  'μ',  r'\sigma': 'σ',
      r'\omega':  'ω', r'\Delta': 'Δ', r'\Sigma': 'Σ',r'\cdot': '·',
      r'\ldots':  '…', r'\dots': '…',
      r'\left(':  '(', r'\right)': ')','\\left[': '[', r'\right]': ']',
      r'\left|':  '|', r'\right|': '|',
      r'\text{':  '',  r'\mathrm{': '','\\mathbf{': '','\\mathit{': '',
    };
    subs.forEach((k, v) => s = s.replaceAll(k, v));
    s = s.replaceAllMapped(RegExp(r'\\[a-zA-Z]+\{([^}]*)\}'),
        (m) => m.group(1)!);
    s = s.replaceAll(RegExp(r'\\[a-zA-Z]+'), '');
    s = s.replaceAll('{', '').replaceAll('}', '');
    return s.trim();
  }

  Widget _buildMarkdown(String text) {
    return MarkdownWidget(
      data: text,
      shrinkWrap: true,
      selectable: true,
      config: MarkdownConfig(
        configs: [
          PreConfig(
            wrapper: (child, code, language) =>
                _codeBlock(code, language),
          ),
          CodeConfig(
            style: TextStyle(
              backgroundColor: Colors.pink.shade50,
              color: _kPinkDark,
              fontFamily: 'monospace',
              fontSize: 14,
            ),
          ),
          TableConfig(
            wrapper: (t) =>
                SingleChildScrollView(scrollDirection: Axis.horizontal, child: t),
            defaultColumnWidth: const IntrinsicColumnWidth(),
            border:
                TableBorder.all(color: Colors.pink.shade200, width: 1),
          ),
          PConfig(
            textStyle: const TextStyle(
                fontSize: 15, color: _kText, height: 1.5),
          ),
          H1Config(
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: _kPinkDark)),
          H2Config(
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _kPinkDark)),
          H3Config(
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _kPinkDark)),
          BlockquoteConfig(
            sideColor: _kPink,
            textColor: Colors.black54,
            sideWith: 3,
            padding: const EdgeInsets.only(left: 12, top: 8, bottom: 8),
            margin: const EdgeInsets.symmetric(vertical: 8),
          ),
          ListConfig(
            marker: (ordered, depth, index) {
              if (ordered)    return Text('${index + 1}. ');
              if (depth == 0) return const Text('• ');
              if (depth == 1) return const Text('◦ ');
              return const Text('▪ ');
            },
          ),
        ],
      ),
    );
  }

  Widget _codeBlock(String code, String? lang) {
    final sc = ScrollController();
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
          color: Colors.grey.shade900,
          borderRadius: BorderRadius.circular(8)),
      child: Stack(
        children: [
          Scrollbar(
            controller: sc,
            thumbVisibility: false,
            child: SingleChildScrollView(
              controller: sc,
              scrollDirection: Axis.horizontal,
              child: HighlightView(
                code,
                language: lang ?? 'plaintext',
                theme: vs2015Theme,
                padding: const EdgeInsets.fromLTRB(12, 32, 12, 12),
                textStyle:
                    const TextStyle(fontFamily: 'monospace', fontSize: 13),
              ),
            ),
          ),
          Positioned(
            top: 6, right: 6,
            child: GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: code));
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: const Text('Copied'),
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: _kPinkDark,
                ));
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.white24)),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.copy, size: 12, color: Colors.white70),
                    SizedBox(width: 4),
                    Text('Copy',
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.white70,
                            fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Typing indicator ─────────────────────────────────────────────────────────

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const SizedBox(
              width: 32,
              height: 32,
              child: _EriAvatar(size: 32, isThinking: true)),
          const SizedBox(width: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: _kSurface,
              borderRadius: const BorderRadius.only(
                topLeft:     Radius.circular(20),
                topRight:    Radius.circular(20),
                bottomRight: Radius.circular(20),
                bottomLeft:  Radius.circular(4),
              ),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 6,
                    offset: const Offset(0, 2))
              ],
            ),
            child: const _TypingDots(),
          ),
        ],
      ),
    );
  }

  // ── Suggestion chips ─────────────────────────────────────────────────────────

  Widget _buildChips() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text('Suggested questions',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _kGrey,
                    letterSpacing: 0.5)),
          ),
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _chips.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) => GestureDetector(
                onTap: () => _send(_chips[i]),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: _kSurface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _kPink.withOpacity(0.4)),
                    boxShadow: [
                      BoxShadow(
                          color: _kPink.withOpacity(0.08),
                          blurRadius: 4,
                          offset: const Offset(0, 2))
                    ],
                  ),
                  child: Text(_chips[i],
                      style: TextStyle(
                          color: _kPinkDark,
                          fontSize: 13,
                          fontWeight: FontWeight.w500)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Input bar ────────────────────────────────────────────────────────────────

  Widget _buildInputBar(double bottomInset) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 10, 12, 16 + bottomInset),
      decoration: BoxDecoration(
        color: _kSurface,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, -3))
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 130),
              decoration: BoxDecoration(
                color: _kBg,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: _kPink.withOpacity(0.3)),
              ),
              child: TextField(
                controller: _controller,
                focusNode: _focus,
                maxLines: null,
                minLines: 1,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                style: const TextStyle(fontSize: 15, color: _kText),
                decoration: const InputDecoration(
                  hintText: 'Ask Eri about your cycle…',
                  hintStyle: TextStyle(color: _kGrey, fontSize: 14),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  border: InputBorder.none,
                ),
                onSubmitted: (_) => _send(_controller.text),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _send(_controller.text),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 46, height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isLoading ? Colors.grey.shade300 : _kPink,
                boxShadow: _isLoading
                    ? []
                    : [
                        BoxShadow(
                            color: _kPink.withOpacity(0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 4))
                      ],
              ),
              child: Icon(
                _isLoading ? Icons.hourglass_empty : Icons.send_rounded,
                color: _isLoading ? _kGrey : Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Typing dots
// ─────────────────────────────────────────────────────────────────────────────

class _TypingDots extends StatefulWidget {
  const _TypingDots();
  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1000))
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final t = _ctrl.value;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final phase = (t - i * 0.2).clamp(0.0, 1.0);
            final scale = 0.6 + 0.4 * math.sin(phase * math.pi);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Transform.scale(
                scale: scale,
                child: Container(
                  width: 8, height: 8,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _kPink.withOpacity(0.7)),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
