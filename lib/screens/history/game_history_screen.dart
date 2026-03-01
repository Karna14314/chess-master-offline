import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:chess_master/core/theme/app_theme.dart';
import 'package:chess_master/core/services/database_service.dart';
import 'package:chess_master/core/constants/app_constants.dart';
import 'package:chess_master/providers/game_session_viewmodel.dart';
import 'package:chess_master/providers/engine_provider.dart';
import 'package:chess_master/screens/game/game_screen.dart';
import 'package:chess_master/screens/analysis/analysis_screen.dart';
import 'package:chess/chess.dart' as chess;
import 'package:chess_master/models/game_model.dart';
import 'package:chess_master/models/game_session.dart';
import 'package:chess_master/data/repositories/game_session_repository.dart';

final gameHistoryProvider = FutureProvider<List<GameSession>>((
  ref,
) async {
  final repo = ref.read(gameSessionRepositoryProvider);
  return await repo.getRealGamesHistory();
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

  List<GameSession> _filterGames(List<GameSession> games) {
    return games.where((game) {
      // Filter by mode
      if (_filterGameMode != 'all') {
        final effectiveMode = game.gameMode == GameMode.localMultiplayer ? 'local' : 'bot';
        if (effectiveMode != _filterGameMode) return false;
      }

      // Filter by result
      if (_filterResult != 'all') {
        if (game.result == null) return false;

        if (_filterResult == 'draw') {
          if (game.result != GameResult.draw) return false;
        } else if (_filterResult == 'win') {
          final won = (game.playerColor == PlayerColor.white && game.result == GameResult.whiteWins) ||
                      (game.playerColor == PlayerColor.black && game.result == GameResult.blackWins);
          if (!won) return false;
        } else if (_filterResult == 'loss') {
          final lost = (game.playerColor == PlayerColor.white && game.result == GameResult.blackWins) ||
                       (game.playerColor == PlayerColor.black && game.result == GameResult.whiteWins);
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
    List<GameSession> games,
  ) {
    // Group games by date
    final groupedGames = <String, List<GameSession>>{};
    final dateFormat = DateFormat('MMM d, yyyy');

    for (final game in games) {
      final date = game.lastMoveTime;
      final dateKey = dateFormat.format(date);
      groupedGames.putIfAbsent(dateKey, () => []).add(game);
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
    GameSession game,
  ) async {
    final isCompleted = game.isCompleted;

    if (isCompleted) {
      // Prefer using the stored move history if available
      List<ChessMove> moves;
      if (game.moveHistory.isNotEmpty) {
        moves = game.moveHistory;
      } else {
        final pgn = game.pgn;
        if (pgn.isEmpty) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('No game data available to analyze.'),
              ),
            );
          }
          return;
        }

        final parsedMoves = _parsePgnToMoves(pgn);
        if (parsedMoves == null || parsedMoves.isEmpty) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Failed to parse the game moves.')),
            );
          }
          return;
        }
        moves = parsedMoves;
      }

      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AnalysisScreen(
              moves: moves,
              startingFen: game.startingFen,
            ),
          ),
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

    // Initialize engine
    final engineNotifier = ref.read(engineProvider.notifier);
    await engineNotifier.initialize();
    engineNotifier.resetForNewGame();

    // Load game session
    await ref.read(gameSessionProvider.notifier).loadSession(game.id);

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
    GameSession game,
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

    await ref.read(gameSessionRepositoryProvider).deleteSession(game.id);
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

        final state = replayBoard.history.last;
        final move = state.move;

        moves.add(
          ChessMove(
            from: _algebraic(move.from),
            to: _algebraic(move.to),
            san: san,
            promotion: move.promotion?.toString(),
            capturedPiece: move.captured?.toString(),
            isCapture: move.captured != null,
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

  String _algebraic(int i) {
    final f = i & 15;
    final r = i >> 4;
    return '${String.fromCharCode(97 + f)}${8 - r}';
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
  final GameSession game;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _GameCard({
    required this.game,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isCompleted = game.isCompleted;
    final isSaved = true; // game sessions are implicitly saved
    final customName = null; // Removed custom name for now
    
    final dateTime = game.lastMoveTime;
    final timeFormat = DateFormat('HH:mm');

    // Determine opponent display
    final opponentText = game.gameMode == GameMode.localMultiplayer ? 'Friend' : 'Bot (${game.difficulty?.elo ?? 1200})';
    final displayName = customName ?? 'Game vs $opponentText';

    // Determine result display
    IconData resultIcon;
    Color resultColor;
    String resultText;

    if (!isCompleted) {
      resultIcon = Icons.pause_circle_outline;
      resultColor = Colors.orange;
      resultText = 'In Progress';
    } else if (game.result == GameResult.whiteWins) {
      if (game.playerColor == PlayerColor.white) {
        resultIcon = Icons.emoji_events;
        resultColor = Colors.green;
        resultText = 'Victory';
      } else {
        resultIcon = Icons.sentiment_dissatisfied;
        resultColor = Colors.red;
        resultText = 'Defeat';
      }
    } else if (game.result == GameResult.blackWins) {
      if (game.playerColor == PlayerColor.black) {
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
                        if (game.resultReason != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            game.resultReason!,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${game.moveHistory.length} moves • ${game.playerColor == PlayerColor.white ? '♔' : '♚'} as ${game.playerColor.name.capitalize()} • ${timeFormat.format(dateTime)}',
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
