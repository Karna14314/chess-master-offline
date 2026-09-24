import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:chess_master/core/theme/app_theme.dart';
import 'package:chess_master/core/constants/app_constants.dart';
import 'package:chess_master/models/bot_profile.dart';
import 'package:chess_master/providers/bot_progress_provider.dart';
import 'package:chess_master/providers/game_session_viewmodel.dart';
import 'package:chess_master/screens/game/game_screen.dart';
import 'package:chess_master/widgets/shared/app_card.dart';
import 'package:chess_master/widgets/shared/bot_avatar.dart';

/// Modal bottom sheet displaying detailed bot personality and match options
class BotProfileSheet extends ConsumerStatefulWidget {
  final BotProfile bot;
  final int? campaignLevel;

  const BotProfileSheet({super.key, required this.bot, this.campaignLevel});

  static Future<void> show(
    BuildContext context,
    BotProfile bot, {
    int? campaignLevel,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          BotProfileSheet(bot: bot, campaignLevel: campaignLevel),
    );
  }

  @override
  ConsumerState<BotProfileSheet> createState() => _BotProfileSheetState();
}

class _BotProfileSheetState extends ConsumerState<BotProfileSheet> {
  PlayerColor _selectedColor = PlayerColor.white;
  HandicapMode _selectedHandicap = HandicapMode.none;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final botState = ref.watch(botProgressProvider);
    final stats = botState.getStatsFor(widget.bot.id);
    final textPrimary = AppTheme.textPrimaryFor(context);
    final textSecondary = AppTheme.textSecondaryFor(context);
    final tierColor = widget.bot.tier.color;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardColor(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: AppTheme.borderColorFor(context), width: 1),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Drag handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),

            // Bot Avatar & Glowing Ring
            BotAvatar(
              bot: widget.bot,
              size: 80,
              stars: stats.bestStars,
              showElo: false,
              animateGlow: true,
            ),
            const SizedBox(height: 10),

            // Bot Name & Tier
            Text(
              widget.bot.name,
              style: GoogleFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 4),

            // ELO Pill & Tier Badge
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: tierColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: tierColor.withValues(alpha: 0.6)),
                  ),
                  child: Text(
                    '${widget.bot.tier.displayName} • ${widget.bot.elo} ELO',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: tierColor,
                    ),
                  ),
                ),
                if (stats.bestStars > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber.withValues(alpha: 0.6)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star_rounded,
                            size: 14, color: Colors.amber),
                        const SizedBox(width: 4),
                        Text(
                          '${stats.bestStars}/3 Stars',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.amber,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),

            // Bot Quote Bubble
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.black.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                '"${widget.bot.quote}"',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                  color: textSecondary,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Style Tags
            Wrap(
              spacing: 6,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              children: widget.bot.styleTags.map((tag) {
                return Chip(
                  label: Text(
                    tag,
                    style: GoogleFonts.inter(fontSize: 11, color: textPrimary),
                  ),
                  backgroundColor: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.06),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Head to Head Stats Card
            AppCard(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem('Wins', '${stats.wins}', Colors.green),
                  _buildStatItem('Draws', '${stats.draws}', Colors.orange),
                  _buildStatItem('Losses', '${stats.losses}', Colors.red),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Match Configuration Options
            _buildSectionLabel('Choose Your Color', textPrimary),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildColorOption(
                    PlayerColor.white,
                    'White',
                    Icons.circle,
                    Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildColorOption(
                    PlayerColor.random,
                    'Random',
                    Icons.shuffle,
                    Colors.purpleAccent,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildColorOption(
                    PlayerColor.black,
                    'Black',
                    Icons.circle,
                    Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),



            _buildSectionLabel('Handicap Mode (Odds)', textPrimary),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: HandicapMode.values.map((mode) {
                  final isSelected = _selectedHandicap == mode;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(mode.displayName),
                      selected: isSelected,
                      onSelected: (_) =>
                          setState(() => _selectedHandicap = mode),
                      selectedColor: AppTheme.primaryColor,
                      labelStyle: GoogleFonts.inter(
                        color: isSelected ? Colors.white : textPrimary,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 12,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 20),

            // Big Play Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _startMatch,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 4,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.play_arrow_rounded, size: 28),
                    const SizedBox(width: 8),
                    Text(
                      'PLAY VS ${widget.bot.name.toUpperCase()}',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String label, Color color) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildColorOption(
    PlayerColor color,
    String label,
    IconData icon,
    Color iconColor,
  ) {
    final isSelected = _selectedColor == color;
    return OutlinedButton(
      onPressed: () => setState(() => _selectedColor = color),
      style: OutlinedButton.styleFrom(
        backgroundColor:
            isSelected ? AppTheme.primaryColor.withValues(alpha: 0.15) : null,
        side: BorderSide(
          color: isSelected
              ? AppTheme.primaryColor
              : Colors.grey.withValues(alpha: 0.3),
          width: isSelected ? 2 : 1,
        ),
        padding: const EdgeInsets.symmetric(vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: iconColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected
                  ? AppTheme.primaryColor
                  : AppTheme.textPrimaryFor(context),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _startMatch() async {
    final navigator = Navigator.of(context);
    navigator.pop();

    final viewModel = ref.read(gameSessionProvider.notifier);
    final botIsBlack = _selectedColor != PlayerColor.black;
    final handicapFen = _selectedHandicap.getStartingFen(botIsBlack: botIsBlack);

    await viewModel.startNewGame(
      gameMode: GameMode.bot,
      botType: widget.bot.engineType,
      difficulty: widget.bot.difficultyLevel,
      timeControl: AppConstants.timeControls[0], // Bots strictly play untimed
      playerColor: _selectedColor,
      startingFen: handicapFen,
      botProfile: widget.bot,
      campaignLevel: widget.campaignLevel,
    );

    if (!navigator.mounted) return;
    navigator.push(
      MaterialPageRoute(builder: (context) => const GameScreen()),
    );
  }
}
