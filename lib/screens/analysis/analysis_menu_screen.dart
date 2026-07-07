import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:chess_master/core/theme/app_theme.dart';
import 'package:chess_master/screens/analysis/analysis_screen.dart';
import 'package:chess_master/screens/analysis/pgn_import_screen.dart';
import 'package:chess_master/data/repositories/game_session_repository.dart';
import 'package:chess_master/models/game_session.dart';
import 'package:chess_master/core/constants/app_constants.dart';
import 'package:chess_master/providers/game_provider.dart';

/// Enhanced analysis menu screen matching the new requirements
class AnalysisMenuScreen extends ConsumerWidget {
  const AnalysisMenuScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeGame = ref.watch(gameProvider);
    final hasActiveGame =
        activeGame.gameMode != GameMode.analysis &&
        activeGame.gameMode != GameMode.puzzle &&
        activeGame.moveHistory.isNotEmpty;

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceDark,
        elevation: 0,
        title: Text(
          'Game Analysis',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Analyze your games using Stockfish.',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 24),

                  if (hasActiveGame) ...[
                    _SectionHeader(title: 'Current Game'),
                    _AnalysisOptionCard(
                      title: 'Analyze Current Game',
                      subtitle: 'Review your ongoing or recently finished game',
                      icon: Icons.grid_on_outlined,
                      color: AppTheme.primaryColor,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) => AnalysisScreen(
                                  moves: activeGame.moveHistory,
                                  startingFen:
                                      'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
                                ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                  ],

                  _SectionHeader(title: 'Import'),
                  _AnalysisOptionCard(
                    title: 'Import PGN',
                    subtitle:
                        'Analyze games from any chess platform. Supports .pgn files.',
                    icon: Icons.upload_file_outlined,
                    color: Colors.purpleAccent,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const PgnImportScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 32),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _SectionHeader(title: 'Recent Analyses'),
                      TextButton(
                        onPressed: () {
                          // Could navigate to a full history screen here, but
                          // the main history screen is already accessible via the main nav.
                          // For now, this could just show more items in the list.
                        },
                        child: Text(
                          'View Full History',
                          style: TextStyle(color: AppTheme.primaryColor),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // History list
          FutureBuilder<List<GameSession>>(
            future: ref
                .read(gameSessionRepositoryProvider)
                .getRealGamesHistory(limit: 5),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ),
                );
              }

              final games = snapshot.data ?? [];

              if (games.isEmpty) {
                return SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 48.0,
                      horizontal: 16.0,
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.query_stats_outlined,
                            size: 64,
                            color: AppTheme.textHint.withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No analyzed games yet',
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              color: AppTheme.textSecondary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Play a game or import a PGN to get started.',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: AppTheme.textHint,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }

              return SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final game = games[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 6.0,
                    ),
                    child: _SavedGameCard(
                      game: game,
                      onTap: () => _analyzeGameSession(context, game),
                    ),
                  );
                }, childCount: games.length),
              );
            },
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }

  void _analyzeGameSession(BuildContext context, GameSession session) {
    if (session.moveHistory.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No moves available for this game.')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => AnalysisScreen(
              moves: session.moveHistory,
              startingFen: session.startingFen,
            ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: AppTheme.textPrimary,
        ),
      ),
    );
  }
}

class _AnalysisOptionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _AnalysisOptionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.cardDark,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.borderColor),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: AppTheme.textHint, size: 28),
            ],
          ),
        ),
      ),
    );
  }
}

class _SavedGameCard extends StatelessWidget {
  final GameSession game;
  final VoidCallback onTap;

  const _SavedGameCard({required this.game, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dateStr = game.startedAt.toString().split(' ')[0];
    final result = game.result?.displayName ?? 'Ongoing';

    String opponent;
    bool isHuman = false;

    if (game.gameMode == GameMode.localMultiplayer) {
      opponent = 'Local Game';
      isHuman = true;
    } else if (game.gameMode == GameMode.bot) {
      opponent =
          game.whitePlayerName.contains('Bot')
              ? game.whitePlayerName
              : game.blackPlayerName;
    } else {
      opponent = 'Unknown';
    }

    final accuracyText =
        game.whiteAccuracy != null
            ? '${game.whiteAccuracy!.toStringAsFixed(1)}%'
            : '-';

    // Determine the color played if possible
    Color iconColor = AppTheme.primaryColor;
    if (game.gameMode == GameMode.bot) {
      iconColor =
          game.playerColor == PlayerColor.white
              ? Colors.white
              : Colors.grey[400]!;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.cardDark,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.borderColor),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceDark,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isHuman ? Icons.person_outline : Icons.smart_toy_outlined,
                  color: iconColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isHuman ? 'Human Game' : 'vs $opponent',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$result • ${game.moveHistory.length} moves',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (game.whiteAccuracy != null)
                    Text(
                      accuracyText,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: _getAccuracyColor(game.whiteAccuracy!),
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    dateStr,
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
      ),
    );
  }

  Color _getAccuracyColor(double accuracy) {
    if (accuracy >= 90) return Colors.blue;
    if (accuracy >= 80) return Colors.green;
    if (accuracy >= 70) return Colors.yellow;
    if (accuracy >= 50) return Colors.orange;
    return Colors.red;
  }
}
