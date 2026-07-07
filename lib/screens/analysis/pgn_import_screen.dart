import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chess_master/core/theme/app_theme.dart';
import 'package:chess_master/screens/analysis/analysis_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:chess/chess.dart' as chess;
import 'package:chess_master/models/game_model.dart';

/// PGN import screen updated for Material 3 and better UX
class PgnImportScreen extends ConsumerStatefulWidget {
  const PgnImportScreen({super.key});

  @override
  ConsumerState<PgnImportScreen> createState() => _PgnImportScreenState();
}

class _PgnImportScreenState extends ConsumerState<PgnImportScreen> {
  final TextEditingController _pgnController = TextEditingController();
  String? _errorMessage;
  bool _isParsing = false;

  @override
  void dispose() {
    _pgnController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Import PGN',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Paste your PGN',
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Analyze games from any chess platform. Paste the PGN string below.',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),

              // PGN input
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.cardDark,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color:
                          _errorMessage != null
                              ? AppTheme.error
                              : AppTheme.borderColor,
                    ),
                  ),
                  child: TextField(
                    controller: _pgnController,
                    maxLines: null,
                    expands: true,
                    style: GoogleFonts.spaceMono(
                      fontSize: 13,
                      color: AppTheme.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText:
                          '[Event "Casual Game"]\n[Site "?"]\n[Date "2024.01.01"]\n...\n\n1. e4 e5 2. Nf3 Nc6 ...',
                      hintStyle: GoogleFonts.spaceMono(
                        fontSize: 13,
                        color: AppTheme.textHint,
                      ),
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.error.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: AppTheme.error,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: AppTheme.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Analyze button
              FilledButton.icon(
                onPressed: _isParsing ? null : _analyzePgn,
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon:
                    _isParsing
                        ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                        : const Icon(Icons.analytics),
                label: Text(
                  _isParsing ? 'Parsing...' : 'Analyze Game',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _analyzePgn() async {
    final pgn = _pgnController.text.trim();

    if (pgn.isEmpty) {
      setState(() {
        _errorMessage = 'Please paste a PGN';
      });
      return;
    }

    setState(() {
      _isParsing = true;
      _errorMessage = null;
    });

    // Parse PGN to extract moves in an isolate
    final moves = await compute(_parsePgnToMoves, pgn);

    if (!mounted) return;

    setState(() {
      _isParsing = false;
    });

    if (moves == null || moves.isEmpty) {
      setState(() {
        _errorMessage = 'Invalid or empty PGN format.';
      });
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => AnalysisScreen(moves: moves)),
    );
  }

  static List<ChessMove>? _parsePgnToMoves(String pgn) {
    try {
      final tempBoard = chess.Chess();
      if (!tempBoard.load_pgn(pgn)) return null;

      final history = tempBoard.getHistory();
      if (history.isEmpty) return null;

      final moves = <ChessMove>[];
      final replayBoard = chess.Chess();

      for (var h in history) {
        final san = h.toString(); // SAN string
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
