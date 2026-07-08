import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chess_master/providers/game_provider.dart';

void main() {
  test('gameState initialization test', () {
    final container = ProviderContainer();
    final gameState = container.read(gameProvider);
    expect(gameState.isPlayerTurn, isTrue);
  });
}
