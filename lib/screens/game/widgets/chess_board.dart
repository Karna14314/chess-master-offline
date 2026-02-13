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
  // Drag state managed via ValueNotifier to avoid full rebuilds
  final ValueNotifier<_DragState> _dragState = ValueNotifier(_DragState.empty());
  chess.Chess? _externalBoard;

  @override
  void initState() {
    super.initState();
    _updateExternalBoard();
  }

  @override
  void didUpdateWidget(ChessBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.fen != oldWidget.fen) {
      _updateExternalBoard();
    }
  }

  @override
  void dispose() {
    _dragState.dispose();
    super.dispose();
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
      effectiveLegalMoves = settings.showLegalMoves ? (widget.legalMoves ?? []) : [];
      effectiveLastMoveFrom = settings.showLastMove ? widget.lastMoveFrom : null;
      effectiveLastMoveTo = settings.showLastMove ? widget.lastMoveTo : null;
      effectiveShowCoordinates = widget.showCoordinates;
      effectiveInCheck = _externalBoard?.in_check ?? false;
      effectiveKingSquare = _findKingSquareExternal();
    } else {
      final gameState = ref.watch(gameProvider);
      effectiveFlipped = widget.flipped ^ settings.boardFlipped;
      effectiveSelectedSquare = gameState.selectedSquare;
      effectiveLegalMoves = settings.showLegalMoves ? gameState.legalMoves : [];
      effectiveLastMoveFrom = settings.showLastMove ? gameState.lastMoveFrom : null;
      effectiveLastMoveTo = settings.showLastMove ? gameState.lastMoveTo : null;
      effectiveShowCoordinates = settings.showCoordinates;
      effectiveInCheck = gameState.inCheck;
      effectiveKingSquare = _findKingSquareInternal(gameState.isWhiteTurn);
    }

    final hintMove = widget.useExternalState ? null : ref.watch(gameProvider).hint;

    final isInteractive = widget.useExternalState 
        ? (widget.onSquareTap != null || widget.onMove != null)
        : widget.interactive;

    return AspectRatio(
      aspectRatio: 1,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final boardSize = constraints.maxWidth;
          final squareSize = boardSize / 8;

          return GestureDetector(
            onPanStart: isInteractive ? (details) => _onDragStart(details, squareSize, effectiveFlipped) : null,
            onPanUpdate: isInteractive ? (details) => _onDragUpdate(details) : null,
            onPanEnd: isInteractive ? (details) => _onDragEnd(squareSize, effectiveFlipped) : null,
            onTapUp: isInteractive ? (details) => _onTap(details, squareSize, effectiveFlipped) : null,
            child: Stack(
              children: [
                // 1. Board squares (background) - RepaintBoundary for performance
                RepaintBoundary(
                  child: CustomPaint(
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
                ),

                // 2. Hint arrow
                if (hintMove != null)
                  RepaintBoundary(
                    child: CustomPaint(
                      size: Size(boardSize, boardSize),
                      painter: _ArrowPainter(
                        from: hintMove.from,
                        to: hintMove.to,
                        color: Colors.blue.withOpacity(0.7),
                        squareSize: squareSize,
                        isFlipped: effectiveFlipped,
                      ),
                    ),
                  ),

                // 3. Pieces Layer
                ValueListenableBuilder<_DragState>(
                  valueListenable: _dragState,
                  builder: (context, dragState, child) {
                    return Stack(
                      children: List.generate(64, (index) {
                        final file = index % 8;
                        final rank = index ~/ 8;
                        final square = _getSquare(file, rank, effectiveFlipped);
                        final piece = _getPieceAt(square);

                        // Don't render the piece being dragged at its original position
                        if (piece == null || square == dragState.fromSquare) return const SizedBox.shrink();

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

                // 4. Best move arrow
                if (widget.bestMove != null && widget.bestMove!.length >= 4)
                  RepaintBoundary(
                    child: CustomPaint(
                      size: Size(boardSize, boardSize),
                      painter: _ArrowPainter(
                        from: widget.bestMove!.substring(0, 2),
                        to: widget.bestMove!.substring(2, 4),
                        color: Colors.green.withOpacity(0.7),
                        squareSize: squareSize,
                        isFlipped: effectiveFlipped,
                      ),
                    ),
                  ),

                // 5. Dragged Piece Layer (Optimized)
                ValueListenableBuilder<_DragState>(
                  valueListenable: _dragState,
                  builder: (context, dragState, child) {
                    if (dragState.piece == null || dragState.position == null) {
                      return const SizedBox.shrink();
                    }

                    return Positioned(
                      left: dragState.position!.dx - squareSize / 2,
                      top: dragState.position!.dy - squareSize / 2,
                      width: squareSize * 1.2,
                      height: squareSize * 1.2,
                      child: ChessPiece(
                        piece: dragState.piece!,
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
        final square = '${String.fromCharCode('a'.codeUnitAt(0) + file)}${8 - rank}';
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
        final square = '${String.fromCharCode('a'.codeUnitAt(0) + file)}${8 - rank}';
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

  void _onDragStart(DragStartDetails details, double squareSize, bool isFlipped) {
    final file = (details.localPosition.dx / squareSize).floor();
    final rank = (details.localPosition.dy / squareSize).floor();
    final square = _getSquare(file, rank, isFlipped);
    final piece = _getPieceAt(square);

    if (piece != null) {
      _dragState.value = _DragState(
        fromSquare: square,
        position: details.localPosition,
        piece: piece,
      );
      
      if (widget.useExternalState) {
        widget.onSquareTap?.call(square);
      } else {
        ref.read(gameProvider.notifier).selectSquare(square);
      }
    }
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (_dragState.value.fromSquare != null) {
      _dragState.value = _dragState.value.copyWith(
        position: details.localPosition,
      );
    }
  }

  void _onDragEnd(double squareSize, bool isFlipped) {
    final state = _dragState.value;
    if (state.fromSquare != null && state.position != null) {
      final file = (state.position!.dx / squareSize).floor().clamp(0, 7);
      final rank = (state.position!.dy / squareSize).floor().clamp(0, 7);
      final targetSquare = _getSquare(file, rank, isFlipped);

      if (targetSquare != state.fromSquare) {
        if (widget.useExternalState) {
          widget.onMove?.call(state.fromSquare!, targetSquare);
        } else {
          final success = ref.read(gameProvider.notifier).tryMove(state.fromSquare!, targetSquare);
          if (success) {
            widget.onMoveCallback?.call();
          }
        }
      }
    }

    _dragState.value = _DragState.empty();
  }
}

class _DragState {
  final String? fromSquare;
  final Offset? position;
  final String? piece;

  const _DragState({this.fromSquare, this.position, this.piece});

  factory _DragState.empty() => const _DragState();

  _DragState copyWith({String? fromSquare, Offset? position, String? piece}) {
    return _DragState(
      fromSquare: fromSquare ?? this.fromSquare,
      position: position ?? this.position,
      piece: piece ?? this.piece,
    );
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
  final Paint _legalMoveDotPaint = Paint();
  final Paint _legalMoveRingPaint = Paint()..style = PaintingStyle.stroke;
  final Paint _highlightPaint = Paint();

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
    _legalMoveDotPaint.color = theme.legalMoveDot;
    _legalMoveRingPaint.color = theme.legalMoveCapture;
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

        // Base square color
        Color color = isLight ? theme.lightSquare : theme.darkSquare;

        // Last move highlight
        if (square == lastMoveFrom || square == lastMoveTo) {
          color = isLight ? theme.lastMoveLightSquare : theme.lastMoveDarkSquare;
        }

        // Selected square highlight
        if (square == selectedSquare) {
          color = isLight ? theme.lightSquareHighlight : theme.darkSquareHighlight;
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
        canvas.drawRect(
          Rect.fromLTWH(
            file * squareSize,
            rank * squareSize,
            squareSize,
            squareSize,
          ),
          _squarePaint,
        );

        // Legal move indicators
        if (legalMoves.contains(square)) {
          final piece = getPieceAt(square);
          final isCapture = piece != null;
          final center = Offset(
            (file + 0.5) * squareSize,
            (rank + 0.5) * squareSize,
          );

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

  void _drawCoordinates(Canvas canvas, int file, int rank, double squareSize, bool isLight) {
    // Only draw on edges
    final isBottomEdge = isFlipped ? rank == 0 : rank == 7;
    final isLeftEdge = file == 0;

    if (!isBottomEdge && !isLeftEdge) return;

    final textStyle = TextStyle(
      color: isLight ? theme.coordinateLight : theme.coordinateDark,
      fontSize: squareSize * 0.15,
      fontWeight: FontWeight.bold,
    );

    // Draw file letters on bottom row
    if (isBottomEdge) {
      final fileLabel = isFlipped
          ? String.fromCharCode('h'.codeUnitAt(0) - file)
          : String.fromCharCode('a'.codeUnitAt(0) + file);

      // We create a new TextPainter here because caching might be premature optimization
      // without proper cache invalidation, but at least we don't recreate the style unnecessarily?
      // Actually, standard optimization is to just paint.
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
    if (isLeftEdge) {
      final rankLabel = isFlipped ? (rank + 1).toString() : (8 - rank).toString();
      final textSpan = TextSpan(text: rankLabel, style: textStyle);
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();

      textPainter.paint(
        canvas,
        Offset(2, rank * squareSize + 2),
      );
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

  // Optimized reusable objects
  final Paint _linePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;
  final Paint _arrowPaint = Paint()
    ..style = PaintingStyle.fill;
  final Path _arrowPath = Path();

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

    _linePaint
      ..color = color
      ..strokeWidth = squareSize * 0.15;

    // Draw line
    canvas.drawLine(fromPos, toPos, _linePaint);

    // Draw arrowhead
    _arrowPaint.color = color;

    final angle = (toPos - fromPos).direction;
    final arrowSize = squareSize * 0.3;
    final dx = toPos.dx - fromPos.dx;
    final dy = toPos.dy - fromPos.dy;
    final distance = (toPos - fromPos).distance;

    if (distance == 0) return;

    // Use pre-allocated path, but reset it
    _arrowPath.reset();
    _arrowPath.moveTo(toPos.dx, toPos.dy);

    // Calculate arrow points
    final x1 = toPos.dx - arrowSize * 1.5 * dx / distance + arrowSize * 0.5 * dy / distance;
    final y1 = toPos.dy - arrowSize * 1.5 * dy / distance - arrowSize * 0.5 * dx / distance;
    final x2 = toPos.dx - arrowSize * 1.5 * dx / distance - arrowSize * 0.5 * dy / distance;
    final y2 = toPos.dy - arrowSize * 1.5 * dy / distance + arrowSize * 0.5 * dx / distance;

    _arrowPath.lineTo(x1, y1);
    _arrowPath.lineTo(x2, y2);
    _arrowPath.close();

    canvas.drawPath(_arrowPath, _arrowPaint);
  }

  Offset? _squareToPosition(String square) {
    if (square.length != 2) return null;

    int file = square.codeUnitAt(0) - 'a'.codeUnitAt(0);
    int rank = 8 - int.parse(square[1]);

    if (isFlipped) {
      file = 7 - file;
      rank = 7 - rank;
    }

    return Offset(
      (file + 0.5) * squareSize,
      (rank + 0.5) * squareSize,
    );
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
