import 'package:flutter/material.dart';
import 'package:chess_master/core/theme/app_theme.dart';
import 'package:chess_master/core/models/chess_models.dart';
import 'package:google_fonts/google_fonts.dart';

class EngineRecommendations extends StatefulWidget {
  final List<EngineLine> lines;
  final bool isLoading;

  const EngineRecommendations({
    super.key,
    required this.lines,
    this.isLoading = false,
  });

  @override
  State<EngineRecommendations> createState() => _EngineRecommendationsState();
}

class _EngineRecommendationsState extends State<EngineRecommendations> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    if (widget.lines.isEmpty && !widget.isLoading) {
      return const SizedBox.shrink();
    }

    final displayLines =
        _expanded ? widget.lines : widget.lines.take(1).toList();
    final currentDepth = widget.lines.isNotEmpty ? widget.lines.first.depth : 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(
                  Icons.memory_rounded,
                  size: 20,
                  color: AppTheme.primaryColor,
                ),
                const SizedBox(width: 8),
                Text(
                  'Engine Analysis',
                  style: GoogleFonts.inter(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const Spacer(),
                if (widget.isLoading) ...[
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Text(
                  'Depth $currentDepth',
                  style: GoogleFonts.inter(
                    color: AppTheme.textHint,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppTheme.surfaceDark),

          // Lines
          if (widget.lines.isEmpty && widget.isLoading)
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Center(
                child: Text(
                  'Analyzing position...',
                  style: GoogleFonts.inter(color: AppTheme.textHint),
                ),
              ),
            )
          else
            ...displayLines.map((line) => _EngineLineRow(line: line)),

          // Expand / Collapse button
          if (widget.lines.length > 1)
            InkWell(
              onTap: () {
                setState(() {
                  _expanded = !_expanded;
                });
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: Text(
                    _expanded ? 'Show Less' : 'Show More',
                    style: GoogleFonts.inter(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _EngineLineRow extends StatelessWidget {
  final EngineLine line;

  const _EngineLineRow({required this.line});

  @override
  Widget build(BuildContext context) {
    final isPositive =
        line.isMate ? (line.mateIn ?? 0) > 0 : line.evaluation >= 0;

    final evalColor = isPositive ? Colors.white : Colors.black;
    final evalBgColor = isPositive ? const Color(0xFF303030) : Colors.white;

    final moveList = line.sanMoves ?? line.moves;
    final bestMove = moveList.isNotEmpty ? moveList.first : '';
    final continuation =
        moveList.length > 1 ? moveList.skip(1).take(5).join(' ') : '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppTheme.surfaceDark, width: 1),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Eval Badge
          Container(
            width: 48,
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: evalBgColor,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: Center(
              child: Text(
                line.evalDisplay,
                style: GoogleFonts.spaceMono(
                  color: evalColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Moves
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bestMove,
                  style: GoogleFonts.spaceMono(
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                if (continuation.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    continuation,
                    style: GoogleFonts.spaceMono(
                      color: AppTheme.textHint,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
