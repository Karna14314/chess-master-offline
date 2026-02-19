import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chess_master/core/theme/app_theme.dart';
import 'package:chess_master/core/constants/app_constants.dart';
import 'package:chess_master/providers/statistics_provider.dart';
import 'package:chess_master/models/statistics_model.dart';
import 'package:fl_chart/fl_chart.dart';

/// Statistics dashboard screen
class StatisticsScreen extends ConsumerWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(statisticsProvider);

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        title: const Text('Statistics'),
        backgroundColor: AppTheme.surfaceDark,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                ref.read(statisticsProvider.notifier).loadStatistics(),
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'reset') {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: AppTheme.surfaceDark,
                    title: const Text('Reset Statistics'),
                    content: const Text(
                      'Are you sure you want to reset all statistics? This cannot be undone.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text(
                          'Reset',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  ref.read(statisticsProvider.notifier).resetStatistics();
                }
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'reset',
                child: Row(
                  children: [
                    Icon(Icons.delete_forever, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Reset All Stats'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Overall stats cards
            _buildOverviewSection(context, stats),
            const SizedBox(height: 24),

            // Win/Loss/Draw pie chart
            _buildGameResultsChart(context, stats),
            const SizedBox(height: 24),

            // Puzzles section
            _buildPuzzlesSection(context, stats),
            const SizedBox(height: 24),

            // Performance by ELO
            _buildPerformanceByElo(context, stats),
            const SizedBox(height: 24),

            // Game details
            _buildGameDetails(context, stats),
            const SizedBox(height: 24),

            // Top openings
            if (stats.openingsPlayed.isNotEmpty)
              _buildTopOpenings(context, stats),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewSection(BuildContext context, StatisticsModel stats) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Overview',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.sports_esports,
                iconColor: AppTheme.primaryColor,
                title: 'Games Played',
                value: stats.totalGames.toString(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                icon: Icons.emoji_events,
                iconColor: Colors.amber,
                title: 'Win Rate',
                value: '${stats.winRate.toStringAsFixed(1)}%',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.extension,
                iconColor: Colors.purple,
                title: 'Puzzles Solved',
                value: '${stats.puzzlesSolved}/${stats.puzzlesAttempted}',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                icon: Icons.trending_up,
                iconColor: Colors.cyan,
                title: 'Puzzle Rating',
                value: stats.currentPuzzleRating.toString(),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGameResultsChart(BuildContext context, StatisticsModel stats) {
    if (stats.totalGames == 0) {
      return _buildEmptyState('No games played yet');
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Game Results',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: Row(
              children: [
                Expanded(
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 4,
                      centerSpaceRadius: 40,
                      sections: [
                        PieChartSectionData(
                          value: stats.wins.toDouble(),
                          title: stats.wins.toString(),
                          color: Colors.green,
                          radius: 50,
                          titleStyle: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        PieChartSectionData(
                          value: stats.losses.toDouble(),
                          title: stats.losses.toString(),
                          color: Colors.red,
                          radius: 50,
                          titleStyle: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        PieChartSectionData(
                          value: stats.draws.toDouble(),
                          title: stats.draws.toString(),
                          color: Colors.grey,
                          radius: 50,
                          titleStyle: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 24),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _LegendItem(
                      color: Colors.green,
                      label: 'Wins',
                      value: stats.wins,
                    ),
                    const SizedBox(height: 12),
                    _LegendItem(
                      color: Colors.red,
                      label: 'Losses',
                      value: stats.losses,
                    ),
                    const SizedBox(height: 12),
                    _LegendItem(
                      color: Colors.grey,
                      label: 'Draws',
                      value: stats.draws,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPuzzlesSection(BuildContext context, StatisticsModel stats) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.extension, color: Colors.purple),
              const SizedBox(width: 8),
              Text(
                'Puzzles',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _StatItem(
                label: 'Attempted',
                value: stats.puzzlesAttempted.toString(),
              ),
              _StatItem(label: 'Solved', value: stats.puzzlesSolved.toString()),
              _StatItem(
                label: 'Solve Rate',
                value: '${stats.puzzleSolveRate.toStringAsFixed(1)}%',
              ),
              _StatItem(
                label: 'Rating',
                value: stats.currentPuzzleRating.toString(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceByElo(BuildContext context, StatisticsModel stats) {
    if (stats.gamesByElo.isEmpty) {
      return _buildEmptyState('No games played yet');
    }

    final sortedElos = stats.gamesByElo.keys.toList()..sort();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Performance by Difficulty',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          ...sortedElos.map((elo) {
            final eloStats = stats.gamesByElo[elo]!;
            final difficultyLevel = AppConstants.difficultyLevels.firstWhere(
              (d) => d.elo == elo,
              orElse: () => AppConstants.difficultyLevels.first,
            );

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${difficultyLevel.name} ($elo ELO)',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      Text(
                        '${eloStats.winRate.toStringAsFixed(0)}% win rate',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: _getWinRateColor(eloStats.winRate),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        flex: eloStats.wins,
                        child: Container(
                          height: 8,
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius:
                                eloStats.losses == 0 && eloStats.draws == 0
                                ? BorderRadius.circular(4)
                                : const BorderRadius.horizontal(
                                    left: Radius.circular(4),
                                  ),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: eloStats.draws,
                        child: Container(height: 8, color: Colors.grey),
                      ),
                      Expanded(
                        flex: eloStats.losses,
                        child: Container(
                          height: 8,
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius:
                                eloStats.wins == 0 && eloStats.draws == 0
                                ? BorderRadius.circular(4)
                                : const BorderRadius.horizontal(
                                    right: Radius.circular(4),
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${eloStats.wins}W / ${eloStats.draws}D / ${eloStats.losses}L (${eloStats.total} games)',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildGameDetails(BuildContext context, StatisticsModel stats) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Game Details',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _DetailRow(
            label: 'Total Moves Played',
            value: stats.totalMoves.toString(),
          ),
          _DetailRow(
            label: 'Average Game Length',
            value: '${stats.averageGameLength.toStringAsFixed(1)} moves',
          ),
          _DetailRow(
            label: 'Total Playing Time',
            value: _formatDuration(
              Duration(seconds: stats.totalGameTimeSeconds),
            ),
          ),
          _DetailRow(
            label: 'Average Game Time',
            value: '${stats.averageGameTimeMinutes.toStringAsFixed(1)} min',
          ),
          _DetailRow(label: 'Hints Used', value: stats.hintsUsed.toString()),
        ],
      ),
    );
  }

  Widget _buildTopOpenings(BuildContext context, StatisticsModel stats) {
    final sortedOpenings = stats.openingsPlayed.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final topOpenings = sortedOpenings.take(5).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Most Played Openings',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          ...topOpenings.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      entry.key,
                      style: Theme.of(context).textTheme.bodyMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${entry.value} games',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.bar_chart, size: 48, color: AppTheme.textHint),
            const SizedBox(height: 12),
            Text(message, style: const TextStyle(color: AppTheme.textHint)),
          ],
        ),
      ),
    );
  }

  Color _getWinRateColor(double winRate) {
    if (winRate >= 60) return Colors.green;
    if (winRate >= 40) return Colors.amber;
    return Colors.red;
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }
}

/// Stat card widget
class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String value;

  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 28),
          const SizedBox(height: 12),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(title, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

/// Legend item for pie chart
class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final int value;

  const _LegendItem({
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 8),
        Text('$label: $value'),
      ],
    );
  }
}

/// Stat item widget
class _StatItem extends StatelessWidget {
  final String label;
  final String value;

  const _StatItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

/// Detail row widget
class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
          ),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
