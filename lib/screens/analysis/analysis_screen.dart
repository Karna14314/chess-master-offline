import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chess_master/core/theme/app_theme.dart';
import 'package:chess_master/core/constants/app_constants.dart';
import 'package:chess_master/models/game_model.dart';
import 'package:chess_master/providers/analysis_provider.dart';
import 'package:chess_master/screens/analysis/widgets/eval_bar.dart';
import 'package:chess_master/screens/analysis/widgets/eval_graph.dart';
import 'package:chess_master/screens/analysis/widgets/engine_lines.dart';
import 'package:chess_master/screens/game/widgets/chess_board.dart';
import 'package:chess_master/models/analysis_model.dart';

/// Post-game analysis screen
class AnalysisScreen extends ConsumerStatefulWidget {
  final List<ChessMove>? moves;
  final String? startingFen;

  const AnalysisScreen({super.key, this.moves, this.startingFen});

  @override
  ConsumerState<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends ConsumerState<AnalysisScreen> {
  bool _isAnalyzing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeAnalysis();
    });
  }

  Future<void> _initializeAnalysis() async {
    final notifier = ref.read(analysisProvider.notifier);
    await notifier.initialize();

    if (widget.moves != null && widget.moves!.isNotEmpty) {
      await notifier.loadGame(
        moves: widget.moves!,
        startingFen:
            widget.startingFen ??
            'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(analysisProvider);

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceDark,
        title: const Text('Game Analysis'),
        actions: [
          if (state.originalMoves.isNotEmpty && !state.isAnalyzing)
            IconButton(
              icon: const Icon(Icons.analytics_outlined),
              onPressed: _startFullAnalysis,
              tooltip: 'Analyze full game',
            ),
          IconButton(
            icon: Icon(
              state.isLiveAnalysis ? Icons.visibility : Icons.visibility_off,
            ),
            onPressed: () {
              ref.read(analysisProvider.notifier).toggleLiveAnalysis();
            },
            tooltip: 'Live analysis',
          ),
        ],
      ),
      body: Column(
        children: [
          // Analysis progress
          if (state.isAnalyzing)
            LinearProgressIndicator(
              value: state.analysisProgress,
              backgroundColor: AppTheme.surfaceDark,
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppTheme.primaryColor,
              ),
            ),

          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // Board with eval bar
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Eval bar
                        SizedBox(
                          height: MediaQuery.of(context).size.width - 48,
                          child: EvalBar(evaluation: state.currentEval),
                        ),
                        const SizedBox(width: 8),
                        // Chess board
                        Expanded(
                          child: AspectRatio(
                            aspectRatio: 1.0,
                            child: _AnalysisBoard(state: state),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Move classification badge
                  if (state.currentMoveAnalysis != null)
                    _MoveClassificationBadge(
                      analysis: state.currentMoveAnalysis!,
                    ),

                  // Navigation controls
                  _NavigationControls(
                    canGoPrevious: state.canGoPrevious,
                    canGoNext: state.canGoNext,
                    currentMove: state.currentMoveIndex + 1,
                    totalMoves: state.totalMoves,
                    onFirst:
                        () => ref.read(analysisProvider.notifier).firstMove(),
                    onPrevious:
                        () =>
                            ref.read(analysisProvider.notifier).previousMove(),
                    onNext:
                        () => ref.read(analysisProvider.notifier).nextMove(),
                    onLast:
                        () => ref.read(analysisProvider.notifier).lastMove(),
                  ),

                  // Evaluation graph (only show if we have analysis data)
                  if (state.analyzedMoves.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Evaluation',
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          EvalGraph(
                            evaluations: state.evaluations,
                            currentMoveIndex:
                                state.currentMoveIndex >= 0
                                    ? state.currentMoveIndex + 1
                                    : 0,
                            onMoveSelected: (index) {
                              ref
                                  .read(analysisProvider.notifier)
                                  .goToMove(index - 1);
                            },
                          ),
                        ],
                      ),
                    ),

                  // Engine lines
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: EngineLines(
                      lines: state.currentEngineLines,
                      isLoading:
                          state.isLiveAnalysis &&
                          state.currentEngineLines.isEmpty,
                    ),
                  ),

                  // Analysis summary (if full analysis done)
                  if (state.fullAnalysis != null)
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: _AnalysisSummary(analysis: state.fullAnalysis!),
                    ),

                  // Move list
                  if (state.originalMoves.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: _MoveList(
                        moves: state.originalMoves,
                        analyzedMoves: state.analyzedMoves,
                        currentIndex: state.currentMoveIndex,
                        onMoveSelected: (index) {
                          ref.read(analysisProvider.notifier).goToMove(index);
                        },
                      ),
                    ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _startFullAnalysis() async {
    setState(() => _isAnalyzing = true);
    await ref.read(analysisProvider.notifier).analyzeFullGame();
    setState(() => _isAnalyzing = false);
  }
}

/// Chess board for analysis mode
class _AnalysisBoard extends StatelessWidget {
  final AnalysisState state;

  const _AnalysisBoard({required this.state});

  @override
  Widget build(BuildContext context) {
    return ChessBoard(
      fen: state.fen,
      isFlipped: false,
      selectedSquare: state.selectedSquare,
      legalMoves: state.legalMoves,
      lastMoveFrom: state.lastMoveFrom,
      lastMoveTo: state.lastMoveTo,
      bestMove: state.bestMove,
      onSquareTap: null, // No interaction in analysis mode
      onMove: null,
      showCoordinates: true,
    );
  }
}

/// Move classification badge showing blunder/mistake/excellent etc.
class _MoveClassificationBadge extends StatelessWidget {
  final MoveAnalysis analysis;

  const _MoveClassificationBadge({required this.analysis});

  @override
  Widget build(BuildContext context) {
    final classification = analysis.classification;
    final color = Color(classification.color);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_getIcon(classification), color: color, size: 20),
          const SizedBox(width: 8),
          Text(
            '${analysis.san} - ${classification.name}',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          if (classification.symbol.isNotEmpty) ...[
            const SizedBox(width: 4),
            Text(
              classification.symbol,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
          if (analysis.evalLoss.abs() > 0.1) ...[
            const SizedBox(width: 12),
            Text(
              analysis.evalLoss > 0
                  ? '-${analysis.evalLoss.toStringAsFixed(1)}'
                  : '+${analysis.evalLoss.abs().toStringAsFixed(1)}',
              style: TextStyle(color: color.withOpacity(0.8), fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  IconData _getIcon(MoveClassification classification) {
    switch (classification) {
      case MoveClassification.blunder:
        return Icons.error;
      case MoveClassification.mistake:
        return Icons.warning;
      case MoveClassification.inaccuracy:
        return Icons.info;
      case MoveClassification.book:
        return Icons.book;
      case MoveClassification.good:
        return Icons.check;
      case MoveClassification.excellent:
        return Icons.star;
      case MoveClassification.brilliant:
        return Icons.auto_awesome;
      case MoveClassification.best:
        return Icons.verified;
    }
  }
}

/// Navigation controls for move navigation
class _NavigationControls extends StatelessWidget {
  final bool canGoPrevious;
  final bool canGoNext;
  final int currentMove;
  final int totalMoves;
  final VoidCallback onFirst;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onLast;

  const _NavigationControls({
    required this.canGoPrevious,
    required this.canGoNext,
    required this.currentMove,
    required this.totalMoves,
    required this.onFirst,
    required this.onPrevious,
    required this.onNext,
    required this.onLast,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.first_page),
            onPressed: canGoPrevious ? onFirst : null,
            color: AppTheme.textPrimary,
            disabledColor: AppTheme.textHint,
          ),
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: canGoPrevious ? onPrevious : null,
            color: AppTheme.textPrimary,
            disabledColor: AppTheme.textHint,
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.cardDark,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$currentMove / $totalMoves',
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: canGoNext ? onNext : null,
            color: AppTheme.textPrimary,
            disabledColor: AppTheme.textHint,
          ),
          IconButton(
            icon: const Icon(Icons.last_page),
            onPressed: canGoNext ? onLast : null,
            color: AppTheme.textPrimary,
            disabledColor: AppTheme.textHint,
          ),
        ],
      ),
    );
  }
}

/// Analysis summary showing game statistics
class _AnalysisSummary extends StatelessWidget {
  final GameAnalysis analysis;

  const _AnalysisSummary({required this.analysis});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Analysis Summary',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 16),
          // Accuracy
          Row(
            children: [
              const Icon(
                Icons.analytics,
                color: AppTheme.primaryColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'Accuracy:',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
              const Spacer(),
              Text(
                '${analysis.averageAccuracy.toStringAsFixed(1)}%',
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          const Divider(height: 24, color: AppTheme.surfaceDark),
          // Move counts
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _StatChip(
                label: 'Blunders',
                count: analysis.blunders,
                color: const Color(0xFFFF0000),
              ),
              _StatChip(
                label: 'Mistakes',
                count: analysis.mistakes,
                color: const Color(0xFFFF8C00),
              ),
              _StatChip(
                label: 'Inaccuracies',
                count: analysis.inaccuracies,
                color: const Color(0xFFFFD700),
              ),
              _StatChip(
                label: 'Excellent',
                count: analysis.excellentMoves,
                color: const Color(0xFF00FF00),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _StatChip({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$count',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(color: color.withOpacity(0.8), fontSize: 12),
          ),
        ],
      ),
    );
  }
}

/// Move list with analysis classification
class _MoveList extends StatelessWidget {
  final List<ChessMove> moves;
  final List<MoveAnalysis> analyzedMoves;
  final int currentIndex;
  final ValueChanged<int> onMoveSelected;

  const _MoveList({
    required this.moves,
    required this.analyzedMoves,
    required this.currentIndex,
    required this.onMoveSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Moves',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: List.generate(moves.length, (index) {
              final move = moves[index];
              final analysis =
                  index < analyzedMoves.length ? analyzedMoves[index] : null;
              final isSelected = index == currentIndex;
              final isWhiteMove = index % 2 == 0;
              final moveNum = (index ~/ 2) + 1;

              // Get classification color
              Color? classificationColor;
              if (analysis != null) {
                classificationColor = Color(analysis.classification.color);
              }

              return GestureDetector(
                onTap: () => onMoveSelected(index),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color:
                        isSelected
                            ? AppTheme.primaryColor.withOpacity(0.3)
                            : classificationColor?.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                    border:
                        isSelected
                            ? Border.all(color: AppTheme.primaryColor, width: 2)
                            : classificationColor != null
                            ? Border.all(
                              color: classificationColor.withOpacity(0.3),
                            )
                            : null,
                  ),
                  child: Text(
                    isWhiteMove ? '$moveNum. ${move.san}' : move.san,
                    style: TextStyle(
                      color: classificationColor ?? AppTheme.textPrimary,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 13,
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
