import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:chess_master/core/theme/app_theme.dart';
import 'package:chess_master/core/services/database_service.dart';
import 'package:chess_master/core/constants/app_constants.dart';
import 'package:chess_master/providers/game_provider.dart';
import 'package:chess_master/providers/engine_provider.dart';
import 'package:chess_master/screens/game/game_screen.dart';
import 'package:chess_master/screens/analysis/analysis_screen.dart';
import 'package:chess/chess.dart' as chess;
import 'package:chess_master/models/game_model.dart';

/// Provider for game history
final gameHistoryProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final dbService = ref.read(databaseServiceProvider);
  return await dbService.getAllGames();
});

/// Game history screen showing saved games
class GameHistoryScreen extends ConsumerStatefulWidget {
  const GameHistoryScreen({super.key});

  @override
  ConsumerState<GameHistoryScreen> createState() => _GameHistoryScreenState();
}

class _GameHistoryScreenState extends ConsumerState<GameHistoryScreen> {
  String _filterGameMode = 'all'; // 'all', 'bot', 'local'
  String _filterResult = 'all'; // 'all', 'win', 'loss', 'draw'

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceDark,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Filter Games',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),

                  // Game Mode Filter
                  Text(
                    'Game Mode',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      _FilterChip(
                        label: 'All',
                        selected: _filterGameMode == 'all',
                        onSelected:
                            (_) => setSheetState(() => _filterGameMode = 'all'),
                      ),
                      _FilterChip(
                        label: 'Bot',
                        selected: _filterGameMode == 'bot',
                        onSelected:
                            (_) => setSheetState(() => _filterGameMode = 'bot'),
                      ),
                      _FilterChip(
                        label: 'Local Multiplayer',
                        selected: _filterGameMode == 'local',
                        onSelected:
                            (_) =>
                                setSheetState(() => _filterGameMode = 'local'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Result Filter
                  Text(
                    'Result',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      _FilterChip(
                        label: 'All',
                        selected: _filterResult == 'all',
                        onSelected:
                            (_) => setSheetState(() => _filterResult = 'all'),
                      ),
                      _FilterChip(
                        label: 'Win',
                        selected: _filterResult == 'win',
                        onSelected:
                            (_) => setSheetState(() => _filterResult = 'win'),
                      ),
                      _FilterChip(
                        label: 'Loss',
                        selected: _filterResult == 'loss',
                        onSelected:
                            (_) => setSheetState(() => _filterResult = 'loss'),
                      ),
                      _FilterChip(
                        label: 'Draw',
                        selected: _filterResult == 'draw',
                        onSelected:
                            (_) => setSheetState(() => _filterResult = 'draw'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        setState(() {}); // Update main screen
                      },
                      child: const Text('Apply Filters'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final gamesAsync = ref.watch(gameHistoryProvider);

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        title: const Text('Game History'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterSheet,
            tooltip: 'Filter',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.refresh(gameHistoryProvider),
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
                    onPressed: () => ref.refresh(gameHistoryProvider),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
        data: (games) {
          final filteredGames = _filterGames(games);

          if (filteredGames.isEmpty) {
            return _buildEmptyState(context);
          }
          return _buildGameList(context, filteredGames);
        },
      ),
    );
  }

  List<Map<String, dynamic>> _filterGames(List<Map<String, dynamic>> games) {
    return games.where((game) {
      // Filter by mode
      if (_filterGameMode != 'all') {
        final mode = game['game_mode'] as String?;
        // Default to 'bot' if null (legacy data)
        final effectiveMode = mode ?? 'bot';
        if (effectiveMode != _filterGameMode) return false;
      }

      // Filter by result
      if (_filterResult != 'all') {
        final result = game['result'] as String?;
        final playerColor = game['player_color'] as String? ?? 'white';

        if (result == null) return false;

        if (_filterResult == 'draw') {
          if (result != '1/2-1/2') return false;
        } else if (_filterResult == 'win') {
          final won =
              (playerColor == 'white' && result == '1-0') ||
              (playerColor == 'black' && result == '0-1');
          if (!won) return false;
        } else if (_filterResult == 'loss') {
          final lost =
              (playerColor == 'white' && result == '0-1') ||
              (playerColor == 'black' && result == '1-0');
          if (!lost) return false;
        }
      }

      return true;
    }).toList();
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.history,
            size: 64,
            color: AppTheme.textSecondary.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No games found',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 8),
          Text(
            'Try changing your filters',
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
    List<Map<String, dynamic>> games,
  ) {
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

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: groupedGames.length,
      itemBuilder: (context, index) {
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
      final pgn = game['pgn'] as String?;
      if (pgn == null || pgn.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No PGN data available to analyze this game.'),
            ),
          );
        }
        return;
      }

      final moves = _parsePgnToMoves(pgn);
      if (moves == null || moves.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to parse the game moves.')),
          );
        }
        return;
      }

      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => AnalysisScreen(moves: moves)),
        );
      }
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

    // Read game_mode from database and convert to GameMode enum
    final gameModeStr = game['game_mode'] as String? ?? 'bot';
    final gameMode =
        gameModeStr == 'local' ? GameMode.localMultiplayer : GameMode.bot;

    ref
        .read(gameProvider.notifier)
        .startNewGame(
          playerColor: playerColor,
          difficulty: difficulty,
          timeControl: timeControl,
          startingFen: fenCurrent,
          gameMode: gameMode,
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

    await ref.read(databaseServiceProvider).deleteGame(game['id'] as String);
    ref.refresh(gameHistoryProvider);

    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Game deleted')));
    }
  }

  List<ChessMove>? _parsePgnToMoves(String pgn) {
    try {
      final tempBoard = chess.Chess();
      if (!tempBoard.load_pgn(pgn)) return null;

      final history = tempBoard.getHistory();
      if (history.isEmpty) return null;

      final moves = <ChessMove>[];
      final replayBoard = chess.Chess();

      for (var h in history) {
        final san = h.toString();
        final success = replayBoard.move(san);
        if (!success) return null;

        final lastVerbose =
            replayBoard.getHistory({'verbose': true}).last as Map;
        moves.add(
          ChessMove(
            from: lastVerbose['from'] as String,
            to: lastVerbose['to'] as String,
            san: san,
            promotion: lastVerbose['promotion']?.toString(),
            capturedPiece: lastVerbose['captured']?.toString(),
            isCapture: lastVerbose['captured'] != null,
            isCheck: replayBoard.in_check,
            isCheckmate: replayBoard.in_checkmate,
            isCastle: san.contains('O-O'),
            fen: replayBoard.fen,
          ),
        );
      }
      return moves;
    } catch (e) {
      return null;
    }
  }
}

/// Filter Chip widget
class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: onSelected,
      backgroundColor: AppTheme.cardDark,
      selectedColor: AppTheme.primaryColor.withOpacity(0.2),
      checkmarkColor: AppTheme.primaryColor,
      labelStyle: TextStyle(
        color: selected ? AppTheme.primaryColor : AppTheme.textPrimary,
      ),
    );
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
    final customName = game['custom_name'] as String?;
    final gameMode = game['game_mode'] as String? ?? 'bot';

    final timestamp = game['updated_at'] as int? ?? game['created_at'] as int?;
    final dateTime =
        timestamp != null
            ? DateTime.fromMillisecondsSinceEpoch(timestamp)
            : null;
    final timeFormat = DateFormat('HH:mm');

    // Determine opponent display
    final opponentText = gameMode == 'local' ? 'Friend' : 'Bot ($botElo)';
    final displayName = customName ?? 'Game vs $opponentText';

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
                  color: resultColor.withOpacity(0.2),
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
                          displayName,
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
                            color: resultColor.withOpacity(0.2),
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
