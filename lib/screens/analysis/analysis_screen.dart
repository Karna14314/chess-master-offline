import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chess_master/core/theme/app_theme.dart';
import 'package:chess_master/core/constants/app_constants.dart';
import 'package:chess_master/models/game_model.dart';
import 'package:chess_master/providers/analysis_provider.dart';
import 'package:chess_master/providers/settings_provider.dart';
import 'package:chess_master/providers/statistics_provider.dart';
import 'package:chess_master/providers/achievement_provider.dart';
import 'package:chess_master/data/repositories/game_session_repository.dart';
import 'package:chess_master/core/services/lesson_service.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:chess_master/screens/game/widgets/chess_board.dart';
import 'package:chess_master/screens/analysis/widgets/unified_eval_bar.dart';
import 'package:chess_master/screens/analysis/widgets/move_navigation_bar.dart';
import 'package:chess_master/screens/analysis/widgets/current_move_details.dart';
import 'package:chess_master/screens/analysis/widgets/engine_recommendations.dart';
import 'package:chess_master/screens/analysis/widgets/move_explanation.dart';
import 'package:chess_master/screens/analysis/widgets/game_accuracy_summary.dart';
import 'package:chess_master/screens/analysis/widgets/move_history_list.dart';
import 'package:chess_master/screens/analysis/widgets/export_share_buttons.dart';
import 'package:chess_master/widgets/shared/app_card.dart';
import 'package:chess_master/widgets/shared/themed_board_container.dart';

class AnalysisScreen extends ConsumerStatefulWidget {
  final List<ChessMove>? moves;
  final String? startingFen;
  final String? gameId;

  const AnalysisScreen({super.key, this.moves, this.startingFen, this.gameId});

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
    super.dispose();
  }

  Future<void> _initializeAnalysis() async {
    final notifier = ref.read(analysisProvider.notifier);
    // Count every completed full-game analysis in statistics + unlocks,
    // and stamp the source game session so History can filter Analysed games.
    notifier.onAnalysisComplete = () async {
      final statsNotifier = ref.read(statisticsProvider.notifier);
      await statsNotifier.recordGameAnalysed();
      final gameId = widget.gameId;
      if (gameId != null) {
        try {
          final repo = ref.read(gameSessionRepositoryProvider);
          final session = await repo.getSession(gameId);
          if (session != null) {
            await repo.saveSession(
              session.copyWith(
                analysisData: {
                  'analysed': true,
                  'analysedAt': DateTime.now().millisecondsSinceEpoch,
                },
              ),
            );
          }
        } catch (_) {}
      }
      try {
        final stats = ref.read(statisticsProvider);
        ref.read(achievementProvider.notifier).checkStudyProgress(
          gamesAnalysed: stats.gamesAnalysed,
          lessonsCompleted:
              LessonService.instance.completedChaptersCount,
          openingsPlayed:
              stats.openingsPlayed.keys.length,
        );
      } catch (_) {}
    };
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

  void _startPracticeMode(
    BuildContext context,
    AnalysisState state,
    AnalysisNotifier notifier,
  ) {
    final currentMoveIndex = state.currentMoveIndex;
    if (currentMoveIndex < 0 ||
        currentMoveIndex >= state.analyzedMoves.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Analysis for this move is still in progress...'),
        ),
      );
      return;
    }

    final analyzedMove = state.analyzedMoves[currentMoveIndex];
    final classification = analyzedMove.classification;

    if (classification != MoveClassification.blunder &&
        classification != MoveClassification.mistake &&
        classification != MoveClassification.inaccuracy &&
        classification != MoveClassification.miss) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This move was already good! Practice your mistakes instead.',
          ),
        ),
      );
      return;
    }

    final prevMoveIndex = currentMoveIndex - 1;
    String practiceFen;
    if (prevMoveIndex >= 0 && prevMoveIndex < state.analyzedMoves.length) {
      practiceFen = state.analyzedMoves[prevMoveIndex].fen;
    } else {
      practiceFen = state.startingFen;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => Scaffold(
              appBar: AppBar(
                title: const Text('Practice Position'),
                backgroundColor: Theme.of(context).colorScheme.surface,
              ),
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.fitness_center_rounded,
                        size: 64,
                        color: Color(0xFF00ACC1),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Practice Mode',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Find the best move in this position.\nYour original move was: ${analyzedMove.san} (${classification.name})',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 32),
                      Text(
                        'FEN: $practiceFen',
                        style: Theme.of(context).textTheme.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
                      ElevatedButton.icon(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.analytics_rounded),
                        label: const Text('Back to Analysis'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(analysisProvider);
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(analysisProvider.notifier);
    final boardSize = min(MediaQuery.of(context).size.width - 64, 320.0);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        title: Text(
          'Game Analysis',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.flip_camera_android_rounded),
            tooltip: 'Flip Board',
            onPressed: () {
              setState(() {
                _isFlipped = !_isFlipped;
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // -------------------------------------------------------------
          // Top Half: Interactive Board + Eval Bar + Navigation (Fixed)
          // 0ms delay, fully scrubbable while engine calculates below!
          // -------------------------------------------------------------
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 540),
              child: Container(
                color: Theme.of(context).colorScheme.surface,
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Eval Bar
                    Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: SizedBox(
                        height: boardSize,
                        child: UnifiedEvalBar(
                          evaluation: state.currentEval,
                          isFlipped: _isFlipped,
                          showWinPercent: settings.showWinPercent,
                        ),
                      ),
                    ),
                    // Chess Board wrapped in ThemedBoardContainer
                    Expanded(
                      child: ThemedBoardContainer(
                        borderRadius: 8,
                        child: ChessBoard(
                          fen: state.fen,
                          isFlipped: _isFlipped,
                          selectedSquare: state.selectedSquare,
                          legalMoves: state.legalMoves,
                          lastMoveFrom: state.lastMoveFrom,
                          lastMoveTo: state.lastMoveTo,
                          bestMove: state.bestMove,
                          onSquareTap: null,
                          onMove: null,
                          showCoordinates: true,
                          enableMoveAnimation: true,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Move Navigation Bar
                MoveNavigationBar(
                  canGoPrevious: state.canGoPrevious,
                  canGoNext: state.canGoNext,
                  currentMove: state.currentMoveIndex + 1,
                  totalMoves: state.totalMoves,
                  onFirst: notifier.firstMove,
                  onPrevious: notifier.previousMove,
                  onNext: notifier.nextMove,
                  onLast: notifier.lastMove,
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
                                    c == MoveClassification.mistake ||
                                    c == MoveClassification.inaccuracy ||
                                    c == MoveClassification.miss) {
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
                                  c == MoveClassification.mistake ||
                                  c == MoveClassification.inaccuracy ||
                                  c == MoveClassification.miss) {
                                notifier.goToMove(i);
                                return;
                              }
                            }
                          }
                          : null,
                  onPracticeFromHere:
                      state.currentMoveIndex >= 0
                          ? () => _startPracticeMode(context, state, notifier)
                          : null,
                ),
              ],
            ),
          ),
        ),
      ),

      const Divider(height: 1, thickness: 1),

      // -------------------------------------------------------------
      // Bottom Half: Non-Blocking Streaming Score, Live Moves & Review
      // -------------------------------------------------------------
      Expanded(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Prominent Live Streaming Progress Card
                  if (state.isAnalyzing) ...[
                    _buildStreamingProgressCard(state),
                    const SizedBox(height: 10),
                  ],

                  // 2. Current Move Details & Explanation
                  if (state.currentMoveAnalysis != null) ...[
                    CurrentMoveDetails(
                      analysis: state.currentMoveAnalysis!,
                      onRetry: () {
                        if (state.currentMoveIndex > 0) {
                          notifier.goToMove(state.currentMoveIndex - 1);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Try to find a better move!'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    MoveExplanation(analysis: state.currentMoveAnalysis!),
                    const SizedBox(height: 8),
                  ],

                  // 3. Engine Recommendations
                  // isLoading only while a live engine pass is actually
                  // running: after analyzeFullGame() completes, isAnalyzing
                  // is false but currentEngineLines stays empty until the
                  // user taps a move (goToMove fills lines instantly from
                  // analyzedMoves). Gating on isAnalyzing avoids the stale
                  // "Analyzing position..." spinner after overall analysis.
                  EngineRecommendations(
                    lines: state.currentEngineLines,
                    isLoading:
                        state.isLiveAnalysis &&
                        state.isAnalyzing &&
                        state.currentEngineLines.isEmpty,
                    fen: state.fen,
                  ),
                  const SizedBox(height: 10),

                  // 4. Total Game Accuracy Summary (Positioned below the score)
                  if (state.fullAnalysis != null) ...[
                    GameAccuracySummary(
                      analysis: state.fullAnalysis!,
                      isInProgress: state.isAnalyzing,
                      openingName: state.fullAnalysis!.openingName != null
                          ? (state.fullAnalysis!.ecoCode != null
                              ? '${state.fullAnalysis!.ecoCode} · ${state.fullAnalysis!.openingName}'
                              : state.fullAnalysis!.openingName)
                          : null,
                    ),
                    const SizedBox(height: 10),
                  ],

                  // 5. Move History List
                  if (state.originalMoves.isNotEmpty) ...[
                    MoveHistoryList(
                      moves: state.originalMoves,
                      analyzedMoves: state.analyzedMoves,
                      currentIndex: state.currentMoveIndex,
                      onMoveSelected: notifier.goToMove,
                    ),
                    const SizedBox(height: 10),
                  ],

                  // 6. Export and Share
                  ExportShareButtons(pgn: _buildPgn(state), fen: state.fen),
                ],
              ),
            ),
          ),
        ),
      ),
    ],
  ),
);
  }

  Widget _buildStreamingProgressCard(AnalysisState state) {
    final progress = state.analysisProgress.clamp(0.0, 1.0);
    final percentInt = (progress * 100).round();
    final analyzedCount = state.analyzedMoves.length;
    final totalCount = state.totalMoves;

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      borderColor: AppTheme.primaryColor.withValues(alpha: 0.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppTheme.primaryColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Analyzing Game ($percentInt%)...',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ],
              ),
              Text(
                'Move $analyzedCount of $totalCount',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textSecondaryFor(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress > 0 ? progress : null,
              minHeight: 6,
              backgroundColor: Colors.grey.withValues(alpha: 0.2),
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppTheme.primaryColor,
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
    sb.writeln('[Event "ChessMaster Game"]');
    sb.writeln('[Site "ChessMaster Offline"]');
    sb.writeln('[Date "${DateTime.now().toIso8601String().split('T')[0]}"]');
    sb.writeln('[White "Player"]');
    sb.writeln('[Black "Bot"]');
    sb.writeln('[Result "*"]');
    sb.writeln();
    for (int i = 0; i < state.originalMoves.length; i++) {
      if (i % 2 == 0) {
        sb.write('${(i ~/ 2) + 1}. ');
      }
      sb.write('${state.originalMoves[i].san} ');
    }
    sb.write('*');
    return sb.toString().trim();
  }
}
