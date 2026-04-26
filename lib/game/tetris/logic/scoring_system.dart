class ScoringSystem {
  static const Map<int, int> _baseScores = {
    0: 0,
    1: 100,
    2: 300,
    3: 500,
    4: 800,
  };

  static int calculateScore(int linesCleared, int currentLevel) {
    final base = _baseScores[linesCleared] ?? 0;
    return base * currentLevel;
  }
}
