// lib/screens/tracker/aero_chat_bubble.dart
//
// Usage: wrap boyfriend_period_viewer_page.dart body in a Stack and add:
//   AeroChatBubble()
//
// Messages are persisted to SharedPreferences so they survive app restarts.
// The reload (refresh) icon clears the conversation completely.
// Aero responses render full Markdown.

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:markdown_widget/markdown_widget.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/vs2015.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'aero_ai_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Colours  (teal / blue palette — matches BoyfriendPeriodViewerPage)
// ─────────────────────────────────────────────────────────────────────────────
const Color _kTeal      = Color(0xFF0B7285);
const Color _kTealLight = Color(0xFFB2EBF2);
const Color _kTealDark  = Color(0xFF005F73);
const Color _kBg        = Color(0xFFF0F8FA);
const Color _kSurface   = Colors.white;
const Color _kText      = Color(0xFF1F2A44);
const Color _kGrey      = Color(0xFF6B7280);

// ─────────────────────────────────────────────────────────────────────────────
// AeroChatBubble  ·  floating button
// ─────────────────────────────────────────────────────────────────────────────

class AeroChatBubble extends StatefulWidget {
  const AeroChatBubble({super.key});

  @override
  State<AeroChatBubble> createState() => _AeroChatBubbleState();
}

class _AeroChatBubbleState extends State<AeroChatBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bounce;
  late final Animation<double>   _bounceAnim;

  // ── Draggable position ──────────────────────────────────────────────────────
  Offset? _pos;
  bool    _isDragging = false;
  static const String _kPrefX  = 'aero_bubble_x';
  static const String _kPrefY  = 'aero_bubble_y';
  static const double _kBubbleW = 80.0;
  static const double _kBubbleH = 98.0;

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

  Offset _clamp(Offset pos, Size screen) {
    const m = 8.0;
    return Offset(
      pos.dx.clamp(m, screen.width  - _kBubbleW - m),
      pos.dy.clamp(m, screen.height - _kBubbleH - m),
    );
  }

  bool _isInCenter(Offset pos, Size screen) {
    final bx = pos.dx + _kBubbleW / 2;
    final by = pos.dy + _kBubbleH / 2;
    return (bx - screen.width  / 2).abs() < 90 &&
           (by - screen.height / 2).abs() < 90;
  }

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
      builder: (_) => const _AeroChatSheet(),
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
          _bounce.stop();
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
                    color: _kTealDark,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                          color: _kTeal.withOpacity(0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 3)),
                    ],
                  ),
                  child: const Text('Ask Aero',
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
                      colors: [_kTealLight, _kTeal],
                      center: Alignment.topLeft,
                      radius: 1.4,
                    ),
                    boxShadow: [
                      BoxShadow(
                          color: _kTeal.withOpacity(0.5),
                          blurRadius: 16,
                          offset: const Offset(0, 6)),
                    ],
                  ),
                  child: const _AeroAvatar(size: 64),
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
// Aero Avatar  ·  male character with blink + head-tilt
// ─────────────────────────────────────────────────────────────────────────────

class _AeroAvatar extends StatefulWidget {
  final double size;
  final bool   isThinking;
  const _AeroAvatar({this.size = 48, this.isThinking = false});

  @override
  State<_AeroAvatar> createState() => _AeroAvatarState();
}

class _AeroAvatarState extends State<_AeroAvatar> with TickerProviderStateMixin {
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
    _tiltAnim = Tween<double>(begin: -0.06, end: 0.06)
        .animate(CurvedAnimation(parent: _tiltCtrl, curve: Curves.easeInOut));
  }

  void _scheduleBlink() async {
    while (mounted) {
      await Future.delayed(
          Duration(milliseconds: 2800 + math.Random().nextInt(2000)));
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
          painter: _AeroAvatarPainter(
              eyeScaleY: _blinkAnim.value, isThinking: widget.isThinking),
        ),
      ),
    );
  }
}

class _AeroAvatarPainter extends CustomPainter {
  final double eyeScaleY;
  final bool   isThinking;
  _AeroAvatarPainter({required this.eyeScaleY, required this.isThinking});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r  = size.width * 0.42;

    // Face base — slightly warmer cool tone
    canvas.drawCircle(Offset(cx, cy), r,
        Paint()..color = const Color(0xFFDFF0F5));

    // Subtle jaw / cheekbone shading
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy + r * .15), width: r * 1.6, height: r * 1.1),
      Paint()..color = const Color(0xFFCCE8EF).withOpacity(0.55),
    );

    // Eyes
    final eyeR = r * .14;
    final eyePaint = Paint()..color = const Color(0xFF1F2A44);
    for (final xo in [-r * .30, r * .30]) {
      canvas.save();
      canvas.translate(cx + xo, cy - r * .08);
      canvas.scale(1.0, eyeScaleY);
      canvas.drawCircle(Offset.zero, eyeR, eyePaint);
      // Eye shine
      canvas.drawCircle(Offset(eyeR * .3, -eyeR * .3), eyeR * .35,
          Paint()..color = Colors.white.withOpacity(0.8));
      canvas.restore();
    }

    // Brow — slightly angular for masculine look
    final browPaint = Paint()
      ..color = const Color(0xFF1F2A44)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * .025
      ..strokeCap = StrokeCap.round;
    for (final xo in [-r * .30, r * .30]) {
      final bPath = Path()
        ..moveTo(cx + xo - r * .15, cy - r * .28)
        ..lineTo(cx + xo + r * .15, cy - r * .22);
      canvas.drawPath(bPath, browPaint);
    }

    // Mouth
    final mp = Paint()
      ..color = _kTeal
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * .025
      ..strokeCap = StrokeCap.round;
    final p = Path();
    if (isThinking) {
      // Straight / slightly curved thinking mouth
      p..moveTo(cx - r * .20, cy + r * .38)
       ..quadraticBezierTo(cx, cy + r * .32, cx + r * .20, cy + r * .38);
    } else {
      // Calm confident smile
      p..moveTo(cx - r * .26, cy + r * .30)
       ..quadraticBezierTo(cx, cy + r * .52, cx + r * .26, cy + r * .30);
    }
    canvas.drawPath(p, mp);

    // Short hair — flat-top / cropped style
    final hairPaint = Paint()..color = const Color(0xFF1F2A44);
    // Side locks
    canvas.drawCircle(Offset(cx - r * .75, cy - r * .45), r * .18, hairPaint);
    canvas.drawCircle(Offset(cx + r * .75, cy - r * .45), r * .18, hairPaint);
    // Top arc — shorter/flatter than Eri
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r * .88),
      math.pi * 1.20, math.pi * .60, false,
      Paint()
        ..color = const Color(0xFF1F2A44)
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * .08
        ..strokeCap = StrokeCap.round,
    );

    // Outer glow ring
    canvas.drawCircle(Offset(cx, cy), r,
        Paint()
          ..color = _kTeal.withOpacity(0.25)
          ..style = PaintingStyle.stroke
          ..strokeWidth = size.width * .02);
  }

  @override
  bool shouldRepaint(_AeroAvatarPainter o) =>
      o.eyeScaleY != eyeScaleY || o.isThinking != isThinking;
}

// ─────────────────────────────────────────────────────────────────────────────
// Chat Sheet
// ─────────────────────────────────────────────────────────────────────────────

class _AeroChatSheet extends StatefulWidget {
  const _AeroChatSheet();

  @override
  State<_AeroChatSheet> createState() => _AeroChatSheetState();
}

class _AeroChatSheetState extends State<_AeroChatSheet> {
  final AeroAiService         _svc        = AeroAiService();
  final TextEditingController _controller = TextEditingController();
  final ScrollController      _scroll     = ScrollController();
  final FocusNode             _focus      = FocusNode();

  bool _isLoading      = false;
  bool _isInitialising = false;

  static const List<String> _chips = [
    "What phase is she in?",
    "Why is she moody today?",
    "How can I support her right now?",
    "What should I expect this week?",
    "What are her common symptoms?",
    "How do I talk to her about this?",
  ];

  // ── Lifecycle ───────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    setState(() => _isInitialising = true);
    await _svc.loadMessages();
    if (!_svc.isContextReady) await _svc.buildContext();
    if (mounted) {
      setState(() => _isInitialising = false);
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
    setState(() => _isLoading = true);
    _scrollToBottom();

    try {
      await _svc.sendMessage(trimmed);
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
            'This will delete your entire chat history with Aero. This cannot be undone.'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel', style: TextStyle(color: _kGrey))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Clear',
                  style: TextStyle(
                      color: _kTealDark, fontWeight: FontWeight.bold))),
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
              color: _kTeal.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Row(
        children: [
          const SizedBox(width: 36, height: 36, child: _AeroAvatar(size: 36)),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Aero',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _kTealDark)),
              Text('Partner Cycle Assistant',
                  style: TextStyle(fontSize: 12, color: _kGrey)),
            ],
          ),
          const Spacer(),
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

  // ── Loader ──────────────────────────────────────────────────────────────────

  Widget _buildLoader() {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
                width: 56,
                height: 56,
                child: _AeroAvatar(size: 56, isThinking: true)),
            const SizedBox(height: 14),
            Text('Loading cycle data…',
                style: TextStyle(
                    color: _kTealDark,
                    fontSize: 14,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 10),
            SizedBox(
              width: 180,
              child: LinearProgressIndicator(
                backgroundColor: _kTealLight,
                color: _kTeal,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Message list ─────────────────────────────────────────────────────────────

  Widget _buildMessageList(List<AeroChatMessage> msgs) {
    if (msgs.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
                width: 100, height: 100, child: _AeroAvatar(size: 100)),
            const SizedBox(height: 16),
            Text("Hey! I'm Aero",
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: _kTealDark)),
            const SizedBox(height: 6),
            Text(
              "Ask me about your girlfriend's cycle",
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

  Widget _buildBubble(AeroChatMessage msg) {
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
                width: 32, height: 32, child: _AeroAvatar(size: 32)),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser ? _kTeal : _kSurface,
                borderRadius: BorderRadius.only(
                  topLeft:     const Radius.circular(20),
                  topRight:    const Radius.circular(20),
                  bottomLeft:  Radius.circular(isUser ? 20 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 20),
                ),
                boxShadow: [
                  BoxShadow(
                      color: (isUser ? _kTeal : Colors.black).withOpacity(0.12),
                      blurRadius: 8,
                      offset: const Offset(0, 2)),
                ],
              ),
              child: isUser
                  ? Text(msg.text,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 15, height: 1.45))
                  : _buildAeroContent(msg.text),
            ),
          ),
          if (isUser) const SizedBox(width: 4),
        ],
      ),
    );
  }

  // ── Markdown renderer ────────────────────────────────────────────────────────

  Widget _buildAeroContent(String raw) {
    return _buildMarkdown(_preprocessLatex(raw));
  }

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
              backgroundColor: Colors.cyan.shade50,
              color: _kTealDark,
              fontFamily: 'monospace',
              fontSize: 14,
            ),
          ),
          TableConfig(
            wrapper: (t) =>
                SingleChildScrollView(scrollDirection: Axis.horizontal, child: t),
            defaultColumnWidth: const IntrinsicColumnWidth(),
            border:
                TableBorder.all(color: Colors.cyan.shade200, width: 1),
          ),
          PConfig(
            textStyle: const TextStyle(
                fontSize: 15, color: _kText, height: 1.5),
          ),
          H1Config(
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: _kTealDark)),
          H2Config(
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _kTealDark)),
          H3Config(
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _kTealDark)),
          BlockquoteConfig(
            sideColor: _kTeal,
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
                  backgroundColor: _kTealDark,
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
              child: _AeroAvatar(size: 32, isThinking: true)),
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
                    border: Border.all(color: _kTeal.withOpacity(0.4)),
                    boxShadow: [
                      BoxShadow(
                          color: _kTeal.withOpacity(0.08),
                          blurRadius: 4,
                          offset: const Offset(0, 2))
                    ],
                  ),
                  child: Text(_chips[i],
                      style: TextStyle(
                          color: _kTealDark,
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
                border: Border.all(color: _kTeal.withOpacity(0.3)),
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
                  hintText: "Ask Aero about your girlfriend's cycle…",
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
                color: _isLoading ? Colors.grey.shade300 : _kTeal,
                boxShadow: _isLoading
                    ? []
                    : [
                        BoxShadow(
                            color: _kTeal.withOpacity(0.4),
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
                      color: _kTeal.withOpacity(0.7)),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
