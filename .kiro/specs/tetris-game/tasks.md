# Implementation Plan: Tetris Game

## Overview

This implementation plan breaks down the Tetris game feature into discrete coding tasks organized by development phases. The game will be built in Flutter with a focus on clean architecture, efficient rendering using CustomPainter, and comprehensive testing. Each task builds incrementally on previous work, with checkpoints to validate progress.

## Tasks

- [ ] 1. Set up project structure and data models
  - Create directory structure: `lib/game/tetris/` with subdirectories for `logic/`, `widgets/`, `services/`, and `models/`
  - Create `models/game_state.dart` with GameState enum (start, playing, paused, gameOver)
  - Create `models/tetromino_shapes.dart` with all 7 tetromino shape definitions (I, O, T, S, Z, J, L) and 4 rotation states each
  - Define TetrominoType enum and TetrominoColors class with color mappings
  - _Requirements: Design Section "Data Models"_

- [ ] 2. Implement core Tetromino class
  - [ ] 2.1 Create `logic/tetromino.dart` with Tetromino class
    - Implement constructor with TetrominoType parameter
    - Implement currentShape getter that returns current rotation matrix
    - Implement color getter using TetrominoColors mapping
    - Implement rotateClockwise() and rotateCounterClockwise() methods
    - Implement clone() method for piece manipulation
    - Implement static random() factory method
    - Implement static fromType() factory method
    - _Requirements: Design Component 3 "Tetromino"_
  
  - [ ]* 2.2 Write unit tests for Tetromino class
    - Test all 7 shapes have exactly 4 rotation states
    - Test rotation cycles correctly (0→1→2→3→0)
    - Test each shape has correct dimensions
    - Test color mapping for all types
    - Test random() generates valid pieces
    - _Requirements: Design Component 3 "Tetromino"_

- [ ] 3. Implement GameBoard with collision detection
  - [ ] 3.1 Create `logic/game_board.dart` with GameBoard class
    - Initialize 10x20 grid (List<List<int?>>)
    - Implement canPlacePiece() with boundary and collision checks
    - Implement isValidPosition() for coordinate validation
    - Implement lockPiece() to fix piece in grid
    - Implement getFullLines() to identify complete rows
    - Implement clearLines() with line removal and shifting
    - Implement reset() to clear grid
    - Implement calculateGhostY() for ghost piece preview
    - _Requirements: Design Component 2 "GameBoard", Algorithm "Collision Detection"_
  
  - [ ]* 3.2 Write property test for collision detection
    - **Property 2: Collision Prevention**
    - **Validates: Design Property 2 - No piece can be placed where collision exists**
    - Test that canPlacePiece returns false for out-of-bounds positions
    - Test that canPlacePiece returns false for occupied cells
    - _Requirements: Design Property 2_
  
  - [ ]* 3.3 Write property test for grid integrity
    - **Property 1: Grid Integrity**
    - **Validates: Design Property 1 - Grid always maintains 10x20 dimensions**
    - Test grid dimensions after 1000 random operations (lock, clear)
    - _Requirements: Design Property 1_
  
  - [ ]* 3.4 Write unit tests for line clearing
    - Test single line clear
    - Test multiple simultaneous line clears (2, 3, 4 lines)
    - Test lines shift down correctly
    - Test empty lines added at top
    - _Requirements: Design Algorithm "Line Clearing"_

- [ ] 4. Implement HighScoreService for persistence
  - [ ] 4.1 Create `services/high_score_service.dart`
    - Implement getHighScore() using SharedPreferences
    - Implement saveHighScore() with error handling
    - Implement clearHighScore() for testing
    - Handle SharedPreferences initialization failures gracefully
    - _Requirements: Design Component 4 "HighScoreService"_
  
  - [ ]* 4.2 Write unit tests for HighScoreService
    - Test high score save and load
    - Test default value (0) when no score exists
    - Test error handling for SharedPreferences failures
    - _Requirements: Design Component 4 "HighScoreService"_

- [ ] 5. Checkpoint - Core data structures complete
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 6. Implement TetrisGameLogic state management
  - [ ] 6.1 Create `logic/tetris_game_logic.dart` with TetrisGameLogic class extending ChangeNotifier
    - Initialize GameBoard, HighScoreService
    - Implement game state properties (currentState, board, currentPiece, nextPiece, heldPiece, score, highScore, level, linesCleared)
    - Implement startGame() to initialize game and spawn first piece
    - Implement pauseGame() and resumeGame() for state transitions
    - Implement restartGame() to reset all state
    - Implement gameOver() to handle game end
    - _Requirements: Design Component 1 "TetrisGameLogic", Algorithm "Main Game Loop"_
  
  - [ ] 6.2 Implement piece movement methods in TetrisGameLogic
    - Implement movePieceLeft() with collision checking
    - Implement movePieceRight() with collision checking
    - Implement movePieceDown() with collision checking
    - Implement hardDrop() to instantly drop piece to bottom
    - Call notifyListeners() after each successful movement
    - _Requirements: Design Component 1 "TetrisGameLogic"_
  
  - [ ] 6.3 Implement rotation with wall kick system
    - Implement rotatePieceClockwise() with SRS wall kick offsets
    - Implement rotatePieceCounterClockwise() with SRS wall kick offsets
    - Implement _getWallKicks() helper for rotation-specific offsets
    - Try up to 5 wall kick positions before canceling rotation
    - _Requirements: Design Algorithm "Rotation with Wall Kick"_
  
  - [ ]* 6.4 Write unit tests for piece movement
    - Test movement within bounds
    - Test movement blocked by walls
    - Test movement blocked by locked pieces
    - Test hardDrop calculates correct distance
    - _Requirements: Design Component 1 "TetrisGameLogic"_
  
  - [ ]* 6.5 Write property test for rotation validity
    - **Property 8: Rotation Validity**
    - **Validates: Design Property 8 - Rotation only succeeds if resulting position is valid**
    - Test that successful rotations result in valid piece positions
    - _Requirements: Design Property 8_

- [ ] 7. Implement game loop and scoring
  - [ ] 7.1 Implement tick() method for automatic falling
    - Calculate fall interval based on level
    - Move piece down automatically
    - Lock piece when it cannot move further
    - Trigger line clearing after lock
    - Spawn next piece after lock
    - Check game over condition
    - _Requirements: Design Algorithm "Main Game Loop"_
  
  - [ ] 7.2 Implement scoring system
    - Create `logic/scoring_system.dart` with calculateScore() function
    - Implement score formula: baseScore * level (100/300/500/800 for 1/2/3/4 lines)
    - Implement _updateScore() in TetrisGameLogic
    - Update high score when current score exceeds it
    - Save high score to SharedPreferences
    - _Requirements: Design Function "calculateScore", Algorithm "Score Calculation"_
  
  - [ ] 7.3 Implement level progression
    - Implement updateLevel() to increment level every 10 lines
    - Implement _calculateFallInterval() with progressive difficulty
    - Update fall speed from 1000ms (level 1) to minimum 100ms
    - Reset linesClearedThisLevel on level up
    - _Requirements: Design Algorithm "Level Progression"_
  
  - [ ]* 7.4 Write property test for score monotonicity
    - **Property 3: Score Monotonicity**
    - **Validates: Design Property 3 - Score never decreases during gameplay**
    - Test score across 100 game ticks
    - _Requirements: Design Property 3_
  
  - [ ]* 7.5 Write property test for level progression
    - **Property 4: Level Progression**
    - **Validates: Design Property 4 - Level increases monotonically with lines cleared**
    - Test level == (linesCleared ÷ 10) + 1
    - _Requirements: Design Property 4_
  
  - [ ]* 7.6 Write unit tests for scoring
    - Test score calculation for 1, 2, 3, 4 lines at various levels
    - Test high score updates correctly
    - Test high score persistence
    - _Requirements: Design Function "calculateScore"_

- [ ] 8. Implement advanced features
  - [ ] 8.1 Implement hold piece mechanic
    - Implement holdPiece() method in TetrisGameLogic
    - Track holdUsedThisTurn flag to prevent multiple holds
    - Reset flag when piece is locked
    - Handle first hold (move to hold, spawn next)
    - Handle swap (exchange current with held)
    - _Requirements: Design Algorithm "Hold Piece"_
  
  - [ ] 8.2 Implement piece spawning logic
    - Implement _spawnNextPiece() method
    - Position piece at top center of board
    - Check if spawn position is valid (game over if not)
    - Generate new random next piece
    - _Requirements: Design Algorithm "Piece Spawning"_
  
  - [ ]* 8.3 Write property test for piece uniqueness
    - **Property 6: Piece Uniqueness**
    - **Validates: Design Property 6 - Only one active piece exists at any time**
    - Test throughout game lifecycle
    - _Requirements: Design Property 6_
  
  - [ ]* 8.4 Write property test for game over condition
    - **Property 10: Game Over Condition**
    - **Validates: Design Property 10 - Game over occurs if and only if new piece cannot spawn**
    - Test game over triggers when spawn position blocked
    - _Requirements: Design Property 10_

- [ ] 9. Checkpoint - Game logic complete
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 10. Implement GameBoardWidget with CustomPainter
  - [ ] 10.1 Create `widgets/game_board_widget.dart`
    - Create GameBoardWidget StatelessWidget with required parameters (board, currentPiece, pieceX, pieceY, showGhost)
    - Create GameBoardPainter extending CustomPainter
    - Implement paint() method to draw grid background
    - Implement drawing locked pieces with colors from grid
    - Implement _drawPiece() helper method
    - Implement drawing ghost piece with reduced opacity
    - Implement drawing current falling piece
    - Implement shouldRepaint() to optimize redraws
    - _Requirements: Design Component 6 "GameBoardWidget", Example 3_
  
  - [ ]* 10.2 Write property test for ghost piece accuracy
    - **Property 9: Ghost Piece Accuracy**
    - **Validates: Design Property 9 - Ghost piece is always at lowest valid position**
    - Test ghost Y calculation for various piece positions
    - _Requirements: Design Property 9_

- [ ] 11. Implement UI widgets
  - [ ] 11.1 Create `widgets/score_panel.dart`
    - Display current score, high score, level, and lines cleared
    - Use Row/Column layout with Text widgets
    - Style with appropriate fonts and colors
    - _Requirements: Design Component 5 "TetrisGameScreen"_
  
  - [ ] 11.2 Create `widgets/controls_widget.dart`
    - Create IconButton for rotate (rotate_right icon)
    - Create Row with left/down/right arrow IconButtons
    - Create ElevatedButton for hard drop
    - Create ElevatedButton for hold
    - Wire buttons to TetrisGameLogic methods
    - _Requirements: Design Example 2_
  
  - [ ] 11.3 Create `widgets/next_piece_widget.dart`
    - Display "Next" label
    - Render next piece preview using CustomPainter
    - Scale piece to fit preview area
    - _Requirements: Design Component 5 "TetrisGameScreen"_
  
  - [ ] 11.4 Create `widgets/hold_piece_widget.dart`
    - Display "Hold" label
    - Render held piece preview using CustomPainter
    - Show empty state when no piece held
    - _Requirements: Design Component 5 "TetrisGameScreen"_

- [ ] 12. Implement main TetrisGameScreen
  - [ ] 12.1 Create `screens/tetris/tetris_game_screen.dart`
    - Create StatefulWidget with SingleTickerProviderStateMixin
    - Initialize TetrisGameLogic and AnimationController in initState()
    - Implement _handleTick() to call gameLogic.tick() when playing
    - Add AnimationController listener for game loop
    - Implement dispose() to clean up resources
    - _Requirements: Design Component 5 "TetrisGameScreen", Example 5_
  
  - [ ] 12.2 Implement game screen layout
    - Create Scaffold with AppBar (title "Tetris", pause button)
    - Use ListenableBuilder to rebuild on game state changes
    - Implement _buildStartScreen() with start button
    - Implement _buildGameScreen() with Row layout
    - Left side (flex: 3): ScorePanel, GameBoardWidget, ControlsWidget
    - Right side (flex: 1): NextPieceWidget, HoldPieceWidget
    - _Requirements: Design Example 5_
  
  - [ ] 12.3 Implement game control methods
    - Implement _startGame() to start logic and animation
    - Implement _pauseGame() to pause and show dialog
    - Implement _resumeGame() to resume animation
    - Implement _showPauseDialog() with resume/restart/quit options
    - Implement _showGameOverDialog() with final score and restart option
    - _Requirements: Design Component 5 "TetrisGameScreen"_

- [ ] 13. Integrate with existing GamePage
  - [ ] 13.1 Modify `screens/game_page.dart`
    - Import TetrisGameScreen
    - Add ElevatedButton.icon with games icon and "Play Tetris" label
    - Implement onPressed to navigate to TetrisGameScreen using MaterialPageRoute
    - Style button with appropriate padding
    - _Requirements: Design Section "Integration with Existing GamePage"_

- [ ] 14. Checkpoint - UI complete
  - Ensure all tests pass, ask the user if questions arise.

- [ ]* 15. Write integration tests
  - [ ]* 15.1 Write widget test for complete game flow
    - Test start screen displays correctly
    - Test start button launches game
    - Test game board renders
    - Test piece movement via controls
    - Test game over dialog appears
    - Test restart functionality
    - _Requirements: Design Section "Integration Testing Approach"_
  
  - [ ]* 15.2 Write widget test for pause/resume
    - Test pause button shows dialog
    - Test resume continues game
    - Test restart from pause
    - _Requirements: Design Component 5 "TetrisGameScreen"_
  
  - [ ]* 15.3 Write widget test for navigation
    - Test navigation from GamePage to TetrisGameScreen
    - Test back navigation
    - _Requirements: Design Section "Integration with Existing GamePage"_

- [ ]* 16. Add polish and animations (optional)
  - [ ]* 16.1 Add line clear animation
    - Animate line flash before removal
    - Use AnimationController with fade effect
    - _Requirements: Design Section "Development Phases" - Phase 5_
  
  - [ ]* 16.2 Add sound effects (optional)
    - Use just_audio package (already in project)
    - Add sounds for: line clear, piece drop, game over, level up
    - Load sound assets in initState()
    - Play sounds on corresponding events
    - _Requirements: Design Section "Dependencies" - Optional Dependencies_
  
  - [ ]* 16.3 Optimize responsive layout
    - Add MediaQuery checks for portrait/landscape
    - Adjust layout for tablet screens (width > 600)
    - Increase touch target sizes for mobile
    - _Requirements: Design Section "Responsive Design Strategy"_

- [ ] 17. Final checkpoint - Complete feature
  - Run all tests to ensure everything passes
  - Test on physical device or emulator
  - Verify high score persistence across app restarts
  - Verify game performance (60 FPS target)
  - Ask the user if questions arise or if ready to deploy

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP delivery
- Each task references specific design document sections for traceability
- Property tests validate universal correctness properties from the design
- Unit tests validate specific examples and edge cases
- Checkpoints ensure incremental validation at major milestones
- The design document uses Dart/Flutter, so all code should be written in Dart
- CustomPainter is used for efficient rendering of the 10x20 grid
- ChangeNotifier provides reactive state management without additional dependencies
- All game logic is testable independently of UI components
