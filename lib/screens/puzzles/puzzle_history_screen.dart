import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:chess_master/core/theme/app_theme.dart';
import 'package:chess_master/core/services/database_service.dart';
import 'package:chess_master/providers/puzzle_provider.dart';
import 'package:chess_master/screens/puzzles/puzzle_screen.dart';

final puzzleHistoryProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
      final db = ref.watch(databaseServiceProvider);
      return await db.getPuzzleHistory(limit: 50);
    });

class PuzzleHistoryScreen extends ConsumerWidget {
  const PuzzleHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(puzzleHistoryProvider);
    final statsAsync = ref.watch(puzzleStatsProvider);

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        title: Text(
          'Puzzle History',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: historyAsync.when(
        loading:
            () => const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor),
            ),
        error:
            (error, _) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 48,
                    color: AppTheme.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading puzzle history',
                    style: GoogleFonts.inter(color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => ref.invalidate(puzzleHistoryProvider),
                    child: const Text('Try Again'),
                  ),
                ],
              ),
            ),
        data: (history) {
          if (history.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.history_toggle_off,
                    size: 64,
                    color: AppTheme.textHint.withOpacity(0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No puzzles played yet',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Puzzles you tackle will appear here',
                    style: GoogleFonts.inter(color: AppTheme.textHint),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: _buildStatsCard(statsAsync),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: history.length,
                  itemBuilder: (context, index) {
                    final puzzle = history[index];
                    return _PuzzleHistoryCard(puzzleData: puzzle);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatsCard(PuzzleStats stats) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Overall Statistics',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                'Rating', 
                stats.currentRating.toString(), 
                Icons.star, 
                Colors.amber,
              ),
              _buildStatItem(
                'Solved', 
                stats.puzzlesSolved.toString(), 
                Icons.check_circle, 
                Colors.green,
              ),
              _buildStatItem(
                'Success', 
                '${stats.successRate.toStringAsFixed(1)}%', 
                Icons.pie_chart, 
                AppTheme.primaryColor,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: AppTheme.textHint,
          ),
        ),
      ],
    );
  }
}

class _PuzzleHistoryCard extends ConsumerWidget {
  final Map<String, dynamic> puzzleData;

  const _PuzzleHistoryCard({required this.puzzleData});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final puzzleId = puzzleData['puzzle_id'] as int;
    final solved = puzzleData['solved'] == 1;
    final attempts = puzzleData['attempts'] as int? ?? 1;
    final lastAttempted = DateTime.fromMillisecondsSinceEpoch(
      puzzleData['last_attempted'] as int? ?? 0,
    );
    final dateFormat = DateFormat('MMM d, yyyy • h:mm a');

    final color = solved ? Colors.green : AppTheme.error;
    final icon = solved ? Icons.check_circle : Icons.cancel;

    return InkWell(
      onTap: () async {
        final notifier = ref.read(puzzleProvider.notifier);
        await notifier.loadPuzzleById(puzzleId);
        
        if (context.mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PuzzleScreen(puzzleId: puzzleId),
            ),
          );
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.cardDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Puzzle #$puzzleId',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    dateFormat.format(lastAttempted),
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppTheme.textHint,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  solved ? 'Solved' : 'Failed',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$attempts attempt${attempts == 1 ? '' : 's'}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppTheme.textHint,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
