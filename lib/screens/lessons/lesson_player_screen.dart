import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:chess/chess.dart' as chess;
import 'package:chess_master/core/services/audio_service.dart';
import 'package:chess_master/core/services/lesson_service.dart';
import 'package:chess_master/providers/achievement_provider.dart';
import 'package:chess_master/providers/statistics_provider.dart';
import 'package:chess_master/core/theme/app_theme.dart';
import 'package:chess_master/screens/game/widgets/chess_board.dart';
import 'package:chess_master/widgets/shared/app_card.dart';
import 'package:chess_master/widgets/shared/themed_board_container.dart';

const Color _accentGold = Color(0xFFF59E0B);
const Color _successGreen = Color(0xFF2E7D32);
const Color _lossRed = Color(0xFFEF5350);

class LessonPlayerScreen extends ConsumerStatefulWidget {
  final String categoryId;
  final int initialChapterIndex;

  const LessonPlayerScreen({
    super.key,
    required this.categoryId,
    this.initialChapterIndex = 0,
  });

  @override
  ConsumerState<LessonPlayerScreen> createState() => _LessonPlayerScreenState();
}

class _LessonPlayerScreenState extends ConsumerState<LessonPlayerScreen> {
  late List<LessonChapter> _chapters;
  late int _currentIndex;
  late chess.Chess _board;

  int _moveStep = 0;
  bool _isCompleted = false;
  bool _isOpponentMoving = false;
  String? _feedbackMessage;
  Color _feedbackColor = Colors.transparent;

  String? _selectedSquare;
  List<String> _legalMoves = [];
  String? _lastMoveFrom;
  String? _lastMoveTo;

  int _hintsShown = 0;
  bool _showHintArrow = false;

  /// v2 lesson phases: 0 = concept intro, 1 = guided play, 2 = quiz.
  int _phase = 1;
  int? _quizPicked;
  bool _quizCorrect = false;

  /// Fixed board orientation for the whole chapter, captured at load time
  /// from the starting FEN. Never derive this from the live board position:
  /// the side to move alternates after every ply, which made the board
  /// flip back and forth (twice per move pair) during play.
  bool _boardFlipped = false;

  @override
  void initState() {
    super.initState();
    _chapters = LessonService.instance.getChaptersForCategory(widget.categoryId);
    _currentIndex = widget.initialChapterIndex.clamp(0, _chapters.isEmpty ? 0 : _chapters.length - 1);
    _loadCurrentChapter();
  }

  void _loadCurrentChapter() {
    if (_chapters.isEmpty) return;
    final chapter = _chapters[_currentIndex];

    _board = chess.Chess.fromFEN(chapter.fen);
    // Pin orientation to the player's color (side to move at chapter start).
    _boardFlipped = chapter.fen.split(' ').length > 1
        ? chapter.fen.split(' ')[1] == 'b'
        : false;
    _moveStep = 0;
    _isCompleted = LessonService.instance.isChapterCompleted(chapter.id);
    _isOpponentMoving = false;
    _feedbackMessage = null;
    _selectedSquare = null;
    _legalMoves = [];
    _lastMoveFrom = null;
    _lastMoveTo = null;
    _hintsShown = 0;
    _showHintArrow = false;
    _phase = chapter.hasConcept && !_isCompleted ? 0 : 1;
    _quizPicked = null;
    _quizCorrect = false;
  }

  LessonChapter get _currentChapter => _chapters[_currentIndex];

  bool get _isFlipped => _boardFlipped;

  String? get _activeArrow {
    if (_showHintArrow && _moveStep < _currentChapter.solutionMoves.length) {
      final uci = _normalizeToUci(_currentChapter.solutionMoves[_moveStep]);
      if (uci != null && uci.length >= 4) {
        return uci;
      }
    }
    if (_currentChapter.shapes.isNotEmpty && _moveStep == 0) {
      final shape = _currentChapter.shapes.first;
      if (shape.length >= 4) return shape;
    }
    return null;
  }

  String? _normalizeToUci(String moveStr) {
    if (moveStr.length >= 4 && RegExp(r'^[a-h][1-8][a-h][1-8]').hasMatch(moveStr)) {
      return moveStr.substring(0, 4);
    }
    // Attempt SAN lookup from legal moves
    for (final m in _board.generate_moves()) {
      if (_board.move_to_san(m).replaceAll('+', '').replaceAll('#', '') ==
          moveStr.replaceAll('+', '').replaceAll('#', '')) {
        return '${m.fromAlgebraic}${m.toAlgebraic}';
      }
    }
    return null;
  }

  bool get _isWalkthrough => _currentChapter.type == 'walkthrough';

  void _onSquareTap(String square) {
    if (_isCompleted || _isOpponentMoving || _phase != 1 || _isWalkthrough) {
      return;
    }

    final piece = _board.get(square);
    final isCurrentTurnPiece = piece != null && piece.color == _board.turn;

    if (_selectedSquare != null) {
      // Trying to make a move
      if (_legalMoves.contains(square)) {
        _handlePlayerMove(_selectedSquare!, square);
        return;
      }
    }

    if (isCurrentTurnPiece) {
      setState(() {
        _selectedSquare = square;
        _legalMoves = _board
            .moves({'square': square, 'verbose': true})
            .map((m) => m['to'] as String)
            .toList();
      });
    } else {
      setState(() {
        _selectedSquare = null;
        _legalMoves = [];
      });
    }
  }

  void _onMove(String from, String to) {
    if (_isCompleted || _isOpponentMoving || _phase != 1 || _isWalkthrough) {
      return;
    }
    _handlePlayerMove(from, to);
  }

  /// Walkthrough (opening) stepping: play the next scripted move with narration.
  void _playNextWalkthroughStep() {
    final chapter = _currentChapter;
    if (_moveStep >= chapter.solutionMoves.length || _isOpponentMoving) return;
    final uci = _normalizeToUci(chapter.solutionMoves[_moveStep]);
    if (uci == null || uci.length < 4) return;
    try {
      _board.move({'from': uci.substring(0, 2), 'to': uci.substring(2, 4)});
    } catch (_) {
      return;
    }
    AudioService.instance.playMove();
    setState(() {
      _lastMoveFrom = uci.substring(0, 2);
      _lastMoveTo = uci.substring(2, 4);
      _moveStep++;
      _feedbackMessage = chapter.narrationForMoveStep(_moveStep - 1);
      if (_feedbackMessage!.isEmpty) _feedbackMessage = null;
      _feedbackColor = _successGreen;
    });
    if (_moveStep >= chapter.solutionMoves.length) {
      _onSolved();
    }
  }

  void _handlePlayerMove(String from, String to) {
    final expectedMove = _currentChapter.solutionMoves[_moveStep];
    final playedUci = '$from$to'.toLowerCase();

    // Check if move is legal on the board
    final legalMoves = _board.moves({'square': from, 'verbose': true});
    final matchMove = legalMoves.firstWhere(
      (m) => m['from'] == from && m['to'] == to,
      orElse: () => null,
    );

    if (matchMove == null) {
      setState(() {
        _selectedSquare = null;
        _legalMoves = [];
      });
      return;
    }

    final playedSan = matchMove['san'] as String? ?? '';
    final isCorrect = _isExpectedMove(from, to, playedSan, expectedMove);

    if (isCorrect) {
      // Execute player move
      _board.move({'from': from, 'to': to});
      AudioService.instance.playMove();

      final narration = _currentChapter.narrationForMoveStep(_moveStep);
      setState(() {
        _lastMoveFrom = from;
        _lastMoveTo = to;
        _selectedSquare = null;
        _legalMoves = [];
        _moveStep++;
        _showHintArrow = false;
        _feedbackMessage =
            narration.isNotEmpty ? narration : 'Excellent move!';
        _feedbackColor = _successGreen;
      });

      // Check if finished or opponent responds
      if (_moveStep >= _currentChapter.solutionMoves.length) {
        _onSolved();
      } else {
        _playOpponentResponse();
      }
    } else {
      // Incorrect move — teach, don't just reject.
      AudioService.instance.playCheck();
      final teaching = _currentChapter.mistakeText;
      setState(() {
        _selectedSquare = null;
        _legalMoves = [];
        _feedbackMessage =
            teaching.isNotEmpty ? teaching : 'Incorrect move. Try again!';
        _feedbackColor = _lossRed;
      });

      Future.delayed(const Duration(milliseconds: 1200), () {
        if (mounted) {
          setState(() {
            _feedbackMessage = null;
          });
        }
      });
    }
  }

  bool _isExpectedMove(String from, String to, String playedSan, String expected) {
    final uci = '$from$to'.toLowerCase();
    final expUci = expected.toLowerCase().replaceAll('+', '').replaceAll('#', '');

    if (uci == expUci || uci.startsWith(expUci)) return true;

    final normSan = playedSan.replaceAll('+', '').replaceAll('#', '').replaceAll('x', '');
    final normExp = expected.replaceAll('+', '').replaceAll('#', '').replaceAll('x', '');
    return normSan == normExp;
  }

  void _playOpponentResponse() {
    setState(() => _isOpponentMoving = true);

    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;

      final oppMoveStr = _currentChapter.solutionMoves[_moveStep];
      final uci = _normalizeToUci(oppMoveStr);

      if (uci != null && uci.length >= 4) {
        final from = uci.substring(0, 2);
        final to = uci.substring(2, 4);
        _board.move({'from': from, 'to': to});
        AudioService.instance.playMove();

        setState(() {
          _lastMoveFrom = from;
          _lastMoveTo = to;
          _moveStep++;
          _isOpponentMoving = false;
          _feedbackMessage = null;
        });

        if (_moveStep >= _currentChapter.solutionMoves.length) {
          _onSolved();
        }
      } else {
        setState(() => _isOpponentMoving = false);
      }
    });
  }

  void _onSolved() {
    AudioService.instance.playGameEnd();
    // v2 quiz gate: position solved → answer the check question first.
    if (_currentChapter.hasQuiz && !_quizCorrect && !_isCompleted) {
      setState(() {
        _phase = 2;
        _feedbackMessage = 'Position solved! One quick check…';
        _feedbackColor = _successGreen;
      });
      return;
    }
    _completeChapter();
  }

  void _answerQuiz(int picked) {
    final chapter = _currentChapter;
    setState(() {
      _quizPicked = picked;
      _quizCorrect = picked == chapter.quizAnswer;
      if (_quizCorrect) {
        _feedbackMessage = 'Correct! Lesson complete.';
        _feedbackColor = _successGreen;
      } else {
        _feedbackMessage =
            'Not quite — the concept above holds the answer. Try again.';
        _feedbackColor = _lossRed;
      }
    });
    if (_quizCorrect) {
      Future.delayed(const Duration(milliseconds: 600), () {
        if (!mounted) return;
        _completeChapter();
      });
    }
  }

  void _completeChapter() {
    LessonService.instance.markChapterCompleted(_currentChapter.id);

    // Study achievement unlocks.
    try {
      ref.read(achievementProvider.notifier).checkStudyProgress(
            gamesAnalysed:
                ref.read(statisticsProvider).gamesAnalysed,
            lessonsCompleted:
                LessonService.instance.completedChaptersCount,
            openingsPlayed:
                ref.read(statisticsProvider).openingsPlayed.keys.length,
          );
    } catch (_) {}

    setState(() {
      _isCompleted = true;
      _feedbackMessage = 'Lesson Completed!';
      _feedbackColor = _successGreen;
    });
  }

  void _showHint() {
    if (_currentChapter.hints.isEmpty) return;
    setState(() {
      _hintsShown = (_hintsShown + 1).clamp(1, _currentChapter.hints.length);
      _showHintArrow = true;
    });
  }

  void _resetChapter() {
    setState(() {
      _loadCurrentChapter();
    });
  }

  void _goToChapter(int index) {
    if (index >= 0 && index < _chapters.length) {
      setState(() {
        _currentIndex = index;
        _loadCurrentChapter();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_chapters.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Lesson')),
        body: const Center(child: Text('No chapters available for this category.')),
      );
    }

    final chapter = _currentChapter;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              chapter.title,
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            Text(
              'Exercise ${_currentIndex + 1} of ${_chapters.length}',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppTheme.textHintFor(context),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Reset Position',
            onPressed: _resetChapter,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Instruction Card
              AppCard(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _accentGold.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.lightbulb_rounded,
                        color: _accentGold,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        chapter.instruction,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimaryFor(context),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // v2 Concept intro (phase 0)
              if (_phase == 0 && chapter.hasConcept) ...[
                const SizedBox(height: 12),
                AppCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.school_rounded,
                            size: 18,
                            color: _accentGold,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'The Idea',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: _accentGold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        chapter.concept,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          height: 1.5,
                          color: AppTheme.textPrimaryFor(context),
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.play_arrow_rounded, size: 18),
                          label: Text(
                            'Start Practicing',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _accentGold,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed:
                              () => setState(() {
                                _phase = 1;
                                _feedbackMessage = null;
                              }),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // v2 Quiz gate (phase 2)
              if (_phase == 2 && chapter.hasQuiz) ...[
                const SizedBox(height: 12),
                AppCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.quiz_rounded,
                            size: 18,
                            color: _accentGold,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Quick Check',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: _accentGold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        chapter.quizQuestion,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimaryFor(context),
                        ),
                      ),
                      const SizedBox(height: 10),
                      ...List.generate(chapter.quizOptions.length, (i) {
                        final picked = _quizPicked == i;
                        final isAnswer =
                            _quizCorrect && i == chapter.quizAnswer;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              backgroundColor:
                                  isAnswer
                                      ? _successGreen.withValues(alpha: 0.15)
                                      : picked
                                      ? _lossRed.withValues(alpha: 0.12)
                                      : null,
                              side: BorderSide(
                                color:
                                    isAnswer
                                        ? _successGreen
                                        : picked
                                        ? _lossRed
                                        : AppTheme.borderColorFor(context),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed:
                                _quizCorrect ? null : () => _answerQuiz(i),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                chapter.quizOptions[i],
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: AppTheme.textPrimaryFor(context),
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ],

              if (_feedbackMessage != null) ...[
                const SizedBox(height: 8),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: _feedbackColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _feedbackColor.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _isCompleted ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                        color: _feedbackColor,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _feedbackMessage!,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _feedbackColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 12),

              // 2. Interactive Chess Board
              ThemedBoardContainer(
                child: ChessBoard(
                  fen: _board.fen,
                  isFlipped: _isFlipped,
                  selectedSquare: _selectedSquare,
                  legalMoves: _legalMoves,
                  lastMoveFrom: _lastMoveFrom,
                  lastMoveTo: _lastMoveTo,
                  bestMove: _activeArrow,
                  showHint: _showHintArrow,
                  onSquareTap: _onSquareTap,
                  onMove: _onMove,
                  showCoordinates: true,
                ),
              ),

              const SizedBox(height: 12),

              // 3. Hints & Explanation Card
              if (_hintsShown > 0)
                AppCard(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.help_outline_rounded, size: 16, color: _accentGold),
                          const SizedBox(width: 6),
                          Text(
                            'Hint ($_hintsShown/${chapter.hints.length})',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: _accentGold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        chapter.hints[_hintsShown - 1],
                        style: GoogleFonts.inter(fontSize: 13),
                      ),
                    ],
                  ),
                ),

              // Walkthrough stepping (openings)
              if (_isWalkthrough && _phase == 1 && !_isCompleted) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.skip_next_rounded, size: 18),
                    label: Text(
                      _moveStep == 0
                          ? 'Play First Move'
                          : 'Next Move (${_moveStep + 1}/${chapter.solutionMoves.length})',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _accentGold,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: _playNextWalkthroughStep,
                  ),
                ),
              ],

              if (_isCompleted) ...[
                const SizedBox(height: 12),
                AppCard(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.verified_rounded, size: 18, color: _successGreen),
                          const SizedBox(width: 8),
                          Text(
                            'Key Tactical Principle',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: _successGreen,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        chapter.explanation,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          height: 1.4,
                          color: AppTheme.textPrimaryFor(context),
                        ),
                      ),
                      if (chapter.takeaway.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: _successGreen.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.format_quote_rounded,
                                size: 16,
                                color: _successGreen,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Remember: ${chapter.takeaway}',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    fontStyle: FontStyle.italic,
                                    color: AppTheme.textPrimaryFor(context),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // 4. Action Buttons & Navigation Toolbar
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.lightbulb_outline_rounded, size: 18),
                      label: Text(
                        _hintsShown > 0 ? 'Next Hint' : 'Get Hint',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _hintsShown < chapter.hints.length ? _showHint : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: Icon(
                        _isCompleted ? Icons.arrow_forward_rounded : Icons.replay_rounded,
                        size: 18,
                      ),
                      label: Text(
                        _isCompleted
                            ? (_currentIndex < _chapters.length - 1 ? 'Next Lesson' : 'Completed!')
                            : 'Reset',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isCompleted ? _accentGold : AppTheme.cardColor(context),
                        foregroundColor: _isCompleted ? Colors.black : AppTheme.textPrimaryFor(context),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () {
                        if (_isCompleted) {
                          if (_currentIndex < _chapters.length - 1) {
                            _goToChapter(_currentIndex + 1);
                          } else {
                            Navigator.of(context).pop();
                          }
                        } else {
                          _resetChapter();
                        }
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Step indicator scrubber
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_chapters.length, (idx) {
                  final isCurrent = idx == _currentIndex;
                  final isDone = LessonService.instance.isChapterCompleted(_chapters[idx].id);

                  return GestureDetector(
                    onTap: () => _goToChapter(idx),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                      width: isCurrent ? 24 : 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: isCurrent
                            ? _accentGold
                            : (isDone ? _successGreen : Colors.grey.withValues(alpha: 0.3)),
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
