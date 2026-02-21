import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chess_master/core/theme/app_theme.dart';
import 'package:chess_master/core/services/database_service.dart';
import 'package:chess_master/screens/analysis/analysis_screen.dart';
import 'package:chess_master/screens/analysis/pgn_import_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:chess/chess.dart' as chess;
import 'package:chess_master/models/game_model.dart';

/// Analysis menu - choose between PGN import or saved games
class AnalysisMenuScreen extends ConsumerWidget {
  const AnalysisMenuScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Game Analysis',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Text(
              'Choose Analysis Source',
              style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Analyze your games with Stockfish engine',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 32),

            // Import PGN option
            _AnalysisOptionCard(
              title: 'Import PGN',
              subtitle: 'Paste or import a PGN file',
              icon: Icons.upload_file,
              color: AppTheme.primaryColor,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PgnImportScreen(),
                  ),
                );
              },
            ),

            const SizedBox(height: 16),

            // Saved games option
            _AnalysisOptionCard(
              title: 'Saved Games',
              subtitle: 'Analyze your previous games',
              icon: Icons.history,
              color: AppTheme.secondaryColor,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SavedGamesListScreen(),
                  ),
                );
              },
            ),

            const Spacer(),

            // Info card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.cardDark,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: AppTheme.primaryColor,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Analysis uses Stockfish 16 to evaluate moves and suggest improvements',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withOpacity(0.2), color.withOpacity(0.05)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
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
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: color, size: 28),
          ],
        ),
      ),
    );
  }
}

/// Saved games list for analysis
class SavedGamesListScreen extends ConsumerWidget {
  const SavedGamesListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseServiceProvider);

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Saved Games',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: db.getAllGames(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor),
            );
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.inbox_outlined,
                    size: 64,
                    color: AppTheme.textHint,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No saved games',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Play some games first!',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: AppTheme.textHint,
                    ),
                  ),
                ],
              ),
            );
          }

          final games = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: games.length,
            itemBuilder: (context, index) {
              final game = games[index];
              return _SavedGameCard(
                game: game,
                onTap: () => _analyzeGame(context, game),
              );
            },
          );
        },
      ),
    );
  }

  void _analyzeGame(BuildContext context, Map<String, dynamic> game) {
    final pgn = game['pgn'] as String?;
    if (pgn == null || pgn.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No PGN data available for this game.')),
      );
      return;
    }

    final moves = _parsePgnToMoves(pgn);
    if (moves == null || moves.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to parse the game moves from PGN.'),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AnalysisScreen(moves: moves)),
    );
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

class _SavedGameCard extends StatelessWidget {
  final Map<String, dynamic> game;
  final VoidCallback onTap;

  const _SavedGameCard({required this.game, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final createdAt = game['created_at'] as int?;
    final dateStr =
        createdAt != null
            ? DateTime.fromMillisecondsSinceEpoch(
              createdAt,
            ).toString().split(' ')[0]
            : 'Unknown date';

    final result = game['result'] as String? ?? 'Ongoing';

    // Determine opponent label based on game mode or custom name
    final customName = game['custom_name'] as String?;
    final gameMode = game['game_mode'] as String? ?? 'bot';
    final botElo = game['bot_elo'] as int? ?? 1200;

    final opponent =
        customName ?? (gameMode == 'local' ? 'Friend' : 'Bot ($botElo)');

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
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
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.analytics_outlined,
                color: AppTheme.primaryColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'vs $opponent',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$result • $dateStr',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
          ],
        ),
      ),
    );
  }
}
