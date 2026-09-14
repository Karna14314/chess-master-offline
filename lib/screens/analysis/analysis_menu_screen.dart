import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:chess_master/core/theme/app_theme.dart';
import 'package:chess_master/screens/analysis/analysis_screen.dart';
import 'package:chess_master/screens/analysis/pgn_import_screen.dart';
import 'package:chess_master/data/repositories/game_session_repository.dart';
import 'package:chess_master/models/game_session.dart';
import 'package:chess_master/core/constants/app_constants.dart';
import 'package:chess_master/providers/game_session_viewmodel.dart';
import 'package:chess_master/widgets/shared/app_card.dart';
import 'package:chess_master/widgets/shared/app_badge.dart';
import 'package:chess_master/widgets/shared/mini_board.dart';
import 'package:chess_master/screens/history/game_history_screen.dart';

/// Enhanced analysis menu screen matching the new requirements
class AnalysisMenuScreen extends ConsumerWidget {
  const AnalysisMenuScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gameSession = ref.watch(gameSessionProvider);
    final hasActiveGame =
        gameSession != null && gameSession.moveHistory.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
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
                      color: AppTheme.textSecondaryFor(context),
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
                                  moves: gameSession.moveHistory,
                                  startingFen: gameSession.startingFen,
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
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const GameHistoryScreen(),
                            ),
                          );
                        },
                        child: Text(
                          'View Full History',
                          style: TextStyle(
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.w600,
                          ),
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
                            color: AppTheme.textHintFor(
                              context,
                            ).withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No analyzed games yet',
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              color: AppTheme.textSecondaryFor(context),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Play a game or import a PGN to get started.',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: AppTheme.textHintFor(context),
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
          color: AppTheme.textPrimaryFor(context),
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
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppTheme.space16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppTheme.space12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: AppTheme.space16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimaryFor(context),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppTheme.textSecondaryFor(context),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppTheme.space8),
          Icon(
            Icons.chevron_right_rounded,
            color: AppTheme.textHintFor(context),
            size: 24,
          ),
        ],
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

    // Determine badge color and icon for result
    final Color badgeColor;
    final IconData badgeIcon;
    final lower = result.toLowerCase();
    if (lower.contains('win') || lower.contains('won')) {
      badgeColor = AppTheme.emeraldGreen;
      badgeIcon = Icons.check_circle_outline_rounded;
    } else if (lower.contains('loss') || lower.contains('lost')) {
      badgeColor = AppTheme.crimsonRed;
      badgeIcon = Icons.cancel_outlined;
    } else if (lower.contains('draw')) {
      badgeColor = AppTheme.amberGold;
      badgeIcon = Icons.remove_circle_outline_rounded;
    } else {
      badgeColor = AppTheme.royalBlue;
      badgeIcon = Icons.info_outline_rounded;
    }

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppTheme.space16),
      child: Row(
        children: [
          MiniBoard(
            fen: game.startingFen,
            size: 52,
            isFlipped: game.isFlipped,
            borderRadius: AppTheme.radiusSm,
          ),
          const SizedBox(width: AppTheme.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isHuman ? 'Human Game' : 'vs $opponent',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimaryFor(context),
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    AppBadge.status(label: result, color: badgeColor, icon: badgeIcon),
                    Text(
                      '• ${game.moveHistory.length} moves',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppTheme.textSecondaryFor(context),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (game.whiteAccuracy != null)
                Text(
                  '${game.whiteAccuracy!.toStringAsFixed(1)}%',
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
                  fontSize: 11,
                  color: AppTheme.textHintFor(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getAccuracyColor(double accuracy) {
    if (accuracy >= 90) return AppTheme.royalBlue;
    if (accuracy >= 80) return AppTheme.emeraldGreen;
    if (accuracy >= 70) return AppTheme.amberGold;
    if (accuracy >= 50) return Colors.orange;
    return AppTheme.crimsonRed;
  }
}
