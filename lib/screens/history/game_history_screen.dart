import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:chess_master/core/theme/app_theme.dart';
import 'package:chess_master/core/services/database_service.dart';
import 'package:chess_master/core/constants/app_constants.dart';
import 'package:chess_master/providers/game_provider.dart';
import 'package:chess_master/providers/engine_provider.dart';
import 'package:chess_master/screens/game/game_screen.dart';

/// State for game history
class GameHistoryState {
  final List<Map<String, dynamic>> games;
  final bool hasMore;
  final bool isLoadingMore;

  const GameHistoryState({
    this.games = const [],
    this.hasMore = true,
    this.isLoadingMore = false,
  });

  GameHistoryState copyWith({
    List<Map<String, dynamic>>? games,
    bool? hasMore,
    bool? isLoadingMore,
  }) {
    return GameHistoryState(
      games: games ?? this.games,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

/// Notifier for game history
class GameHistoryNotifier extends StateNotifier<AsyncValue<GameHistoryState>> {
  final DatabaseService _dbService;
  static const int _pageSize = 20;

  GameHistoryNotifier(this._dbService) : super(const AsyncValue.loading()) {
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    try {
      final games = await _dbService.getAllGames(limit: _pageSize, offset: 0);
      if (mounted) {
        state = AsyncValue.data(
          GameHistoryState(games: games, hasMore: games.length == _pageSize),
        );
      }
    } catch (e, st) {
      if (mounted) {
        state = AsyncValue.error(e, st);
      }
    }
  }

  Future<void> loadMore() async {
    final currentState = state.value;
    if (currentState == null ||
        !currentState.hasMore ||
        currentState.isLoadingMore) {
      return;
    }

    state = AsyncValue.data(currentState.copyWith(isLoadingMore: true));

    try {
      final currentCount = currentState.games.length;
      final newGames = await _dbService.getAllGames(
        limit: _pageSize,
        offset: currentCount,
      );

      if (mounted) {
        state = AsyncValue.data(
          currentState.copyWith(
            games: [...currentState.games, ...newGames],
            hasMore: newGames.length == _pageSize,
            isLoadingMore: false,
          ),
        );
      }
    } catch (e) {
      // Revert loading state on error
      if (mounted) {
        state = AsyncValue.data(currentState.copyWith(isLoadingMore: false));
      }
    }
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    await _loadInitial();
  }

  Future<void> deleteGame(String id) async {
    await _dbService.deleteGame(id);
    final currentState = state.value;
    if (currentState != null) {
      final updatedGames =
          currentState.games.where((g) => g['id'] != id).toList();
      if (mounted) {
        state = AsyncValue.data(currentState.copyWith(games: updatedGames));
      }
    }
  }
}

/// Provider for game history
final gameHistoryProvider =
    StateNotifierProvider<GameHistoryNotifier, AsyncValue<GameHistoryState>>((
      ref,
    ) {
      final dbService = ref.read(databaseServiceProvider);
      return GameHistoryNotifier(dbService);
    });

/// Game history screen showing saved games
class GameHistoryScreen extends ConsumerWidget {
  const GameHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gamesAsync = ref.watch(gameHistoryProvider);

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        title: const Text('Game History'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(gameHistoryProvider.notifier).refresh(),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: gamesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (error, stack) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error loading games: $error'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed:
                        () => ref.read(gameHistoryProvider.notifier).refresh(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
        data: (historyState) {
          if (historyState.games.isEmpty) {
            return _buildEmptyState(context);
          }
          return _buildGameList(context, ref, historyState);
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.history,
            size: 64,
            color: AppTheme.textSecondary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No games yet',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 8),
          Text(
            'Play some games to see your history',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppTheme.textHint),
          ),
        ],
      ),
    );
  }

  Widget _buildGameList(
    BuildContext context,
    WidgetRef ref,
    GameHistoryState historyState,
  ) {
    final games = historyState.games;
    // Group games by date
    final groupedGames = <String, List<Map<String, dynamic>>>{};
    final dateFormat = DateFormat('MMM d, yyyy');

    for (final game in games) {
      final timestamp =
          game['updated_at'] as int? ?? game['created_at'] as int?;
      if (timestamp != null) {
        final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
        final dateKey = dateFormat.format(date);
        groupedGames.putIfAbsent(dateKey, () => []).add(game);
      }
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (scrollInfo) {
        if (!historyState.isLoadingMore &&
            historyState.hasMore &&
            scrollInfo.metrics.pixels >=
                scrollInfo.metrics.maxScrollExtent - 200) {
          ref.read(gameHistoryProvider.notifier).loadMore();
        }
        return false;
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: groupedGames.length + (historyState.isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == groupedGames.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final dateKey = groupedGames.keys.elementAt(index);
          final dateGames = groupedGames[dateKey]!;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (index > 0) const SizedBox(height: 16),
              _buildDateHeader(context, dateKey),
              const SizedBox(height: 8),
              ...dateGames.map(
                (game) => _GameCard(
                  game: game,
                  onTap: () => _loadGame(context, ref, game),
                  onDelete: () => _deleteGame(context, ref, game),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDateHeader(BuildContext context, String date) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            date,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  Future<void> _loadGame(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> game,
  ) async {
    final isCompleted = game['is_completed'] == 1;

    if (isCompleted) {
      // Show game for review/analysis
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Analysis mode coming soon!')),
      );
      return;
    }

    // Resume game
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Resume Game?'),
            content: const Text('Do you want to continue this game?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Resume'),
              ),
            ],
          ),
    );

    if (confirm != true) return;

    // Initialize engine and load game
    final engineNotifier = ref.read(engineProvider.notifier);
    await engineNotifier.initialize();
    engineNotifier.resetForNewGame();

    // Start game from saved position
    final playerColorStr = game['player_color'] as String? ?? 'white';
    final playerColor =
        playerColorStr == 'white' ? PlayerColor.white : PlayerColor.black;

    final botElo = game['bot_elo'] as int? ?? 1200;
    final difficultyIndex = AppConstants.difficultyLevels
        .indexWhere((d) => d.elo == botElo)
        .clamp(0, AppConstants.difficultyLevels.length - 1);
    final difficulty = AppConstants.difficultyLevels[difficultyIndex];

    final timeControlStr = game['time_control'] as String? ?? 'No Timer';
    final timeControlIndex = AppConstants.timeControls
        .indexWhere((tc) => tc.name == timeControlStr)
        .clamp(0, AppConstants.timeControls.length - 1);
    final timeControl = AppConstants.timeControls[timeControlIndex];

    final fenCurrent = game['fen_current'] as String?;

    ref
        .read(gameProvider.notifier)
        .startNewGame(
          playerColor: playerColor,
          difficulty: difficulty,
          timeControl: timeControl,
          startingFen: fenCurrent,
        );

    if (context.mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const GameScreen()),
      );
    }
  }

  Future<void> _deleteGame(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> game,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Game?'),
            content: const Text('This action cannot be undone.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
              ),
            ],
          ),
    );

    if (confirm != true) return;

    await ref
        .read(gameHistoryProvider.notifier)
        .deleteGame(game['id'] as String);

    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Game deleted')));
    }
  }
}

/// Game card widget
class _GameCard extends StatelessWidget {
  final Map<String, dynamic> game;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _GameCard({
    required this.game,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final result = game['result'] as String?;
    final resultReason = game['result_reason'] as String?;
    final playerColor = game['player_color'] as String? ?? 'white';
    final botElo = game['bot_elo'] as int? ?? 0;
    final moveCount = game['move_count'] as int? ?? 0;
    final isCompleted = game['is_completed'] == 1;
    final isSaved = game['is_saved'] == 1;
    final name = game['name'] as String?;

    final timestamp = game['updated_at'] as int? ?? game['created_at'] as int?;
    final dateTime =
        timestamp != null
            ? DateTime.fromMillisecondsSinceEpoch(timestamp)
            : null;
    final timeFormat = DateFormat('HH:mm');

    // Determine result display
    IconData resultIcon;
    Color resultColor;
    String resultText;

    if (!isCompleted) {
      resultIcon = Icons.pause_circle_outline;
      resultColor = Colors.orange;
      resultText = 'In Progress';
    } else if (result == '1-0') {
      if (playerColor == 'white') {
        resultIcon = Icons.emoji_events;
        resultColor = Colors.green;
        resultText = 'Victory';
      } else {
        resultIcon = Icons.sentiment_dissatisfied;
        resultColor = Colors.red;
        resultText = 'Defeat';
      }
    } else if (result == '0-1') {
      if (playerColor == 'black') {
        resultIcon = Icons.emoji_events;
        resultColor = Colors.green;
        resultText = 'Victory';
      } else {
        resultIcon = Icons.sentiment_dissatisfied;
        resultColor = Colors.red;
        resultText = 'Defeat';
      }
    } else {
      resultIcon = Icons.handshake;
      resultColor = Colors.blue;
      resultText = 'Draw';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: AppTheme.cardDark,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Result icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: resultColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(resultIcon, color: resultColor),
              ),
              const SizedBox(width: 12),
              // Game info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          name ?? 'Game vs Bot ($botElo)',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        if (isSaved)
                          Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: Icon(
                              Icons.bookmark,
                              size: 16,
                              color: AppTheme.accentColor,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: resultColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            resultText,
                            style: TextStyle(
                              fontSize: 11,
                              color: resultColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (resultReason != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            resultReason,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$moveCount moves • ${playerColor == 'white' ? '♔' : '♚'} as ${playerColor.capitalize()} • ${dateTime != null ? timeFormat.format(dateTime) : ''}',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: AppTheme.textHint),
                    ),
                  ],
                ),
              ),
              // Actions
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (value) {
                  if (value == 'delete') {
                    onDelete();
                  }
                },
                itemBuilder:
                    (context) => [
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Delete'),
                          ],
                        ),
                      ),
                    ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

extension StringCapitalize on String {
  String capitalize() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }
}
