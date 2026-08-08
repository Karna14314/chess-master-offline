import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chess_master/core/theme/app_theme.dart';
import 'package:chess_master/models/game_model.dart';
import 'package:chess_master/core/constants/app_constants.dart';
import 'package:chess_master/providers/analysis_provider.dart';
import 'package:chess_master/providers/settings_provider.dart';
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
import 'package:chess_master/screens/analysis/widgets/interactive_eval_graph.dart';
import 'package:chess_master/screens/analysis/widgets/accuracy_header.dart';

class AnalysisScreen extends ConsumerStatefulWidget {
  final List<ChessMove>? moves;
  final String? startingFen;

  const AnalysisScreen({super.key, this.moves, this.startingFen});

  @override
  ConsumerState<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends ConsumerState<AnalysisScreen>
    with SingleTickerProviderStateMixin {
  bool _isFlipped = false;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
    _tabController.dispose();
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

  void _startPracticeMode(
    BuildContext context,
    AnalysisState state,
    AnalysisNotifier notifier,
  ) {
    final currentMoveIndex = state.currentMoveIndex;
    if (currentMoveIndex < 0 || currentMoveIndex >= state.analyzedMoves.length) {
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
          content: Text('This move was already good! Practice your mistakes instead.'),
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
        builder: (context) => Scaffold(
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

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        title: Text(
          'Analysis Board',
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
          // Top Loading Progress Bar for Auto Full Game Analysis
          if (state.isAnalyzing)
            LinearProgressIndicator(
              value: state.analysisProgress > 0 ? state.analysisProgress : null,
              backgroundColor: AppTheme.surfaceColor(context),
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppTheme.primaryColor,
              ),
            ),

          // Main Board & Navigation Section (Fixed on top)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left side: Eval Bar
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: SizedBox(
                    height: MediaQuery.of(context).size.width - 64,
                    child: UnifiedEvalBar(
                      evaluation: state.currentEval,
                      isFlipped: _isFlipped,
                      showWinPercent: settings.showWinPercent,
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
                        onSquareTap: null,
                        onMove: null,
                        showCoordinates: true,
                        enableMoveAnimation: true,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Move Navigation Controls
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
                      for (int i = state.currentMoveIndex - 1; i >= 0; i--) {
                        if (i < state.analyzedMoves.length) {
                          final c = state.analyzedMoves[i].classification;
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
                        final c = state.analyzedMoves[i].classification;
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

          // Lichess Style Tab Bar Header
          Container(
            color: AppTheme.cardColor(context),
            child: TabBar(
              controller: _tabController,
              indicatorColor: AppTheme.primaryColor,
              labelColor: AppTheme.primaryColor,
              unselectedLabelColor: AppTheme.textSecondaryFor(context),
              labelStyle: GoogleFonts.inter(fontWeight: FontWeight.bold),
              tabs: const [
                Tab(text: 'Analysis 🔍'),
                Tab(text: 'Report 📊'),
                Tab(text: 'Moves 📜'),
              ],
            ),
          ),

          // Tab Views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Tab 1: Current Move Analysis & Engine PV Lines
                SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Column(
                    children: [
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
                        MoveExplanation(analysis: state.currentMoveAnalysis!),
                      ],
                      EngineRecommendations(
                        lines: state.currentEngineLines,
                        isLoading:
                            state.isLiveAnalysis &&
                            state.currentEngineLines.isEmpty,
                        fen: state.fen,
                      ),
                      ExportShareButtons(pgn: _buildPgn(state), fen: state.fen),
                    ],
                  ),
                ),

                // Tab 2: Game Accuracy & Classification Summary Report
                SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Column(
                    children: [
                      if (state.fullAnalysis != null) ...[
                        AccuracyHeader(analysis: state.fullAnalysis!),
                        if (state.analyzedMoves.isNotEmpty)
                          InteractiveEvalGraph(
                            evaluations: state.evaluations,
                            currentMoveIndex: state.currentMoveIndex,
                            onMoveSelected: notifier.goToMove,
                          ),
                        GameAccuracySummary(
                          analysis: state.fullAnalysis!,
                          openingName:
                              state.fullAnalysis!.moves.length > 5
                                  ? "Custom Opening"
                                  : null,
                        ),
                      ] else if (!state.isAnalyzing)
                        Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Column(
                            children: [
                              const Icon(
                                Icons.analytics_outlined,
                                size: 48,
                                color: Colors.grey,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Not enough moves to analyze.\nPlay a game with at least a few moves.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  color: AppTheme.textSecondaryFor(context),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Column(
                            children: [
                              const CircularProgressIndicator(),
                              const SizedBox(height: 16),
                              Text(
                                'Analyzing game positions...',
                                style: GoogleFonts.inter(
                                  color: AppTheme.textSecondaryFor(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),

                // Tab 3: Move History Table
                SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Column(
                    children: [
                      if (state.originalMoves.isNotEmpty)
                        MoveHistoryList(
                          moves: state.originalMoves,
                          analyzedMoves: state.analyzedMoves,
                          currentIndex: state.currentMoveIndex,
                          onMoveSelected: notifier.goToMove,
                        ),
                    ],
                  ),
                ),
              ],
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
