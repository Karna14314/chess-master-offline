import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chess_master/core/theme/app_theme.dart';
import 'package:chess_master/models/game_model.dart';

import 'package:chess_master/core/constants/app_constants.dart';
import 'package:chess_master/providers/analysis_provider.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

// Import our newly created reusable widgets
import 'package:chess_master/screens/game/widgets/chess_board.dart';
import 'package:chess_master/screens/analysis/widgets/unified_eval_bar.dart';
import 'package:chess_master/screens/analysis/widgets/move_navigation_bar.dart';
import 'package:chess_master/screens/analysis/widgets/current_move_details.dart';
import 'package:chess_master/screens/analysis/widgets/engine_recommendations.dart';
import 'package:chess_master/screens/analysis/widgets/move_explanation.dart';
import 'package:chess_master/screens/analysis/widgets/interactive_eval_graph.dart';
import 'package:chess_master/screens/analysis/widgets/game_accuracy_summary.dart';
import 'package:chess_master/screens/analysis/widgets/move_history_list.dart';
import 'package:chess_master/screens/analysis/widgets/export_share_buttons.dart';

class AnalysisScreen extends ConsumerStatefulWidget {
  final List<ChessMove>? moves;
  final String? startingFen;

  const AnalysisScreen({super.key, this.moves, this.startingFen});

  @override
  ConsumerState<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends ConsumerState<AnalysisScreen> {
  bool _isFlipped = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeAnalysis();
    });
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeRight,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    super.dispose();
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

  Future<void> _startFullAnalysis() async {
    await ref.read(analysisProvider.notifier).analyzeFullGame();
    if (mounted) {}
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(analysisProvider);
    final notifier = ref.read(analysisProvider.notifier);

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceDark,
        elevation: 0,
        title: Text(
          'Game Analysis',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (value) {
              if (value == 'flip') {
                setState(() {
                  _isFlipped = !_isFlipped;
                });
              } else if (value == 'analyze') {
                _startFullAnalysis();
              }
            },
            itemBuilder:
                (context) => [
                  const PopupMenuItem(
                    value: 'flip',
                    child: Row(
                      children: [
                        Icon(Icons.flip_camera_android_rounded),
                        SizedBox(width: 8),
                        Text('Flip Board'),
                      ],
                    ),
                  ),
                  if (state.originalMoves.isNotEmpty && !state.isAnalyzing)
                    const PopupMenuItem(
                      value: 'analyze',
                      child: Row(
                        children: [
                          Icon(Icons.analytics_rounded),
                          SizedBox(width: 8),
                          Text('Analyze Full Game'),
                        ],
                      ),
                    ),
                ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Global Loading Indicator for full game analysis
          if (state.isAnalyzing)
            LinearProgressIndicator(
              value: state.analysisProgress,
              backgroundColor: AppTheme.surfaceDark,
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppTheme.primaryColor,
              ),
            ),

          // Unified Scrollable View
          Expanded(
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 32.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // --- 1. Board & Evaluation Bar Layout ---
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left side: Eval Bar
                          Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: SizedBox(
                              height:
                                  MediaQuery.of(context).size.width -
                                  64, // Matches board size
                              child: UnifiedEvalBar(
                                evaluation: state.currentEval,
                                isFlipped: _isFlipped,
                              ),
                            ),
                          ),
                          // Right side: Chess Board
                          Expanded(
                            child: AspectRatio(
                              aspectRatio: 1.0,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: ChessBoard(
                                  fen: state.fen,
                                  isFlipped: _isFlipped,
                                  selectedSquare: state.selectedSquare,
                                  legalMoves: state.legalMoves,
                                  lastMoveFrom: state.lastMoveFrom,
                                  lastMoveTo: state.lastMoveTo,
                                  bestMove: state.bestMove,
                                  onSquareTap: null, // read-only
                                  onMove: null, // read-only
                                  showCoordinates: true,
                                  enableMoveAnimation: true,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // --- 2. Move Navigation ---
                    MoveNavigationBar(
                      canGoPrevious: state.canGoPrevious,
                      canGoNext: state.canGoNext,
                      currentMove: state.currentMoveIndex + 1,
                      totalMoves: state.totalMoves,
                      onFirst: notifier.firstMove,
                      onPrevious: notifier.previousMove,
                      onNext: notifier.nextMove,
                      onLast: notifier.lastMove,
                      // Jump logic (Find previous/next move index with blunder/mistake classification)
                      onJumpToPreviousMistake:
                          state.analyzedMoves.isNotEmpty
                              ? () {
                                for (
                                  int i = state.currentMoveIndex - 1;
                                  i >= 0;
                                  i--
                                ) {
                                  if (i < state.analyzedMoves.length) {
                                    final c =
                                        state.analyzedMoves[i].classification;
                                    if (c == MoveClassification.blunder ||
                                        c == MoveClassification.mistake) {
                                      notifier.goToMove(i);
                                      return;
                                    }
                                  }
                                }
                              }
                              : null,
                      onJumpToNextMistake:
                          state.analyzedMoves.isNotEmpty
                              ? () {
                                for (
                                  int i = state.currentMoveIndex + 1;
                                  i < state.analyzedMoves.length;
                                  i++
                                ) {
                                  final c =
                                      state.analyzedMoves[i].classification;
                                  if (c == MoveClassification.blunder ||
                                      c == MoveClassification.mistake) {
                                    notifier.goToMove(i);
                                    return;
                                  }
                                }
                              }
                              : null,
                    ),

                    // --- 3. Current Move Details ---
                    if (state.currentMoveAnalysis != null)
                      CurrentMoveDetails(analysis: state.currentMoveAnalysis!),

                    // --- 4. Move Explanation ---
                    if (state.currentMoveAnalysis != null)
                      MoveExplanation(analysis: state.currentMoveAnalysis!),

                    // --- 5. Engine Recommendations ---
                    EngineRecommendations(
                      lines: state.currentEngineLines,
                      isLoading:
                          state.isLiveAnalysis &&
                          state.currentEngineLines.isEmpty,
                    ),

                    // --- 6. Evaluation Graph ---
                    if (state.evaluations.isNotEmpty)
                      InteractiveEvalGraph(
                        evaluations: state.evaluations,
                        currentMoveIndex:
                            state.currentMoveIndex >= 0
                                ? state.currentMoveIndex + 1
                                : 0,
                        onMoveSelected: (index) {
                          notifier.goToMove(index - 1);
                        },
                      ),

                    // --- 7. Game Summary ---
                    if (state.fullAnalysis != null)
                      GameAccuracySummary(
                        analysis: state.fullAnalysis!,
                        openingName:
                            state.fullAnalysis!.moves.length > 5
                                ? "Custom Opening"
                                : null, // Mocked for now, can be extracted later
                      ),

                    // --- 8. Move List History ---
                    if (state.originalMoves.isNotEmpty)
                      MoveHistoryList(
                        moves: state.originalMoves,
                        analyzedMoves: state.analyzedMoves,
                        currentIndex: state.currentMoveIndex,
                        onMoveSelected: notifier.goToMove,
                      ),

                    // --- 9. Export and Share ---
                    ExportShareButtons(pgn: _buildPgn(state), fen: state.fen),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _buildPgn(AnalysisState state) {
    if (state.originalMoves.isEmpty) return "";
    StringBuffer sb = StringBuffer();
    sb.writeln('[Event "Analysis"]');
    sb.writeln('[Date "${DateTime.now().toIso8601String().split('T')[0]}"]');
    sb.writeln();
    for (int i = 0; i < state.originalMoves.length; i++) {
      if (i % 2 == 0) {
        sb.write('${(i ~/ 2) + 1}. ');
      }
      sb.write('${state.originalMoves[i].san} ');
    }
    return sb.toString().trim();
  }
}
