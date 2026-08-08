import 'package:flutter/material.dart';
import 'package:chess/chess.dart' as chess;
import 'package:chess_master/core/theme/app_theme.dart';
import 'package:chess_master/core/models/chess_models.dart';
import 'package:google_fonts/google_fonts.dart';

/// Convert a list of UCI moves to SAN given a starting FEN.
List<String> _uciToSan(String startingFen, List<String> uciMoves) {
  try {
    final board = chess.Chess.fromFEN(startingFen);
    final sanMoves = <String>[];
    for (final uci in uciMoves) {
      if (uci.length < 4) {
        sanMoves.add(uci);
        continue;
      }
      final from = uci.substring(0, 2);
      final to = uci.substring(2, 4);
      final promotion = uci.length > 4 ? uci.substring(4, 5) : null;

      // Find the move in legal moves and get SAN BEFORE making it
      final legalMoves = board.generate_moves();
      chess.Move? targetMove;
      for (final m in legalMoves) {
        if (m.fromAlgebraic == from && m.toAlgebraic == to &&
            (promotion == null || m.promotion?.name == promotion)) {
          targetMove = m;
          break;
        }
      }
      if (targetMove != null) {
        sanMoves.add(board.move_to_san(targetMove));
        board.make_move(targetMove);
      } else {
        sanMoves.add(uci);
      }
    }
    return sanMoves;
  } catch (_) {
    return uciMoves;
  }
}

class EngineRecommendations extends StatefulWidget {
  final List<EngineLine> lines;
  final bool isLoading;
  final String? fen;

  const EngineRecommendations({
    super.key,
    required this.lines,
    this.isLoading = false,
    this.fen,
  });

  @override
  State<EngineRecommendations> createState() => _EngineRecommendationsState();
}

class _EngineRecommendationsState extends State<EngineRecommendations> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    if (widget.lines.isEmpty && !widget.isLoading) {
      return const SizedBox.shrink();
    }

    final displayLines =
        _expanded ? widget.lines : widget.lines.take(1).toList();
    final currentDepth = widget.lines.isNotEmpty ? widget.lines.first.depth : 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.cardColor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColorFor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(
                  Icons.memory_rounded,
                  size: 20,
                  color: AppTheme.primaryColor,
                ),
                const SizedBox(width: 8),
                Text(
                  'Engine Analysis',
                  style: GoogleFonts.inter(
                    color: AppTheme.textPrimaryFor(context),
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const Spacer(),
                if (widget.isLoading) ...[
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Text(
                  'Depth $currentDepth',
                  style: GoogleFonts.inter(
                    color: AppTheme.textHintFor(context),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: AppTheme.surfaceColor(context)),

          // Lines
          if (widget.lines.isEmpty && widget.isLoading)
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Center(
                child: Text(
                  'Analyzing position...',
                  style: GoogleFonts.inter(color: AppTheme.textHintFor(context)),
                ),
              ),
            )
          else
            ...displayLines.map((line) => _EngineLineRow(line: line, fen: widget.fen)),

          // Expand / Collapse button
          if (widget.lines.length > 1)
            InkWell(
              onTap: () {
                setState(() {
                  _expanded = !_expanded;
                });
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: Text(
                    _expanded ? 'Show Less' : 'Show More',
                    style: GoogleFonts.inter(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _EngineLineRow extends StatelessWidget {
  final EngineLine line;
  final String? fen;

  const _EngineLineRow({required this.line, this.fen});

  @override
  Widget build(BuildContext context) {
    final isPositive =
        line.isMate ? (line.mateIn ?? 0) > 0 : line.evaluation >= 0;

    final evalColor = isPositive ? Colors.white : Colors.black;
    final evalBgColor = isPositive ? const Color(0xFF303030) : Colors.white;

    // Convert UCI to SAN if FEN is available
    List<String> moveList;
    if (line.sanMoves != null && line.sanMoves!.isNotEmpty) {
      moveList = line.sanMoves!;
    } else if (fen != null && fen!.isNotEmpty) {
      moveList = _uciToSan(fen!, line.moves);
    } else {
      moveList = line.moves;
    }
    final bestMove = moveList.isNotEmpty ? moveList.first : '';
    final continuation =
        moveList.length > 1 ? moveList.skip(1).take(5).join(' ') : '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppTheme.surfaceColor(context), width: 1),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Eval Badge
          Container(
            width: 48,
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: evalBgColor,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppTheme.borderColorFor(context)),
            ),
            child: Center(
              child: Text(
                line.evalDisplay,
                style: GoogleFonts.spaceMono(
                  color: evalColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Moves
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bestMove,
                  style: GoogleFonts.spaceMono(
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                if (continuation.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    continuation,
                    style: GoogleFonts.spaceMono(
                      color: AppTheme.textHintFor(context),
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
