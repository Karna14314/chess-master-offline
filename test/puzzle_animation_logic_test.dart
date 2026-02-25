import 'package:flutter_test/flutter_test.dart';
import 'package:chess_master/providers/puzzle_provider.dart';
import 'package:chess_master/models/puzzle_model.dart';
import 'package:chess/chess.dart' as chess;

void main() {
  test('PuzzleGameState.isPlayerTurn toggles correctly for animation logic', () {
    // Initial state
    // Puzzle: White to move.
    // FEN: rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1
    // Moves: e2e4 e7e5

    final puzzle = Puzzle(
      id: 1, // int, not String
      fen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
      moves: ['e2e4', 'e7e5'],
      rating: 1200,
      themes: ['opening'],
      searchableThemes: ['opening'],
      popularity: 100,
    );

    final board = chess.Chess.fromFEN(puzzle.fen);

    // Simulate setup move (Opponent e2e4)
    board.move({'from': 'e2', 'to': 'e4'});

    // 1. Initial Playing State
    var state = PuzzleGameState(
      currentPuzzle: puzzle,
      board: board,
      currentMoveIndex: 1,
      isPlayerTurn:
          true, // Player to move next (Black in real game? No, puzzle FEN is start position)
      // Actually, if FEN is start position, white moves first.
      // e2e4 is White.
      // If puzzle moves are ['e2e4', 'e7e5'], first move is Opponent.
      // So Opponent moves e2e4 (White).
      // Then Player moves e7e5 (Black).
      // So isPlayerTurn should be true (Player's turn to move as Black).
      state: PuzzleState.playing,
    );

    // Check initial assumption for animation
    expect(state.isPlayerTurn, true);
    // enableMoveAnimation = state.isPlayerTurn = true.
    // If we just loaded the puzzle, maybe we don't want animation?
    // But PuzzleNotifier applies setup move immediately.
    // If the board rebuilds with new state, it might animate if lastMove matches?
    // But typically initial load doesn't trigger didUpdateWidget with changed moves from null.

    // 2. Player makes a move (e7e5)
    // PuzzleNotifier: state = state.copyWith(isPlayerTurn: false)

    state = state.copyWith(
      currentMoveIndex: 2,
      isPlayerTurn: false,
      state: PuzzleState.correct,
      lastMoveFrom: 'e7',
      lastMoveTo: 'e5',
    );

    expect(state.isPlayerTurn, false);
    // enableMoveAnimation = false. Player move snaps. Good.

    // 3. Opponent moves (Next move if any)
    // PuzzleNotifier: state = state.copyWith(isPlayerTurn: true)

    state = state.copyWith(
      currentMoveIndex: 3,
      isPlayerTurn: true,
      state: PuzzleState.playing,
      lastMoveFrom: 'g1',
      lastMoveTo: 'f3',
    );

    expect(state.isPlayerTurn, true);
    // enableMoveAnimation = true. Opponent move animates. Good.
  });
}
