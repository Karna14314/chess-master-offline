import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:chess_master/core/theme/board_themes.dart';
import 'package:chess_master/providers/settings_provider.dart';

/// Lightweight, read-only 8x8 chessboard preview for game history thumbnails,
/// active match previews, opening positions, and puzzle previews.
class MiniBoard extends ConsumerWidget {
  final String fen;
  final double size;
  final bool isFlipped;
  final BoardTheme? customTheme;
  final PieceSet? customPieceSet;
  final double borderRadius;
  final bool showBorder;

  const MiniBoard({
    super.key,
    this.fen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
    this.size = 72.0,
    this.isFlipped = false,
    this.customTheme,
    this.customPieceSet,
    this.borderRadius = 8.0,
    this.showBorder = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final theme = customTheme ?? settings.currentBoardTheme;
    final pieceSet = customPieceSet ?? settings.currentPieceSet;

    final grid = _parseFen(fen);

    return RepaintBoundary(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          border: showBorder
              ? Border.all(
                  color: theme.darkSquare.withValues(alpha: 0.4),
                  width: 1.0,
                )
              : null,
          boxShadow: showBorder
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: Column(
            children: List.generate(8, (rowIdx) {
              final rank = isFlipped ? rowIdx : 7 - rowIdx;
              return Expanded(
                child: Row(
                  children: List.generate(8, (colIdx) {
                    final file = isFlipped ? 7 - colIdx : colIdx;
                    final isLight = (rank + file) % 2 != 0;
                    final squareColor = isLight ? theme.lightSquare : theme.darkSquare;
                    final pieceCode = grid[rank][file];

                    return Expanded(
                      child: Container(
                        color: squareColor,
                        child: pieceCode != null
                            ? Padding(
                                padding: EdgeInsets.all(size / 64),
                                child: SvgPicture.asset(
                                  pieceSet.getAssetPath(pieceCode),
                                  fit: BoxFit.contain,
                                  placeholderBuilder: (context) => _buildUnicodeFallback(pieceCode),
                                ),
                              )
                            : null,
                      ),
                    );
                  }),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildUnicodeFallback(String pieceCode) {
    final isWhite = pieceCode.startsWith('w');
    final p = pieceCode.substring(1);
    final symbols = {
      'K': isWhite ? '♔' : '♚',
      'Q': isWhite ? '♕' : '♛',
      'R': isWhite ? '♖' : '♜',
      'B': isWhite ? '♗' : '♝',
      'N': isWhite ? '♘' : '♞',
      'P': isWhite ? '♙' : '♟',
    };
    return Center(
      child: Text(
        symbols[p] ?? '',
        style: TextStyle(
          fontSize: size / 10,
          color: isWhite ? Colors.white : Colors.black,
        ),
      ),
    );
  }

  /// Parses FEN string into an 8x8 matrix where [rank][file] holds pieceCode ('wK', 'bP') or null.
  static List<List<String?>> _parseFen(String fen) {
    final matrix = List.generate(8, (_) => List<String?>.filled(8, null));
    final parts = fen.trim().split(' ');
    final piecePlacement = parts.isNotEmpty ? parts[0] : '';
    final rows = piecePlacement.split('/');

    if (rows.length != 8) return matrix;

    for (int r = 0; r < 8; r++) {
      final rank = 7 - r;
      int file = 0;
      for (int i = 0; i < rows[r].length; i++) {
        final char = rows[r][i];
        if (file >= 8) break;

        final digit = int.tryParse(char);
        if (digit != null) {
          file += digit;
        } else {
          final isWhite = char == char.toUpperCase();
          final pieceType = char.toUpperCase();
          matrix[rank][file] = '${isWhite ? 'w' : 'b'}$pieceType';
          file++;
        }
      }
    }
    return matrix;
  }
}
