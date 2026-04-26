# Requirements Document: Tetris Game

## Introduction

This document specifies the functional requirements for a fully functional Tetris game implementation in Flutter. The game provides classic Tetris gameplay with seven tetromino shapes, automatic falling with progressive difficulty, collision detection, line clearing with scoring, and persistent high score tracking. The game operates entirely offline with local data persistence and integrates into an existing game_page.dart screen.

## Glossary

- **System**: The Tetris game application
- **Game_Board**: The 10x20 grid where tetrominoes are placed
- **Tetromino**: A geometric shape composed of four square blocks (I, O, T, S, Z, J, L pieces)
- **Active_Piece**: The currently falling tetromino that the user controls
- **Locked_Piece**: A tetromino that has been placed permanently on the Game_Board
- **Ghost_Piece**: A preview showing where the Active_Piece will land
- **Line**: A complete horizontal row of 10 filled cells on the Game_Board
- **Level**: The current difficulty level, which increases fall speed
- **Hold_Slot**: A storage location where the user can save one tetromino for later use
- **Spawn_Position**: The top-center location where new tetrominoes appear
- **Collision**: When a tetromino overlaps with Game_Board boundaries or Locked_Pieces
- **Wall_Kick**: An adjustment to piece position when rotation would cause Collision
- **Hard_Drop**: Instantly moving the Active_Piece to its lowest valid position
- **High_Score**: The highest score achieved across all game sessions

## Requirements

### Requirement 1: Game Initialization

**User Story:** As a player, I want to start a new Tetris game from the game menu, so that I can begin playing.

#### Acceptance Criteria

1. WHEN the user taps the Tetris button on the game menu, THE System SHALL navigate to the Tetris game screen
2. WHEN the Tetris game screen loads, THE System SHALL initialize a 10x20 empty Game_Board
3. WHEN the game initializes, THE System SHALL load the High_Score from local storage
4. WHEN the game initializes, THE System SHALL spawn the first Active_Piece at the Spawn_Position
5. WHEN the game initializes, THE System SHALL generate and display the next tetromino preview
6. WHEN the game initializes, THE System SHALL set the score to 0 and level to 1

### Requirement 2: Tetromino Shapes and Colors

**User Story:** As a player, I want to see seven distinct tetromino shapes with different colors, so that I can easily identify each piece type.

#### Acceptance Criteria

1. THE System SHALL support seven tetromino types: I, O, T, S, Z, J, and L
2. THE System SHALL render the I-piece in cyan color
3. THE System SHALL render the O-piece in yellow color
4. THE System SHALL render the T-piece in purple color
5. THE System SHALL render the S-piece in green color
6. THE System SHALL render the Z-piece in red color
7. THE System SHALL render the J-piece in blue color
8. THE System SHALL render the L-piece in orange color
9. WHEN rendering any tetromino, THE System SHALL use colors that are visually distinct from each other

### Requirement 3: Piece Movement

**User Story:** As a player, I want to move the falling piece left, right, and down, so that I can position it where I want.

#### Acceptance Criteria

1. WHEN the user presses the left control, THE System SHALL move the Active_Piece one cell left
2. WHEN the user presses the right control, THE System SHALL move the Active_Piece one cell right
3. WHEN the user presses the down control, THE System SHALL move the Active_Piece one cell down
4. IF moving the Active_Piece would cause Collision, THEN THE System SHALL prevent the movement and keep the piece at its current position
5. WHEN the Active_Piece moves, THE System SHALL update the display within 16 milliseconds

### Requirement 4: Piece Rotation

**User Story:** As a player, I want to rotate the falling piece, so that I can orient it to fit into available spaces.

#### Acceptance Criteria

1. WHEN the user presses the rotate control, THE System SHALL rotate the Active_Piece 90 degrees clockwise
2. IF rotation would cause Collision at the current position, THEN THE System SHALL attempt Wall_Kick adjustments
3. WHEN Wall_Kick is attempted, THE System SHALL test up to 5 alternative positions based on the Super Rotation System
4. IF all Wall_Kick positions cause Collision, THEN THE System SHALL cancel the rotation and keep the piece in its original orientation
5. WHEN rotation succeeds, THE System SHALL update the piece orientation and position immediately

### Requirement 5: Automatic Falling

**User Story:** As a player, I want pieces to fall automatically at a consistent rate, so that the game progresses without constant input.

#### Acceptance Criteria

1. WHILE the game is in playing state, THE System SHALL move the Active_Piece down by one cell at regular intervals
2. WHEN the game is at level 1, THE System SHALL move pieces down every 1000 milliseconds
3. WHEN the level increases, THE System SHALL reduce the fall interval by 50 milliseconds per level
4. THE System SHALL maintain a minimum fall interval of 100 milliseconds regardless of level
5. WHEN the game is paused, THE System SHALL stop automatic falling until resumed

### Requirement 6: Collision Detection

**User Story:** As a player, I want pieces to stop when they hit the bottom or other pieces, so that I can build up the game board.

#### Acceptance Criteria

1. WHEN the Active_Piece moves to a position, THE System SHALL check for Collision before allowing the movement
2. IF the Active_Piece would move outside the left boundary (x < 0), THEN THE System SHALL detect Collision
3. IF the Active_Piece would move outside the right boundary (x + width > 10), THEN THE System SHALL detect Collision
4. IF the Active_Piece would move outside the bottom boundary (y + height > 20), THEN THE System SHALL detect Collision
5. IF the Active_Piece would overlap with any Locked_Piece, THEN THE System SHALL detect Collision
6. WHEN Collision is detected during downward movement, THE System SHALL lock the Active_Piece at its current position

### Requirement 7: Piece Locking

**User Story:** As a player, I want pieces to lock in place when they can't move down further, so that they become part of the game board.

#### Acceptance Criteria

1. WHEN the Active_Piece cannot move down due to Collision, THE System SHALL lock the piece at its current position
2. WHEN a piece is locked, THE System SHALL write all occupied cells to the Game_Board permanently
3. WHEN a piece is locked, THE System SHALL check for completed lines
4. WHEN a piece is locked, THE System SHALL spawn the next Active_Piece at the Spawn_Position
5. WHEN a piece is locked, THE System SHALL reset the hold usage flag to allow holding the next piece

### Requirement 8: Line Clearing

**User Story:** As a player, I want completed horizontal lines to be cleared, so that I can make space and score points.

#### Acceptance Criteria

1. WHEN a piece is locked, THE System SHALL identify all lines where all 10 cells are filled
2. WHEN one or more complete lines are identified, THE System SHALL remove those lines from the Game_Board
3. WHEN lines are removed, THE System SHALL shift all lines above the cleared lines downward by the number of cleared lines
4. WHEN lines are shifted down, THE System SHALL add empty lines at the top of the Game_Board
5. WHEN lines are cleared, THE System SHALL maintain the Game_Board dimensions at 10 columns by 20 rows
6. WHEN multiple lines are cleared simultaneously, THE System SHALL process all cleared lines in a single operation

### Requirement 9: Scoring System

**User Story:** As a player, I want to earn points for clearing lines, so that I can track my performance and compete for high scores.

#### Acceptance Criteria

1. WHEN the user clears 1 line, THE System SHALL award 100 points multiplied by the current level
2. WHEN the user clears 2 lines simultaneously, THE System SHALL award 300 points multiplied by the current level
3. WHEN the user clears 3 lines simultaneously, THE System SHALL award 500 points multiplied by the current level
4. WHEN the user clears 4 lines simultaneously, THE System SHALL award 800 points multiplied by the current level
5. WHEN the score increases, THE System SHALL update the displayed score immediately
6. WHEN the current score exceeds the High_Score, THE System SHALL update the High_Score
7. THE System SHALL ensure the score never decreases during gameplay

### Requirement 10: Level Progression

**User Story:** As a player, I want the game difficulty to increase as I clear more lines, so that the game remains challenging.

#### Acceptance Criteria

1. WHEN the game starts, THE System SHALL set the level to 1
2. WHEN the user clears 10 total lines, THE System SHALL increase the level to 2
3. FOR every 10 lines cleared, THE System SHALL increase the level by 1
4. WHEN the level increases, THE System SHALL reduce the automatic fall interval to increase difficulty
5. WHEN the level increases, THE System SHALL display the new level to the user

### Requirement 11: High Score Persistence

**User Story:** As a player, I want my high score to be saved, so that I can see my best performance across game sessions.

#### Acceptance Criteria

1. WHEN the game initializes, THE System SHALL load the High_Score from local storage
2. IF no High_Score exists in local storage, THEN THE System SHALL initialize the High_Score to 0
3. WHEN the current score exceeds the High_Score, THE System SHALL save the new High_Score to local storage immediately
4. WHEN saving the High_Score fails, THE System SHALL log the error and continue gameplay without crashing
5. THE System SHALL persist the High_Score across application restarts

### Requirement 12: Hard Drop

**User Story:** As a player, I want to instantly drop the piece to the bottom, so that I can speed up gameplay.

#### Acceptance Criteria

1. WHEN the user activates the hard drop control, THE System SHALL immediately move the Active_Piece to its lowest valid position
2. WHEN hard drop is executed, THE System SHALL calculate the distance dropped
3. WHEN hard drop is executed, THE System SHALL award 2 points per cell dropped
4. WHEN hard drop completes, THE System SHALL lock the piece immediately
5. WHEN hard drop completes, THE System SHALL trigger line clearing and spawn the next piece

### Requirement 13: Hold Piece Mechanic

**User Story:** As a player, I want to save the current piece for later use, so that I can strategically manage piece placement.

#### Acceptance Criteria

1. WHEN the user activates the hold control, THE System SHALL move the Active_Piece to the Hold_Slot
2. IF the Hold_Slot is empty, THEN THE System SHALL spawn the next piece as the new Active_Piece
3. IF the Hold_Slot contains a piece, THEN THE System SHALL swap the Active_Piece with the held piece
4. WHEN a piece is swapped from hold, THE System SHALL reset its rotation to 0 and position it at the Spawn_Position
5. WHEN hold is used, THE System SHALL prevent using hold again until the current piece is locked
6. IF swapping from hold would cause Collision at the Spawn_Position, THEN THE System SHALL cancel the swap

### Requirement 14: Ghost Piece Preview

**User Story:** As a player, I want to see where the current piece will land, so that I can plan my placement accurately.

#### Acceptance Criteria

1. WHILE an Active_Piece exists, THE System SHALL calculate and display a Ghost_Piece
2. THE System SHALL position the Ghost_Piece at the lowest valid position for the Active_Piece at its current horizontal position
3. THE System SHALL render the Ghost_Piece with 30% opacity of the Active_Piece color
4. WHEN the Active_Piece moves horizontally or rotates, THE System SHALL update the Ghost_Piece position immediately
5. THE System SHALL render the Ghost_Piece below the Active_Piece in the draw order

### Requirement 15: Next Piece Preview

**User Story:** As a player, I want to see the next piece that will spawn, so that I can plan ahead.

#### Acceptance Criteria

1. THE System SHALL display a preview of the next tetromino that will spawn
2. WHEN a new piece spawns, THE System SHALL generate a new random next piece
3. THE System SHALL render the next piece preview in a dedicated UI area separate from the Game_Board
4. THE System SHALL display the next piece in its default rotation (rotation 0)
5. THE System SHALL update the next piece preview immediately when a piece is locked

### Requirement 16: Game Over Condition

**User Story:** As a player, I want the game to end when I can no longer place pieces, so that I know when I've lost.

#### Acceptance Criteria

1. WHEN a new piece spawns, THE System SHALL check if the Spawn_Position is valid
2. IF the Spawn_Position has Collision, THEN THE System SHALL trigger game over
3. WHEN game over is triggered, THE System SHALL stop automatic falling
4. WHEN game over is triggered, THE System SHALL display a game over dialog with the final score
5. WHEN game over is triggered, THE System SHALL save the High_Score if it was exceeded
6. WHEN game over occurs, THE System SHALL offer options to restart or return to the menu

### Requirement 17: Pause and Resume

**User Story:** As a player, I want to pause and resume the game, so that I can take breaks without losing progress.

#### Acceptance Criteria

1. WHEN the user activates the pause control, THE System SHALL pause the game
2. WHEN the game is paused, THE System SHALL stop automatic falling
3. WHEN the game is paused, THE System SHALL prevent all piece movement and rotation controls
4. WHEN the game is paused, THE System SHALL display a pause dialog
5. WHEN the user resumes from pause, THE System SHALL restore automatic falling at the current level speed
6. WHEN the user resumes from pause, THE System SHALL restore all game controls

### Requirement 18: Game Restart

**User Story:** As a player, I want to restart the game at any time, so that I can start fresh without navigating away.

#### Acceptance Criteria

1. WHEN the user activates the restart control, THE System SHALL reset the Game_Board to empty
2. WHEN restart is activated, THE System SHALL reset the score to 0
3. WHEN restart is activated, THE System SHALL reset the level to 1
4. WHEN restart is activated, THE System SHALL reset the lines cleared counter to 0
5. WHEN restart is activated, THE System SHALL spawn a new first piece
6. WHEN restart is activated, THE System SHALL preserve the High_Score
7. WHEN restart is activated, THE System SHALL start automatic falling at level 1 speed

### Requirement 19: Responsive UI Rendering

**User Story:** As a player, I want the game to render smoothly on my device, so that I have a good gameplay experience.

#### Acceptance Criteria

1. THE System SHALL render the Game_Board at 60 frames per second during gameplay
2. THE System SHALL respond to user input within 16 milliseconds
3. THE System SHALL use efficient rendering techniques to minimize CPU usage
4. WHEN the screen orientation changes, THE System SHALL adapt the layout appropriately
5. THE System SHALL render all UI elements clearly on screens from 320px to 1024px width

### Requirement 20: Offline Operation

**User Story:** As a player, I want to play the game without an internet connection, so that I can play anywhere.

#### Acceptance Criteria

1. THE System SHALL operate entirely offline without requiring network connectivity
2. THE System SHALL store all game data locally on the device
3. THE System SHALL not transmit any data over the network
4. THE System SHALL not require user authentication or login
5. THE System SHALL function identically whether the device is online or offline

### Requirement 21: Random Piece Generation

**User Story:** As a player, I want pieces to appear in random order, so that each game is different and unpredictable.

#### Acceptance Criteria

1. WHEN generating a new piece, THE System SHALL randomly select from all seven tetromino types
2. THE System SHALL ensure each tetromino type has an equal probability of being selected
3. WHEN the game starts, THE System SHALL generate both the first Active_Piece and the next piece randomly
4. THE System SHALL use a different random sequence for each game session

### Requirement 22: Game State Management

**User Story:** As a developer, I want clear game state management, so that the system behavior is predictable and maintainable.

#### Acceptance Criteria

1. THE System SHALL maintain one of four states: start, playing, paused, or game over
2. WHEN the game initializes, THE System SHALL set the state to start
3. WHEN the user starts the game, THE System SHALL transition from start to playing
4. WHEN the user pauses, THE System SHALL transition from playing to paused
5. WHEN the user resumes, THE System SHALL transition from paused to playing
6. WHEN game over is triggered, THE System SHALL transition to game over state
7. WHEN the user restarts, THE System SHALL transition from any state to start

### Requirement 23: Grid Integrity

**User Story:** As a developer, I want the game board to maintain consistent dimensions, so that the game logic remains correct.

#### Acceptance Criteria

1. THE System SHALL maintain the Game_Board at exactly 10 columns wide
2. THE System SHALL maintain the Game_Board at exactly 20 rows tall
3. WHEN lines are cleared, THE System SHALL preserve the 10x20 dimensions
4. WHEN pieces are locked, THE System SHALL preserve the 10x20 dimensions
5. WHEN the game is reset, THE System SHALL preserve the 10x20 dimensions

### Requirement 24: Visual Feedback

**User Story:** As a player, I want clear visual feedback for game events, so that I understand what's happening.

#### Acceptance Criteria

1. WHEN a line is cleared, THE System SHALL provide visual indication of the cleared line
2. WHEN the level increases, THE System SHALL display the new level prominently
3. WHEN the score increases, THE System SHALL update the score display immediately
4. WHEN a piece is locked, THE System SHALL render it in the Game_Board with its color
5. WHEN the game is paused, THE System SHALL display a pause indicator

### Requirement 25: Control Responsiveness

**User Story:** As a player, I want controls to respond immediately to my input, so that I have precise control over pieces.

#### Acceptance Criteria

1. WHEN the user presses a movement control, THE System SHALL execute the movement within one frame (16ms)
2. WHEN the user presses the rotation control, THE System SHALL execute the rotation within one frame
3. WHEN the user presses the hard drop control, THE System SHALL execute the drop within one frame
4. WHEN the user presses the hold control, THE System SHALL execute the hold within one frame
5. THE System SHALL prevent input lag from affecting gameplay responsiveness
