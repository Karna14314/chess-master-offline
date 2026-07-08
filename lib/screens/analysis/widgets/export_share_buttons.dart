import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:chess_master/core/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';

class ExportShareButtons extends StatelessWidget {
  final String pgn;
  final String fen;

  const ExportShareButtons({super.key, required this.pgn, required this.fen});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Export & Share',
            style: GoogleFonts.inter(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _ExportButton(
                icon: Icons.copy_all_rounded,
                label: 'Copy PGN',
                onTap: () {
                  Clipboard.setData(ClipboardData(text: pgn));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('PGN copied to clipboard!')),
                  );
                },
              ),
              _ExportButton(
                icon: Icons.code_rounded,
                label: 'Copy FEN',
                onTap: () {
                  Clipboard.setData(ClipboardData(text: fen));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('FEN copied to clipboard!')),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ExportButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ExportButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.surfaceDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.borderColor),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppTheme.primaryColor, size: 24),
            const SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.inter(
                color: AppTheme.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
