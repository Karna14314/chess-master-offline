import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chess/chess.dart' as chess;
import 'package:chess_master/core/theme/board_themes.dart';
import 'package:chess_master/providers/game_provider.dart';
import 'package:chess_master/providers/settings_provider.dart';
import 'package:chess_master/screens/game/widgets/chess_piece.dart';

/// Main chess board widget with interactive piece movement
/// Supports both internal game provider state and external state via props
class ChessBoard extends ConsumerStatefulWidget {
  // Mode: Use internal provider state vs external state
  final bool useExternalState;

  // External state properties (used when useExternalState is true)
  final String? fen;
  final bool isFlipped;
  final String? selectedSquare;
  final List<String>? legalMoves;
  final String? lastMoveFrom;
  final String? lastMoveTo;
  final String? bestMove; // UCI format for arrow
  final bool showHint;
  final String? hintSquare;
  final void Function(String square)? onSquareTap;
  final void Function(String from, String to)? onMove;
  final bool showCoordinates;

  // Legacy props for internal mode
  final bool interactive;
  final bool flipped;
  final VoidCallback? onMoveCallback;

  // External mode constructor
  const ChessBoard({
    super.key,
    required this.fen,
    this.isFlipped = false,
    this.selectedSquare,
    this.legalMoves,
    this.lastMoveFrom,
    this.lastMoveTo,
    this.bestMove,
    this.showHint = false,
    this.hintSquare,
    this.onSquareTap,
    this.onMove,
    this.showCoordinates = true,
  }) : useExternalState = true,
       interactive = true,
       flipped = false,
       onMoveCallback = null;

  // Internal mode constructor (uses game provider)
  const ChessBoard.internal({
    super.key,
    this.interactive = true,
    this.flipped = false,
    this.onMoveCallback,
  }) : useExternalState = false,
       fen = null,
       isFlipped = false,
       selectedSquare = null,
       legalMoves = null,
       lastMoveFrom = null,
       lastMoveTo = null,
       bestMove = null,
       showHint = false,
       hintSquare = null,
       onSquareTap = null,
       onMove = null,
       showCoordinates = true;

  @override
  ConsumerState<ChessBoard> createState() => _ChessBoardState();
}

class _ChessBoardState extends ConsumerState<ChessBoard> {
  // Use ValueNotifier for drag state to avoid full rebuilds
  final ValueNotifier<String?> _draggedFrom = ValueNotifier(null);
  final ValueNotifier<Offset?> _dragPosition = ValueNotifier(null);
  final ValueNotifier<String?> _draggedPiece = ValueNotifier(null);
  chess.Chess? _externalBoard;

  @override
  void initState() {
    super.initState();
    _updateExternalBoard();
  }

  @override
  void dispose() {
    _draggedFrom.dispose();
    _dragPosition.dispose();
    _draggedPiece.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(ChessBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.fen != oldWidget.fen) {
      _updateExternalBoard();
    }
  }

  void _updateExternalBoard() {
    if (widget.useExternalState && widget.fen != null) {
      try {
        _externalBoard = chess.Chess.fromFEN(widget.fen!);
      } catch (e) {
        _externalBoard = chess.Chess();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final theme = settings.currentBoardTheme;

    // Determine state based on mode
    final bool effectiveFlipped;
    final String? effectiveSelectedSquare;
    final List<String> effectiveLegalMoves;
    final String? effectiveLastMoveFrom;
    final String? effectiveLastMoveTo;
    final bool effectiveShowCoordinates;
    final bool effectiveInCheck;
    final String? effectiveKingSquare;

    if (widget.useExternalState) {
      effectiveFlipped = widget.isFlipped ^ settings.boardFlipped;
      effectiveSelectedSquare = widget.selectedSquare;
      effectiveLegalMoves =
          settings.showLegalMoves ? (widget.legalMoves ?? []) : [];
      effectiveLastMoveFrom =
          settings.showLastMove ? widget.lastMoveFrom : null;
      effectiveLastMoveTo = settings.showLastMove ? widget.lastMoveTo : null;
      effectiveShowCoordinates = widget.showCoordinates;
      effectiveInCheck = _externalBoard?.in_check ?? false;
      effectiveKingSquare = _findKingSquareExternal();
    } else {
      final gameState = ref.watch(gameProvider);
      effectiveFlipped = widget.flipped ^ settings.boardFlipped;
      effectiveSelectedSquare = gameState.selectedSquare;
      effectiveLegalMoves = settings.showLegalMoves ? gameState.legalMoves : [];
      effectiveLastMoveFrom =
          settings.showLastMove ? gameState.lastMoveFrom : null;
      effectiveLastMoveTo = settings.showLastMove ? gameState.lastMoveTo : null;
      effectiveShowCoordinates = settings.showCoordinates;
      effectiveInCheck = gameState.inCheck;
      effectiveKingSquare = _findKingSquareInternal(gameState.isWhiteTurn);
    }

    final hintMove =
        widget.useExternalState ? null : ref.watch(gameProvider).hint;

    final isInteractive =
        widget.useExternalState
            ? (widget.onSquareTap != null || widget.onMove != null)
            : widget.interactive;

    return AspectRatio(
      aspectRatio: 1,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final boardSize = constraints.maxWidth;
          final squareSize = boardSize / 8;

          return GestureDetector(
            onPanStart:
                isInteractive
                    ? (details) =>
                        _onDragStart(details, squareSize, effectiveFlipped)
                    : null,
            onPanUpdate:
                isInteractive ? (details) => _onDragUpdate(details) : null,
            onPanEnd:
                isInteractive
                    ? (details) =>
                        _onDragEnd(squareSize, effectiveFlipped)
                    : null,
            onTapUp:
                isInteractive
                    ? (details) =>
                        _onTap(details, squareSize, effectiveFlipped)
                    : null,
            child: Stack(
              children: [
                // RepaintBoundary for the static parts of the board
                RepaintBoundary(
                  child: Stack(
                    children: [
                      // Board squares
                      CustomPaint(
                        size: Size(boardSize, boardSize),
                        painter: BoardPainter(
                          theme: theme,
                          selectedSquare: effectiveSelectedSquare,
                          lastMoveFrom: effectiveLastMoveFrom,
                          lastMoveTo: effectiveLastMoveTo,
                          legalMoves: effectiveLegalMoves,
                          inCheck: effectiveInCheck,
                          kingSquare: effectiveKingSquare,
                          isFlipped: effectiveFlipped,
                          showCoordinates: effectiveShowCoordinates,
                          bestMove: widget.bestMove,
                          showHint: hintMove != null,
                          hintSquare: hintMove?.from,
                          getPieceAt: _getPieceAt,
                        ),
                      ),
                      // Hint arrow
                      if (hintMove != null)
                        CustomPaint(
                          size: Size(boardSize, boardSize),
                          painter: _ArrowPainter(
                            from: hintMove.from,
                            to: hintMove.to,
                            color: Colors.blue.withOpacity(0.7),
                            squareSize: squareSize,
                            isFlipped: effectiveFlipped,
                          ),
                        ),
                      // Static Pieces (rebuilds only when drag starts/ends)
                      ValueListenableBuilder<String?>(
                        valueListenable: _draggedFrom,
                        builder: (context, draggedFromSquare, child) {
                          return Stack(
                            children: List.generate(64, (index) {
                              final file = index % 8;
                              final rank = index ~/ 8;
                              final square = _getSquare(
                                file,
                                rank,
                                effectiveFlipped,
                              );
                              final piece = _getPieceAt(square);

                              // Don't render the piece being dragged at its original position
                              if (piece == null || square == draggedFromSquare) {
                                return const SizedBox.shrink();
                              }

                              final x = file * squareSize;
                              final y = rank * squareSize;

                              return Positioned(
                                left: x,
                                top: y,
                                width: squareSize,
                                height: squareSize,
                                child: ChessPiece(
                                  piece: piece,
                                  size: squareSize,
                                  pieceSet: settings.currentPieceSet,
                                ),
                              );
                            }),
                          );
                        },
                      ),
                      // Best move arrow
                      if (widget.bestMove != null &&
                          widget.bestMove!.length >= 4)
                        CustomPaint(
                          size: Size(boardSize, boardSize),
                          painter: _ArrowPainter(
                            from: widget.bestMove!.substring(0, 2),
                            to: widget.bestMove!.substring(2, 4),
                            color: Colors.green.withOpacity(0.7),
                            squareSize: squareSize,
                            isFlipped: effectiveFlipped,
                          ),
                        ),
                    ],
                  ),
                ),

                // Dragged piece layer (rebuilds every frame during drag)
                ValueListenableBuilder<Offset?>(
                  valueListenable: _dragPosition,
                  builder: (context, dragPos, child) {
                    final piece = _draggedPiece.value;
                    if (piece == null || dragPos == null) {
                      return const SizedBox.shrink();
                    }

                    return Positioned(
                      left: dragPos.dx - squareSize / 2,
                      top: dragPos.dy - squareSize / 2,
                      width: squareSize * 1.2,
                      height: squareSize * 1.2,
                      child: ChessPiece(
                        piece: piece,
                        size: squareSize * 1.2,
                        pieceSet: settings.currentPieceSet,
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String? _getPieceAt(String square) {
    if (widget.useExternalState) {
      if (_externalBoard == null) return null;
      final piece = _externalBoard!.get(square);
      if (piece == null) return null;
      final colorPrefix = piece.color == chess.Color.WHITE ? 'w' : 'b';
      final pieceChar = piece.type.name.toUpperCase();
      return '$colorPrefix$pieceChar';
    } else {
      return ref.read(gameProvider.notifier).getPieceAt(square);
    }
  }

  String _getSquare(int file, int rank, bool isFlipped) {
    if (isFlipped) {
      file = 7 - file;
      rank = 7 - rank;
    }
    final fileChar = String.fromCharCode('a'.codeUnitAt(0) + file);
    final rankChar = (8 - rank).toString();
    return '$fileChar$rankChar';
  }

  String? _findKingSquareInternal(bool isWhite) {
    for (int file = 0; file < 8; file++) {
      for (int rank = 0; rank < 8; rank++) {
        final square =
            '${String.fromCharCode('a'.codeUnitAt(0) + file)}${8 - rank}';
        final piece = ref.read(gameProvider.notifier).getPieceAt(square);
        if (piece == (isWhite ? 'wK' : 'bK')) {
          return square;
        }
      }
    }
    return null;
  }

  String? _findKingSquareExternal() {
    if (_externalBoard == null) return null;
    final isWhite = _externalBoard!.turn == chess.Color.WHITE;
    for (int file = 0; file < 8; file++) {
      for (int rank = 0; rank < 8; rank++) {
        final square =
            '${String.fromCharCode('a'.codeUnitAt(0) + file)}${8 - rank}';
        final piece = _externalBoard!.get(square);
        if (piece != null &&
            piece.type == chess.PieceType.KING &&
            piece.color == (isWhite ? chess.Color.WHITE : chess.Color.BLACK)) {
          return square;
        }
      }
    }
    return null;
  }

  void _onTap(TapUpDetails details, double squareSize, bool isFlipped) {
    final file = (details.localPosition.dx / squareSize).floor();
    final rank = (details.localPosition.dy / squareSize).floor();
    final square = _getSquare(file, rank, isFlipped);

    if (widget.useExternalState) {
      widget.onSquareTap?.call(square);
    } else {
      final moved = ref.read(gameProvider.notifier).selectSquare(square);
      if (moved) {
        widget.onMoveCallback?.call();
      }
    }
  }

  void _onDragStart(
    DragStartDetails details,
    double squareSize,
    bool isFlipped,
  ) {
    final file = (details.localPosition.dx / squareSize).floor();
    final rank = (details.localPosition.dy / squareSize).floor();
    final square = _getSquare(file, rank, isFlipped);
    final piece = _getPieceAt(square);

    if (piece != null) {
      // Update Notifiers instead of setState
      _draggedFrom.value = square;
      _dragPosition.value = details.localPosition;
      _draggedPiece.value = piece;

      if (widget.useExternalState) {
        widget.onSquareTap?.call(square);
      } else {
        ref.read(gameProvider.notifier).selectSquare(square);
      }
    }
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (_draggedFrom.value != null) {
      // Update Notifier instead of setState
      _dragPosition.value = details.localPosition;
    }
  }

  void _onDragEnd(double squareSize, bool isFlipped) {
    final fromSquare = _draggedFrom.value;
    final dragPos = _dragPosition.value;

    if (fromSquare != null && dragPos != null) {
      final file = (dragPos.dx / squareSize).floor().clamp(0, 7);
      final rank = (dragPos.dy / squareSize).floor().clamp(0, 7);
      final targetSquare = _getSquare(file, rank, isFlipped);

      if (targetSquare != fromSquare) {
        if (widget.useExternalState) {
          widget.onMove?.call(fromSquare, targetSquare);
        } else {
          final success = ref
              .read(gameProvider.notifier)
              .tryMove(fromSquare, targetSquare);
          if (success) {
            widget.onMoveCallback?.call();
          }
        }
      }
    }

    // Reset Notifiers
    _draggedFrom.value = null;
    _dragPosition.value = null;
    _draggedPiece.value = null;
  }
}

/// Custom painter for drawing the chess board
class BoardPainter extends CustomPainter {
  final BoardTheme theme;
  final String? selectedSquare;
  final String? lastMoveFrom;
  final String? lastMoveTo;
  final List<String> legalMoves;
  final bool inCheck;
  final String? kingSquare;
  final bool isFlipped;
  final bool showCoordinates;
  final String? bestMove;
  final bool showHint;
  final String? hintSquare;
  final String? Function(String) getPieceAt;

  // Optimized paints
  final Paint _squarePaint = Paint();
  late final Paint _legalMoveDotPaint;
  late final Paint _legalMoveRingPaint;

  BoardPainter({
    required this.theme,
    this.selectedSquare,
    this.lastMoveFrom,
    this.lastMoveTo,
    this.legalMoves = const [],
    this.inCheck = false,
    this.kingSquare,
    this.isFlipped = false,
    this.showCoordinates = true,
    this.bestMove,
    this.showHint = false,
    this.hintSquare,
    required this.getPieceAt,
  }) {
    _legalMoveDotPaint = Paint()..color = theme.legalMoveDot;
    _legalMoveRingPaint = Paint()
      ..color = theme.legalMoveCapture
      ..style = PaintingStyle.stroke;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final squareSize = size.width / 8;
    // Update stroke width based on current size
    _legalMoveRingPaint.strokeWidth = squareSize * 0.08;

    for (int rank = 0; rank < 8; rank++) {
      for (int file = 0; file < 8; file++) {
        final isLight = (rank + file) % 2 == 0;
        final square = _getSquare(file, rank);
        final rect = Rect.fromLTWH(
          file * squareSize,
          rank * squareSize,
          squareSize,
          squareSize,
        );

        // Base square color
        Color color = isLight ? theme.lightSquare : theme.darkSquare;

        // Last move highlight
        if (square == lastMoveFrom || square == lastMoveTo) {
          color =
              isLight ? theme.lastMoveLightSquare : theme.lastMoveDarkSquare;
        }

        // Selected square highlight
        if (square == selectedSquare) {
          color =
              isLight ? theme.lightSquareHighlight : theme.darkSquareHighlight;
        }

        // Hint highlight
        if (showHint && square == hintSquare) {
          color = Colors.green.withOpacity(0.5);
        }

        // Check highlight
        if (inCheck && square == kingSquare) {
          color = theme.checkHighlight;
        }

        _squarePaint.color = color;
        canvas.drawRect(rect, _squarePaint);

        // Legal move indicators
        if (legalMoves.contains(square)) {
          final piece = getPieceAt(square);
          final isCapture = piece != null;
          final center = rect.center;

          if (isCapture) {
            // Capture indicator - ring
            canvas.drawCircle(center, squareSize * 0.4, _legalMoveRingPaint);
          } else {
            // Move indicator - dot
            canvas.drawCircle(center, squareSize * 0.15, _legalMoveDotPaint);
          }
        }

        // Draw coordinates
        if (showCoordinates) {
          _drawCoordinates(canvas, file, rank, squareSize, isLight);
        }
      }
    }
  }

  String _getSquare(int file, int rank) {
    if (isFlipped) {
      file = 7 - file;
      rank = 7 - rank;
    }
    final fileChar = String.fromCharCode('a'.codeUnitAt(0) + file);
    final rankChar = (8 - rank).toString();
    return '$fileChar$rankChar';
  }

  void _drawCoordinates(
    Canvas canvas,
    int file,
    int rank,
    double squareSize,
    bool isLight,
  ) {
    final textStyle = TextStyle(
      color: isLight ? theme.coordinateLight : theme.coordinateDark,
      fontSize: squareSize * 0.15,
      fontWeight: FontWeight.bold,
    );

    // Draw file letters on bottom row
    if ((isFlipped ? rank == 0 : rank == 7)) {
      final fileLabel =
          isFlipped
              ? String.fromCharCode('h'.codeUnitAt(0) - file)
              : String.fromCharCode('a'.codeUnitAt(0) + file);
      final textSpan = TextSpan(text: fileLabel, style: textStyle);
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();

      textPainter.paint(
        canvas,
        Offset(
          file * squareSize + squareSize - textPainter.width - 2,
          rank * squareSize + squareSize - textPainter.height - 2,
        ),
      );
    }

    // Draw rank numbers on left column
    if (file == 0) {
      final rankLabel =
          isFlipped ? (rank + 1).toString() : (8 - rank).toString();
      final textSpan = TextSpan(text: rankLabel, style: textStyle);
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();

      textPainter.paint(canvas, Offset(2, rank * squareSize + 2));
    }
  }

  @override
  bool shouldRepaint(covariant BoardPainter oldDelegate) {
    return selectedSquare != oldDelegate.selectedSquare ||
        lastMoveFrom != oldDelegate.lastMoveFrom ||
        lastMoveTo != oldDelegate.lastMoveTo ||
        legalMoves != oldDelegate.legalMoves ||
        inCheck != oldDelegate.inCheck ||
        kingSquare != oldDelegate.kingSquare ||
        isFlipped != oldDelegate.isFlipped ||
        theme != oldDelegate.theme ||
        showCoordinates != oldDelegate.showCoordinates ||
        bestMove != oldDelegate.bestMove ||
        showHint != oldDelegate.showHint ||
        hintSquare != oldDelegate.hintSquare;
  }
}

/// Arrow painter for showing best move
class _ArrowPainter extends CustomPainter {
  final String from;
  final String to;
  final Color color;
  final double squareSize;
  final bool isFlipped;

  _ArrowPainter({
    required this.from,
    required this.to,
    required this.color,
    required this.squareSize,
    required this.isFlipped,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final fromPos = _squareToPosition(from);
    final toPos = _squareToPosition(to);

    if (fromPos == null || toPos == null) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = squareSize * 0.15
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Draw line
    canvas.drawLine(fromPos, toPos, paint);

    // Draw arrowhead
    final arrowPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final angle = (toPos - fromPos).direction;
    final arrowSize = squareSize * 0.3;

    final path = Path();
    path.moveTo(toPos.dx, toPos.dy);
    path.lineTo(
      toPos.dx -
          arrowSize *
              1.5 *
              (toPos - fromPos).dx /
              (toPos - fromPos).distance +
          arrowSize *
              0.5 *
              (toPos - fromPos).dy /
              (toPos - fromPos).distance,
      toPos.dy -
          arrowSize *
              1.5 *
              (toPos - fromPos).dy /
              (toPos - fromPos).distance -
          arrowSize *
              0.5 *
              (toPos - fromPos).dx /
              (toPos - fromPos).distance,
    );
    path.lineTo(
      toPos.dx -
          arrowSize *
              1.5 *
              (toPos - fromPos).dx /
              (toPos - fromPos).distance -
          arrowSize *
              0.5 *
              (toPos - fromPos).dy /
              (toPos - fromPos).distance,
      toPos.dy -
          arrowSize *
              1.5 *
              (toPos - fromPos).dy /
              (toPos - fromPos).distance +
          arrowSize *
              0.5 *
              (toPos - fromPos).dx /
              (toPos - fromPos).distance,
    );
    path.close();

    canvas.drawPath(path, arrowPaint);
  }

  Offset? _squareToPosition(String square) {
    if (square.length != 2) return null;

    int file = square.codeUnitAt(0) - 'a'.codeUnitAt(0);
    int rank = 8 - int.parse(square[1]);

    if (isFlipped) {
      file = 7 - file;
      rank = 7 - rank;
    }

    return Offset((file + 0.5) * squareSize, (rank + 0.5) * squareSize);
  }

  @override
  bool shouldRepaint(covariant _ArrowPainter oldDelegate) {
    return from != oldDelegate.from ||
        to != oldDelegate.to ||
        color != oldDelegate.color ||
        squareSize != oldDelegate.squareSize ||
        isFlipped != oldDelegate.isFlipped;
  }
}
