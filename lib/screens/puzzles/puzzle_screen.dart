import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chess_master/core/theme/app_theme.dart';
import 'package:chess_master/models/puzzle_model.dart';
import 'package:chess_master/providers/puzzle_provider.dart';
import 'package:chess_master/providers/journey_provider.dart';
import 'package:chess_master/screens/puzzles/widgets/puzzle_board_widget.dart';
import 'package:chess_master/widgets/shared/app_badge.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Puzzle training screen
class PuzzleScreen extends ConsumerStatefulWidget {
  final int? puzzleId;
  final PuzzleFilterMode? initialMode;
  final int? initialMinRating;
  final int? initialMaxRating;
  final String? initialTheme;
  const PuzzleScreen({
    super.key,
    this.puzzleId,
    this.initialMode,
    this.initialMinRating,
    this.initialMaxRating,
    this.initialTheme,
  });

  @override
  ConsumerState<PuzzleScreen> createState() => _PuzzleScreenState();
}

class _PuzzleScreenState extends ConsumerState<PuzzleScreen> {
  int? _lastJourneyFeedbackPuzzleId;
  Timer? _journeyAutoAdvanceTimer;

  @override
  void initState() {
    super.initState();
    // Lock orientation to portrait
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializePuzzles();
    });
  }

  @override
  void dispose() {
    _journeyAutoAdvanceTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializePuzzles() async {
    final notifier = ref.read(puzzleProvider.notifier);
    // Re-apply mode here: puzzleProvider is autoDispose, so the instance
    // configured by the menu may have been disposed during navigation,
    // which silently reset the mode to adaptive and froze journey progress
    // at level 1. Configuring in initState guarantees journey mode sticks.
    if (widget.initialMode != null) {
      notifier.setModeConfig(
        mode: widget.initialMode!,
        minRating: widget.initialMinRating,
        maxRating: widget.initialMaxRating,
        theme: widget.initialTheme,
      );
      return;
    }
    await notifier.initialize();

    if (widget.puzzleId != null) {
      await notifier.loadPuzzleById(widget.puzzleId!);
    } else if (ref.read(puzzleProvider).currentPuzzle == null) {
      await notifier.startNewPuzzle();
    }
  }

  /// Seamless journey progression: brief snackbar feedback + auto-advance.
  /// Never opens a dialog and never requires manual dismissal. The inline
  /// success banner in [_buildStatusWidget] stays visible as confirmation.
  void _checkJourneySeamlessAdvance(PuzzleGameState state) {
    if (state.mode != PuzzleFilterMode.journey) return;
    final puzzle = state.currentPuzzle;
    if (state.state != PuzzleState.completed || puzzle == null) {
      if (state.state != PuzzleState.completed) {
        _journeyAutoAdvanceTimer?.cancel();
      }
      return;
    }
    if (_lastJourneyFeedbackPuzzleId == puzzle.id) return;
    _lastJourneyFeedbackPuzzleId = puzzle.id;

    final journey = ref.read(journeyProvider);
    final milestone = journey.newlyUnlockedMilestone;
    if (milestone != null) {
      ref.read(journeyProvider.notifier).clearNewlyUnlockedMilestone();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final progress =
          '${journey.solvedCount} / $kTotalJourneyLevels solved';
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              milestone != null
                  ? 'Solved! Milestone $milestone reached • $progress'
                  : 'Solved! $progress — next level loading…',
            ),
            duration: const Duration(milliseconds: 1200),
            behavior: SnackBarBehavior.floating,
          ),
        );
    });

    _journeyAutoAdvanceTimer?.cancel();
    _journeyAutoAdvanceTimer = Timer(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      ref.read(puzzleProvider.notifier).nextPuzzle();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(puzzleProvider);
    _checkJourneySeamlessAdvance(state);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          _getAppBarTitle(state.mode),
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        actions: [
          _buildAppBarAction(state),
          if (state.mode != PuzzleFilterMode.journey)
            IconButton(
              icon: const Icon(Icons.skip_next_rounded),
              tooltip: 'Skip Puzzle',
              onPressed: () => ref.read(puzzleProvider.notifier).nextPuzzle(),
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child:
            state.isLoading
                ? const Center(
                  child: CircularProgressIndicator(
                    color: AppTheme.primaryColor,
                  ),
                )
                : state.errorMessage != null && state.currentPuzzle == null
                ? _buildErrorWidget(state)
                : _buildPuzzleContent(state),
      ),
    );
  }

  Widget _buildErrorWidget(PuzzleGameState state) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: AppTheme.error, size: 48),
          const SizedBox(height: 16),
          Text(
            state.errorMessage!,
            style: GoogleFonts.inter(color: AppTheme.textSecondaryFor(context)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _initializePuzzles,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Retry',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPuzzleContent(PuzzleGameState state) {
    if (state.currentPuzzle == null || state.board == null) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primaryColor),
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: Column(
          children: [
            // Compact Puzzle info bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: _buildPuzzleInfoCard(state),
        ),

        // Status message container with fixed height to prevent shaking
        SizedBox(
          height: 38,
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _buildStatusWidget(state),
            ),
          ),
        ),

        // Chess board with premium container
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: AspectRatio(
                aspectRatio: 1.0,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 20,
                        spreadRadius: -4,
                        offset: const Offset(0, 8),
                      ),
                    ],
                    border: Border.all(
                      color: AppTheme.borderStroke(context),
                      width: 1.5,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd - 1.5),
                    child: PuzzleBoardWidget(state: state, ref: ref),
                  ),
                ),
              ),
            ),
          ),
        ),

            // Controls
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: _buildControls(state),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusWidget(PuzzleGameState state) {
    if (state.state == PuzzleState.incorrect) {
      final delta = state.lastRatingDelta;
      return Container(
        key: const ValueKey('incorrect'),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.error.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.close, color: AppTheme.error, size: 18),
            const SizedBox(width: 8),
            Text(
              state.errorMessage ?? "Wrong Move! Try Again",
              style: GoogleFonts.inter(
                color: AppTheme.error,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (delta != null && state.mode != PuzzleFilterMode.journey) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.error.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$delta (${state.currentRating})',
                  style: GoogleFonts.inter(
                    color: AppTheme.error,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    }

    if (state.state == PuzzleState.correct ||
        state.state == PuzzleState.completed) {
      final isCompleted = state.state == PuzzleState.completed;
      final delta = state.lastRatingDelta;
      String message;
      if (state.mode == PuzzleFilterMode.journey) {
        message = isCompleted ? "Level Solved!" : "Correct!";
      } else if (state.mode == PuzzleFilterMode.adaptive) {
        message = isCompleted
            ? "Puzzle Solved! Rating: ${state.currentRating}"
            : "Correct Move!";
      } else {
        message = isCompleted ? "Puzzle Solved!" : "Correct Move!";
      }

      return Container(
        key: const ValueKey('correct'),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check, color: Colors.green, size: 18),
            const SizedBox(width: 8),
            Text(
              message,
              style: GoogleFonts.inter(
                color: Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (isCompleted && delta != null && delta > 0 && state.mode != PuzzleFilterMode.journey) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '+$delta',
                  style: GoogleFonts.inter(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    }

    return Text(
      state.isWhiteTurn ? "White to Move" : "Black to Move",
      key: const ValueKey('turn'),
      style: GoogleFonts.inter(
        color: AppTheme.textSecondaryFor(context),
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildControls(PuzzleGameState state) {
    final notifier = ref.read(puzzleProvider.notifier);
    final isFailed = state.state == PuzzleState.incorrect;
    final isCompleted = state.state == PuzzleState.completed;

    final isJourney = state.mode == PuzzleFilterMode.journey;

    if (isFailed || isCompleted) {
      if (isJourney) {
        if (isCompleted) {
          return SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => notifier.nextPuzzle(),
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Next Level →'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          );
        } else {
          return SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => notifier.retryPuzzle(),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry Level'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.textPrimaryFor(context),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          );
        }
      }

      return Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => notifier.retryPuzzle(),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.textPrimaryFor(context),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed: () => notifier.nextPuzzle(),
              icon: const Icon(Icons.arrow_forward),
              label: Text(isCompleted ? 'Next Puzzle' : 'Skip'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      );
    }

    if (isJourney) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () => notifier.showHint(),
          icon: const Icon(Icons.lightbulb_outline),
          label: const Text('Get Hint'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.textPrimaryFor(context),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => notifier.showHint(),
            icon: const Icon(Icons.lightbulb_outline),
            label: const Text('Hint'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.textPrimaryFor(context),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _showSolutionDialog(state),
            icon: const Icon(Icons.visibility),
            label: const Text('Solution'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.textPrimaryFor(context),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _getAppBarTitle(PuzzleFilterMode mode) {
    switch (mode) {
      case PuzzleFilterMode.journey:
        return 'Puzzle Journey';
      case PuzzleFilterMode.adaptive:
        return 'Adaptive Tactics';
      case PuzzleFilterMode.random:
        return 'Random Puzzles';
      case PuzzleFilterMode.eloRange:
        return 'Target Rating';
      case PuzzleFilterMode.theme:
        return 'Theme Practice';
      case PuzzleFilterMode.daily:
        return 'Daily Puzzle';
    }
  }

  Widget _buildAppBarAction(PuzzleGameState state) {
    final journey = ref.watch(journeyProvider);

    if (state.mode == PuzzleFilterMode.journey) {
      return Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.teal.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.teal.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.route_rounded, color: Colors.teal, size: 16),
            const SizedBox(width: 5),
            Text(
              '${journey.currentLevel}/$kTotalJourneyLevels',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Colors.teal,
              ),
            ),
          ],
        ),
      );
    }

    if (state.mode == PuzzleFilterMode.adaptive) {
      return Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.trending_up_rounded, color: AppTheme.primaryColor, size: 16),
            const SizedBox(width: 5),
            Text(
              '${state.currentRating} ELO',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: AppTheme.primaryColor,
              ),
            ),
          ],
        ),
      );
    }

    if (state.mode == PuzzleFilterMode.random) {
      return Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.purple.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.purple.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.shuffle_rounded, color: Colors.purple, size: 15),
            const SizedBox(width: 5),
            Text(
              'Random',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Colors.purple,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.cardColor(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderColorFor(context)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.emoji_events, color: Colors.amber, size: 16),
          const SizedBox(width: 5),
          Text(
            '${state.currentRating}',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: AppTheme.textPrimaryFor(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPuzzleInfoCard(PuzzleGameState state) {
    final puzzle = state.currentPuzzle!;
    final journey = ref.watch(journeyProvider);
    final isJourney = state.mode == PuzzleFilterMode.journey;
    final isAdaptive = state.mode == PuzzleFilterMode.adaptive;
    final isRandom = state.mode == PuzzleFilterMode.random;
    final isDaily = state.mode == PuzzleFilterMode.daily;
    final isTheme = state.mode == PuzzleFilterMode.theme;

    // Determine badge strictly by mode
    Widget badge;

    if (isJourney) {
      badge = AppBadge.status(
        label: 'LEVEL ${journey.currentLevel} OF $kTotalJourneyLevels',
        color: Colors.teal,
        icon: Icons.route_rounded,
      );
    } else if (isAdaptive) {
      badge = AppBadge.status(
        label: 'ADAPTIVE TRAINING',
        color: AppTheme.primaryColor,
        icon: Icons.auto_awesome_rounded,
      );
    } else if (isRandom) {
      badge = AppBadge.status(
        label: 'RANDOM TACTICS',
        color: Colors.purple,
        icon: Icons.shuffle_rounded,
      );
    } else if (isDaily) {
      badge = AppBadge.status(
        label: 'DAILY PUZZLE',
        color: AppTheme.amberGold,
        icon: Icons.calendar_today_rounded,
      );
    } else if (isTheme) {
      final themeName = widget.initialTheme ?? 'Tactics';
      badge = AppBadge.status(
        label: themeName.toUpperCase(),
        color: const Color(0xFF8B5CF6),
        icon: Icons.category_rounded,
      );
    } else {
      badge = AppBadge.status(
        label: 'TARGET RATING',
        color: Colors.blueGrey,
        icon: Icons.tune_rounded,
      );
    }

    final textPrimary = AppTheme.textPrimaryFor(context);
    final textSecondary = AppTheme.textSecondaryFor(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLevel1(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.borderStroke(context)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              badge,
              if (isJourney)
                Text(
                  '${journey.solvedCount} / $kTotalJourneyLevels',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal,
                  ),
                )
              else if (isAdaptive && state.streak > 0)
                AppBadge.streak(streakDays: state.streak, isActiveToday: true)
              else
                Text(
                  '${puzzle.rating} ELO',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                ),
            ],
          ),
          if (isJourney) ...[
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: (journey.currentLevel / kTotalJourneyLevels).clamp(0.0, 1.0),
                minHeight: 4,
                backgroundColor: AppTheme.borderStroke(context),
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.teal),
              ),
            ),
          ] else ...[
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Puzzle #${puzzle.id}',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: textSecondary,
                  ),
                ),
                if (puzzle.themes.isNotEmpty)
                  Text(
                    puzzle.themes.first,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.primaryColor,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _showSolutionDialog(PuzzleGameState state) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: AppTheme.surfaceColor(context),
            title: const Text('Show Solution?'),
            content: const Text(
              'Showing the solution will end the puzzle attempt.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  ref.read(puzzleProvider.notifier).showSolution();
                },
                child: const Text('Show'),
              ),
            ],
          ),
    );
  }
}
