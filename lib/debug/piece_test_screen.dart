import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chess_master/screens/game/widgets/chess_piece.dart';
import 'package:chess_master/core/theme/board_themes.dart';

/// Debug screen to test piece rendering
/// Navigate to this screen to verify pieces load correctly
class PieceTestScreen extends ConsumerWidget {
  const PieceTestScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pieces = [
      'wK',
      'wQ',
      'wR',
      'wB',
      'wN',
      'wP',
      'bK',
      'bQ',
      'bR',
      'bB',
      'bN',
      'bP',
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Piece Rendering Test')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Traditional Pieces',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: pieces.map((piece) {
                return Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    color: Colors.white,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ChessPiece(
                        piece: piece,
                        size: 60,
                        pieceSet: PieceSet.traditional,
                      ),
                      Text(piece, style: const TextStyle(fontSize: 10)),
                    ],
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 32),
            const Text(
              'Modern Pieces',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: pieces.map((piece) {
                return Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    color: Colors.white,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ChessPiece(
                        piece: piece,
                        size: 60,
                        pieceSet: PieceSet.modern,
                      ),
                      Text(piece, style: const TextStyle(fontSize: 10)),
                    ],
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 32),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Instructions:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text('1. Check if pieces render as SVG images'),
                    Text(
                      '2. If you see Unicode symbols (♔♕♖), SVG loading failed',
                    ),
                    Text('3. If you see nothing, check console for errors'),
                    Text(
                      '4. Check console for "ChessPiece: Loading..." messages',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
