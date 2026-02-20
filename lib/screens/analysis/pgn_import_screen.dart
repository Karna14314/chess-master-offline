import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chess_master/core/theme/app_theme.dart';
import 'package:chess_master/screens/analysis/analysis_screen.dart';
import 'package:google_fonts/google_fonts.dart';

/// PGN import screen for analysis
class PgnImportScreen extends ConsumerStatefulWidget {
  const PgnImportScreen({super.key});

  @override
  ConsumerState<PgnImportScreen> createState() => _PgnImportScreenState();
}

class _PgnImportScreenState extends ConsumerState<PgnImportScreen> {
  final TextEditingController _pgnController = TextEditingController();
  String? _errorMessage;

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
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Paste PGN',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Paste your game in PGN format below',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 16),

            // PGN input
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.cardDark,
                  borderRadius: BorderRadius.circular(12),
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
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.error.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: AppTheme.error,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: AppTheme.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Analyze button
            ElevatedButton(
              onPressed: _analyzePgn,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Analyze Game',
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
    );
  }

  void _analyzePgn() {
    final pgn = _pgnController.text.trim();

    if (pgn.isEmpty) {
      setState(() {
        _errorMessage = 'Please paste a PGN';
      });
      return;
    }

    // TODO: Parse PGN and extract moves
    // For now, just navigate to analysis screen
    setState(() {
      _errorMessage = null;
    });

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const AnalysisScreen()),
    );
  }
}
