import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chess_master/models/game_model.dart';

/// Widget to display the move history list
class MoveList extends ConsumerWidget {
  final List<ChessMove> moves;
  final int? currentMoveIndex;
  final Function(int)? onMoveTap;
  final bool compact;

  const MoveList({
    super.key,
    required this.moves,
    this.currentMoveIndex,
    this.onMoveTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (moves.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        child: Text(
          'No moves yet',
          style: TextStyle(
            color: Colors.grey[600],
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }

    if (compact) {
      return _buildCompactList(context);
    }

    return _buildFullList(context);
  }

  Widget _buildCompactList(BuildContext context) {
    final moveText = _buildMoveString();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(8),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        reverse: true,
        child: Text(
          moveText,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 14,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  String _buildMoveString() {
    final buffer = StringBuffer();

    for (int i = 0; i < moves.length; i++) {
      if (i % 2 == 0) {
        buffer.write('${(i ~/ 2) + 1}. ');
      }
      buffer.write('${moves[i].san} ');
    }

    return buffer.toString().trim();
  }

  Widget _buildFullList(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const ClampingScrollPhysics(),
      itemCount: (moves.length / 2).ceil(),
      itemBuilder: (context, index) {
        final moveNumber = index + 1;
        final whiteIndex = index * 2;
        final blackIndex = index * 2 + 1;

        final whiteMove = moves[whiteIndex];
        final blackMove = blackIndex < moves.length ? moves[blackIndex] : null;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: index.isEven ? Colors.transparent : Colors.black12,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              // Move number
              SizedBox(
                width: 32,
                child: Text(
                  '$moveNumber.',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[400],
                  ),
                ),
              ),
              // White's move
              Expanded(
                child: _buildMoveButton(
                  whiteMove,
                  whiteIndex,
                  isCurrentMove: currentMoveIndex == whiteIndex,
                ),
              ),
              // Black's move
              Expanded(
                child:
                    blackMove != null
                        ? _buildMoveButton(
                          blackMove,
                          blackIndex,
                          isCurrentMove: currentMoveIndex == blackIndex,
                        )
                        : const SizedBox.shrink(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMoveButton(
    ChessMove move,
    int index, {
    bool isCurrentMove = false,
  }) {
    return InkWell(
      onTap: onMoveTap != null ? () => onMoveTap!(index) : null,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color:
              isCurrentMove
                  ? Colors.blue.withValues(alpha: 0.3)
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              move.san,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 14,
                fontWeight: isCurrentMove ? FontWeight.bold : FontWeight.normal,
                color: Colors.white,
              ),
            ),
            if (move.isCheck && !move.isCheckmate)
              const Icon(
                Icons.warning_amber_rounded,
                size: 14,
                color: Colors.orange,
              ),
            if (move.isCheckmate)
              const Icon(Icons.stars, size: 14, color: Colors.amber),
          ],
        ),
      ),
    );
  }
}

/// Small inline move notation display
class MoveNotation extends StatelessWidget {
  final String san;
  final bool isWhite;
  final int moveNumber;
  final bool isCheck;
  final bool isCheckmate;

  const MoveNotation({
    super.key,
    required this.san,
    required this.isWhite,
    required this.moveNumber,
    this.isCheck = false,
    this.isCheckmate = false,
  });

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 14,
          color: Colors.white,
        ),
        children: [
          if (isWhite) TextSpan(text: '$moveNumber. '),
          TextSpan(
            text: san,
            style: TextStyle(
              fontWeight: isCheckmate ? FontWeight.bold : FontWeight.normal,
              color:
                  isCheckmate
                      ? Colors.amber
                      : isCheck
                      ? Colors.orange
                      : Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
