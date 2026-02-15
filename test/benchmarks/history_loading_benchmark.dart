import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

void main() {
  test('Benchmark history loading and grouping', () {
    // 1. Generate dummy data (simulating DB result)
    // We simulate 10,000 games to represent a heavy database load
    print('Generating 10,000 dummy games...');
    final allGames = List.generate(10000, (index) {
      return {
        'id': 'game_$index',
        // Distribute dates over the last year
        'created_at':
            DateTime.now()
                .subtract(Duration(hours: index))
                .millisecondsSinceEpoch,
        'updated_at':
            DateTime.now()
                .subtract(Duration(hours: index))
                .millisecondsSinceEpoch,
        'player_color': index % 2 == 0 ? 'white' : 'black',
        'result': '1-0',
        'is_completed': 1,
        'name': 'Game $index',
        'bot_elo': 1200,
        'move_count': 30,
      };
    });

    // Baseline: Process all games
    // This simulates the current behavior where we fetch everything and group it
    print('Starting baseline benchmark (10,000 items)...');
    final stopwatch = Stopwatch()..start();

    final groupedGames = <String, List<Map<String, dynamic>>>{};
    final dateFormat = DateFormat('MMM d, yyyy');

    for (final game in allGames) {
      final timestamp =
          game['updated_at'] as int? ?? game['created_at'] as int?;
      if (timestamp != null) {
        final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
        final dateKey = dateFormat.format(date);
        groupedGames.putIfAbsent(dateKey, () => []).add(game);
      }
    }

    stopwatch.stop();
    final baselineTime = stopwatch.elapsedMilliseconds;
    print('Baseline (10,000 items): ${baselineTime} ms');

    // Improved: Process chunk
    // This simulates the initial load of the paginated approach
    print('Starting paginated benchmark (20 items)...');
    final chunk = allGames.take(20).toList();
    stopwatch.reset();
    stopwatch.start();

    final groupedChunk = <String, List<Map<String, dynamic>>>{};
    for (final game in chunk) {
      final timestamp =
          game['updated_at'] as int? ?? game['created_at'] as int?;
      if (timestamp != null) {
        final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
        final dateKey = dateFormat.format(date);
        groupedChunk.putIfAbsent(dateKey, () => []).add(game);
      }
    }

    stopwatch.stop();
    final paginatedTime = stopwatch.elapsedMilliseconds;
    print('Paginated (20 items): ${paginatedTime} ms');

    print(
      'Improvement: ${(baselineTime / paginatedTime).toStringAsFixed(1)}x faster processing',
    );
  });
}
