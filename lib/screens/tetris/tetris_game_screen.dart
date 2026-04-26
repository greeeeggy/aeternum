import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../../game/tetris/logic/tetris_game_logic.dart';
import '../../game/tetris/models/game_state.dart';
import '../../game/tetris/models/tetris_theme.dart';
import '../../game/tetris/widgets/game_board_widget.dart';
import '../../game/tetris/widgets/score_panel.dart';
import '../../game/tetris/widgets/controls_widget.dart';
import '../../game/tetris/widgets/next_piece_widget.dart';

class TetrisGameScreen extends StatefulWidget {
  const TetrisGameScreen({Key? key}) : super(key: key);

  @override
  State<TetrisGameScreen> createState() => _TetrisGameScreenState();
}

class _TetrisGameScreenState extends State<TetrisGameScreen>
    with SingleTickerProviderStateMixin {
  late TetrisGameLogic _gameLogic;
  late Ticker _ticker;
  Duration _lastFallTime = Duration.zero;

  @override
  void initState() {
    super.initState();
    _gameLogic = TetrisGameLogic();
    _ticker = createTicker(_onTick);
  }

  void _onTick(Duration elapsed) {
    if (_gameLogic.currentState != GameState.playing) return;
    final interval = _gameLogic.calculateFallInterval();
    if ((elapsed - _lastFallTime).inMilliseconds >= interval) {
      _lastFallTime = elapsed;
      _gameLogic.tick();
    }
  }

  void _goToStart() {
    _ticker.stop();
    _gameLogic.resetToStart();
  }

  void _startGame() {
    _gameLogic.startGame();
    _lastFallTime = Duration.zero;
    if (!_ticker.isActive) _ticker.start();
  }

  void _pauseGame() {
    _gameLogic.pauseGame();
    _ticker.stop();
    _showPauseDialog();
  }

  void _resumeGame() {
    _gameLogic.resumeGame();
    _lastFallTime = Duration.zero;
    _ticker.start();
  }

  void _restartGame() {
    _ticker.stop();
    _gameLogic.restartGame();
    _lastFallTime = Duration.zero;
    _ticker.start();
  }

  // ── Dialogs ──────────────────────────────────────────────────

  void _showPauseDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: TetrisTheme.icePanel(radius: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: TetrisTheme.bannerBox(radius: 10),
                child: const Text('PAUSED',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: TetrisTheme.textLight,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 3,
                    )),
              ),
              const SizedBox(height: 16),
              _dialogButton('RESUME', () {
                Navigator.of(ctx).pop();
                _resumeGame();
              }),
              const SizedBox(height: 8),
              _dialogButton('REPLAY', () {
                Navigator.of(ctx).pop();
                _restartGame();
              }),
              const SizedBox(height: 8),
              _dialogButton('EXIT', () {
                Navigator.of(ctx).pop();
                _goToStart();
              }, danger: true),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showGameOverDialog() {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: TetrisTheme.icePanel(radius: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: TetrisTheme.bannerBox(radius: 10),
                child: const Text('GAME OVER',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: TetrisTheme.textLight,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 3,
                    )),
              ),
              const SizedBox(height: 16),
              // Score
              _statRow('SCORE', _gameLogic.score.toString()),
              const SizedBox(height: 8),
              _statRow('BEST', _gameLogic.highScore.toString(),
                  valueColor: TetrisTheme.gold),
              const SizedBox(height: 16),
              _dialogButton('PLAY AGAIN', () {
                Navigator.of(ctx).pop();
                _restartGame();
              }),
              const SizedBox(height: 8),
              _dialogButton('MENU', () {
                Navigator.of(ctx).pop();
                _goToStart();
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dialogButton(String label, VoidCallback onTap,
      {bool danger = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: danger
              ? const Color(0xFF8A1A1A)
              : TetrisTheme.banner,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: danger
                ? const Color(0xFF5C0F0F)
                : TetrisTheme.bannerDark,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 4,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: TetrisTheme.textLight,
            fontSize: 15,
            fontWeight: FontWeight.w800,
            letterSpacing: 2,
          ),
        ),
      ),
    );
  }

  Widget _statRow(String label, String value, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(
              color: TetrisTheme.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            )),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: TetrisTheme.bannerBox(radius: 6),
          child: Text(
            value,
            style: TextStyle(
              color: valueColor ?? TetrisTheme.textLight,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  // ── Lifecycle ────────────────────────────────────────────────

  @override
  void dispose() {
    _ticker.dispose();
    _gameLogic.dispose();
    super.dispose();
  }

  bool _isGameOverDialogShowing = false;

  // ── Build ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TetrisTheme.bg,
      body: ListenableBuilder(
        listenable: _gameLogic,
        builder: (context, _) {
          // Only needed at the top level to switch between start/game screens
          // and to trigger the game-over dialog
          if (_gameLogic.currentState == GameState.gameOver &&
              !_isGameOverDialogShowing) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && ModalRoute.of(context)?.isCurrent == true) {
                _isGameOverDialogShowing = true;
                _ticker.stop();
                _showGameOverDialog().then((_) {
                  _isGameOverDialogShowing = false;
                });
              }
            });
          }
          return _buildBody(context);
        },
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    switch (_gameLogic.currentState) {
      case GameState.start:
        return _buildStartScreen();
      case GameState.playing:
      case GameState.paused:
      case GameState.gameOver:
        return _buildGameScreen();
    }
  }

  // ── Start Screen ─────────────────────────────────────────────

  Widget _buildStartScreen() {
    return SafeArea(
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(32),
          padding: const EdgeInsets.all(28),
          decoration: TetrisTheme.icePanel(radius: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: TetrisTheme.bannerBox(radius: 12),
                child: const Text(
                  'TETRIS',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: TetrisTheme.textLight,
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 8,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              if (_gameLogic.highScore > 0) ...[
                _statRow('BEST', _gameLogic.highScore.toString(),
                    valueColor: TetrisTheme.gold),
                const SizedBox(height: 20),
              ],
              _dialogButton('PLAY', _startGame),
            ],
          ),
        ),
      ),
    );
  }

  // ── Game Screen ──────────────────────────────────────────────

  Widget _buildGameScreen() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            // Toolbar + score + board rebuild on game state changes
            ListenableBuilder(
              listenable: _gameLogic,
              builder: (context, _) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildToolbar(),
                  const SizedBox(height: 8),
                  ScorePanel(
                    score: _gameLogic.score,
                    highScore: _gameLogic.highScore,
                    level: _gameLogic.level,
                    linesCleared: _gameLogic.linesCleared,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        // RepaintBoundary isolates the board's paint layer
                        // so parent rebuilds don't force the canvas to repaint
                        child: RepaintBoundary(
                          child: GameBoardWidget(
                            board: _gameLogic.board,
                            currentPiece: _gameLogic.currentPiece,
                            pieceX: _gameLogic.pieceX,
                            pieceY: _gameLogic.pieceY,
                            showGhost: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 1,
                        child: Column(
                          children: [
                            NextPieceWidget(nextPiece: _gameLogic.nextPiece),
                            const SizedBox(height: 8),
                            HoldPieceWidget(heldPiece: _gameLogic.heldPiece),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Controls are OUTSIDE ListenableBuilder — they never
            // need to rebuild since they only call methods, not render state
            ControlsWidget(gameLogic: _gameLogic),
          ],
        ),
      ),
    );
  }

  Widget _buildToolbar() {
    return Row(
      children: [
        // Back icon button
        _iconToolbarButton(Icons.arrow_back, () => Navigator.of(context).pop()),
        const SizedBox(width: 8),
        // Title
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: TetrisTheme.bannerBox(radius: 10),
            child: const Text(
              'TETRIS',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: TetrisTheme.textLight,
                fontSize: 16,
                fontWeight: FontWeight.w900,
                letterSpacing: 4,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Pause icon button
        _iconToolbarButton(Icons.pause, _pauseGame),
      ],
    );
  }

  Widget _iconToolbarButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: TetrisTheme.bannerBox(radius: 10),
        child: Icon(icon, color: TetrisTheme.textLight, size: 22),
      ),
    );
  }
}
