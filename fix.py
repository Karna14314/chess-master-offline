import re

with open('lib/providers/analysis_provider.dart', 'r') as f:
    content = f.read()

# 1. Update goToMove to call stopAnalysis
content = content.replace('''  /// Navigate to a specific move index
  Future<void> goToMove(int moveIndex) async {
    if (moveIndex < -1 || moveIndex >= state.originalMoves.length) return;

    // Cancel any running analysis
    _analysisToken++;
    // Give the engine loop a chance to exit before starting new analysis
    await Future.delayed(Duration.zero);''', '''  /// Navigate to a specific move index
  Future<void> goToMove(int moveIndex) async {
    if (moveIndex < -1 || moveIndex >= state.originalMoves.length) return;

    // Cancel any running analysis
    stopAnalysis();
    // Give the engine loop a chance to exit before starting new analysis
    await Future.delayed(Duration.zero);''')

# 2. Update _analyzeCurrentPosition to use token
old_analyze_pos = '''  Future<void> _analyzeCurrentPosition() async {
    if (_stockfish == null || !_isInitialized) return;
    if (_isAnalyzing) return;

    final fen = state.fen;
    final depth = AppConstants.analysisDepth;
    final multiPv = AppConstants.topEngineLinesCount;

    try {
      final cached = await _db.getCachedEvaluation(
        fen: fen,
        requiredDepth: depth,
        requiredMultiPv: multiPv,
      );

      if (cached != null) {
        final linesJson = jsonDecode(cached['engine_lines'] as String) as List;
        final lines = linesJson.map((l) => EngineLine(
          rank: l['rank'] as int,
          evaluation: (l['evaluation'] as num).toDouble(),
          depth: l['depth'] as int,
          moves: List<String>.from(l['moves']),
          isMate: (l['isMate'] as bool?) ?? false,
          mateIn: l['mateIn'] as int?,
        )).toList();

        state = state.copyWith(
          currentEval: (cached['evaluation'] as num).toDouble(),
          currentEngineLines: lines,
          bestMove: lines.isNotEmpty ? lines.first.moves.first : null,
        );
        return;
      }
    } catch (e) {
      debugPrint('Eval cache lookup failed: $e');
    }

    try {
      _isAnalyzing = true;
      final result = await _stockfish!.analyzePosition(
        fen: fen,
        depth: depth,
        multiPv: multiPv,
        onUpdate: (partialResult) {
          state = state.copyWith(
            currentEval: partialResult.evalInPawns,
            currentEngineLines: partialResult.lines,
            bestMove:
                partialResult.lines.isNotEmpty
                    ? partialResult.lines.first.moves.first
                    : null,
          );
        },
      );

      final linesJson = result.lines.map((l) => ({
        'rank': l.rank,
        'evaluation': l.evaluation,
        'depth': l.depth,
        'moves': l.moves,
        'isMate': l.isMate,
        'mateIn': l.mateIn,
      })).toList();

      await _db.cacheEvaluation(
        fen: fen,
        depth: depth,
        multiPv: multiPv,
        evaluation: result.evalInPawns,
        engineLines: jsonEncode(linesJson),
        isMate: result.lines.isNotEmpty && result.lines.first.isMate,
        mateIn: result.lines.isNotEmpty ? result.lines.first.mateIn : null,
      );

      state = state.copyWith(
        currentEval: result.evalInPawns,
        currentEngineLines: result.lines,
        bestMove:
            result.lines.isNotEmpty ? result.lines.first.moves.first : null,
      );
    } catch (e) {
      debugPrint('Stockfish analysis failed: $e. Using BasicEvaluator.');
      try {
        final basicResult = await BasicEvaluatorService.instance.analyze(fen);
        state = state.copyWith(
          currentEval: basicResult.evalInPawns,
          currentEngineLines: basicResult.lines,
          bestMove:
              basicResult.lines.isNotEmpty
                  ? basicResult.lines.first.moves.first
                  : null,
        );
      } catch (e2) {
        // Silently fail
      }
    } finally {
      _isAnalyzing = false;
    }
  }'''

new_analyze_pos = '''  Future<void> _analyzeCurrentPosition() async {
    if (_stockfish == null || !_isInitialized) return;
    if (_isAnalyzing) return;

    final fen = state.fen;
    final depth = AppConstants.analysisDepth;
    final multiPv = AppConstants.topEngineLinesCount;
    final token = _analysisToken;

    try {
      final cached = await _db.getCachedEvaluation(
        fen: fen,
        requiredDepth: depth,
        requiredMultiPv: multiPv,
      );

      if (cached != null) {
        if (token != _analysisToken) return;
        final linesJson = jsonDecode(cached['engine_lines'] as String) as List;
        final lines = linesJson.map((l) => EngineLine(
          rank: l['rank'] as int,
          evaluation: (l['evaluation'] as num).toDouble(),
          depth: l['depth'] as int,
          moves: List<String>.from(l['moves']),
          isMate: (l['isMate'] as bool?) ?? false,
          mateIn: l['mateIn'] as int?,
        )).toList();

        state = state.copyWith(
          currentEval: (cached['evaluation'] as num).toDouble(),
          currentEngineLines: lines,
          bestMove: lines.isNotEmpty ? lines.first.moves.first : null,
        );
        return;
      }
    } catch (e) {
      debugPrint('Eval cache lookup failed: $e');
    }

    try {
      _isAnalyzing = true;
      final result = await _stockfish!.analyzePosition(
        fen: fen,
        depth: depth,
        multiPv: multiPv,
        onUpdate: (partialResult) {
          if (token != _analysisToken) return;
          state = state.copyWith(
            currentEval: partialResult.evalInPawns,
            currentEngineLines: partialResult.lines,
            bestMove:
                partialResult.lines.isNotEmpty
                    ? partialResult.lines.first.moves.first
                    : null,
          );
        },
      );

      if (token != _analysisToken) return;

      final linesJson = result.lines.map((l) => ({
        'rank': l.rank,
        'evaluation': l.evaluation,
        'depth': l.depth,
        'moves': l.moves,
        'isMate': l.isMate,
        'mateIn': l.mateIn,
      })).toList();

      await _db.cacheEvaluation(
        fen: fen,
        depth: depth,
        multiPv: multiPv,
        evaluation: result.evalInPawns,
        engineLines: jsonEncode(linesJson),
        isMate: result.lines.isNotEmpty && result.lines.first.isMate,
        mateIn: result.lines.isNotEmpty ? result.lines.first.mateIn : null,
      );

      state = state.copyWith(
        currentEval: result.evalInPawns,
        currentEngineLines: result.lines,
        bestMove:
            result.lines.isNotEmpty ? result.lines.first.moves.first : null,
      );
    } catch (e) {
      debugPrint('Stockfish analysis failed: $e. Using BasicEvaluator.');
      try {
        if (token != _analysisToken) return;
        final basicResult = await BasicEvaluatorService.instance.analyze(fen);
        if (token != _analysisToken) return;
        state = state.copyWith(
          currentEval: basicResult.evalInPawns,
          currentEngineLines: basicResult.lines,
          bestMove:
              basicResult.lines.isNotEmpty
                  ? basicResult.lines.first.moves.first
                  : null,
        );
      } catch (e2) {
        // Silently fail
      }
    } finally {
      if (token == _analysisToken) {
        _isAnalyzing = false;
      }
    }
  }'''

content = content.replace(old_analyze_pos, new_analyze_pos)

with open('lib/providers/analysis_provider.dart', 'w') as f:
    f.write(content)
