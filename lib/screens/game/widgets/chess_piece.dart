import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:chess_master/core/theme/board_themes.dart';

/// Widget to render a chess piece from SVG or fallback to text
class ChessPiece extends StatelessWidget {
  final String piece; // Format: 'wK', 'bQ', etc.
  final double size;
  final PieceSet pieceSet;

  const ChessPiece({
    super.key,
    required this.piece,
    required this.size,
    required this.pieceSet,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Padding(
        padding: EdgeInsets.all(size * 0.05),
        child: _buildPiece(),
      ),
    );
  }

  Widget _buildPiece() {
    // Try to load SVG first
    final assetPath = pieceSet.getAssetPath(piece);

    // ⚡ Bolt: Using RepaintBoundary to isolate the piece from the board's pixels.
    // This stops the 'Raster' thread from doing 64+ redraws per frame during a drag.
    return RepaintBoundary(
      child: SvgPicture.asset(
        assetPath,
        width: size * 0.9,
        height: size * 0.9,
        fit: BoxFit.contain,
        placeholderBuilder: (context) => _buildFallbackPiece(),
        colorFilter: null, // Don't apply color filter to preserve piece colors
      ),
    );
  }

  Widget _buildFallbackPiece() {
    // Unicode chess symbols as fallback
    final isWhite = piece.startsWith('w');
    final pieceType = piece.substring(1);
    
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
        symbols[pieceType] ?? '?',
        style: TextStyle(
          fontSize: size * 0.75,
          color: isWhite ? Colors.white : Colors.black,
          shadows: [
            Shadow(
              color: isWhite ? Colors.black : Colors.white,
              blurRadius: 2,
              offset: const Offset(1, 1),
            ),
          ],
        ),
      ),
    );
  }
}

/// Static helper to preload piece assets
class PieceAssets {
  static final Map<String, String> _pieceNames = {
    'wK': 'White King',
    'wQ': 'White Queen',
    'wR': 'White Rook',
    'wB': 'White Bishop',
    'wN': 'White Knight',
    'wP': 'White Pawn',
    'bK': 'Black King',
    'bQ': 'Black Queen',
    'bR': 'Black Rook',
    'bB': 'Black Bishop',
    'bN': 'Black Knight',
    'bP': 'Black Pawn',
  };

  static List<String> get allPieceCodes => _pieceNames.keys.toList();

  static String getPieceName(String code) => _pieceNames[code] ?? 'Unknown';

  /// Preload all SVG assets for faster rendering
  static Future<void> preloadAssets(BuildContext context, PieceSet pieceSet) async {
    for (final piece in allPieceCodes) {
      try {
        final loader = SvgAssetLoader(pieceSet.getAssetPath(piece));
        await svg.cache.putIfAbsent(
          loader.cacheKey(null),
          () => loader.loadBytes(null),
        );
      } catch (_) {
        // Asset doesn't exist, will use fallback
      }
    }
  }
}
