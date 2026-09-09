import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chess_master/core/theme/app_theme.dart';
import 'package:chess_master/providers/puzzle_provider.dart';
import 'package:chess_master/providers/journey_provider.dart';
import 'package:chess_master/screens/puzzles/puzzle_screen.dart';
import 'package:chess_master/screens/puzzles/daily_puzzle_screen.dart';
import 'package:chess_master/screens/puzzles/puzzle_history_screen.dart';
import 'package:google_fonts/google_fonts.dart';

/// Puzzle mode selection
enum PuzzleMode {
  adaptive, // Based on current rating
  daily, // Daily puzzle
  random, // Random puzzles
  eloRange, // Specific ELO range
  theme, // By theme
  journey, // Puzzle Journey progression
}

/// Puzzle menu screen for selecting puzzle mode
class PuzzleMenuScreen extends ConsumerStatefulWidget {
  const PuzzleMenuScreen({super.key});

  @override
  ConsumerState<PuzzleMenuScreen> createState() => _PuzzleMenuScreenState();
}

class _PuzzleMenuScreenState extends ConsumerState<PuzzleMenuScreen> {
  int _minElo = 800;
  int _maxElo = 1600;
  String _selectedTheme = 'all';

  final List<String> _themes = [
    'all',
    'mateIn1',
    'mateIn2',
    'fork',
    'pin',
    'skewer',
    'discoveredAttack',
    'doubleAttack',
    'deflection',
    'backRankMate',
    'endgame',
    'opening',
  ];

  @override
  Widget build(BuildContext context) {
    final stats = ref.watch(puzzleStatsProvider);
    final journey = ref.watch(journeyProvider);

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Puzzles',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimaryFor(context),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.history, color: AppTheme.textSecondaryFor(context)),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PuzzleHistoryScreen(),
                ),
              );
            },
          ),
        ],
      ),
      extendBodyBehindAppBar: false,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Puzzle Journey hero card at the top
              _JourneyHeroCard(
                journey: journey,
                onContinue: () => _startPuzzles(PuzzleMode.journey),
              ),
              const SizedBox(height: 24),

              // Stats card
              _StatsCard(stats: stats),
              const SizedBox(height: 32),

              // Quick play section
              Text(
                'Quick Play',
                style: GoogleFonts.inter(
                  color: AppTheme.textPrimaryFor(context),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              _buildQuickPlayTile(
                icon: Icons.calendar_today,
                title: 'Daily Puzzle',
                subtitle: 'New challenge every day',
                color: Colors.orange,
                onTap: () => _startPuzzles(PuzzleMode.daily),
              ),
              const SizedBox(height: 12),
              _buildQuickPlayTile(
                icon: Icons.auto_awesome,
                title: 'Adaptive',
                subtitle: 'Matched to your rating',
                color: AppTheme.primaryColor,
                onTap: () => _startPuzzles(PuzzleMode.adaptive),
              ),
              const SizedBox(height: 12),
              _buildQuickPlayTile(
                icon: Icons.shuffle,
                title: 'Random',
                subtitle: 'Any puzzle from our collection',
                color: Colors.purple,
                onTap: () => _startPuzzles(PuzzleMode.random),
              ),
              const SizedBox(height: 32),

              // Custom training section
              Text(
                'Custom Training',
                style: GoogleFonts.inter(
                  color: AppTheme.textPrimaryFor(context),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),

              // Rating range selector
              _EloRangeSelector(
                minElo: _minElo,
                maxElo: _maxElo,
                onMinChanged: (val) => setState(() => _minElo = val),
                onMaxChanged: (val) => setState(() => _maxElo = val),
                onStart: () => _startPuzzles(PuzzleMode.eloRange),
              ),
              const SizedBox(height: 24),

              // Theme selector
              Text(
                'Practice by Theme',
                style: GoogleFonts.inter(
                  color: AppTheme.textPrimaryFor(context),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              _ThemeSelector(
                themes: _themes,
                selectedTheme: _selectedTheme,
                onThemeSelected: (theme) => setState(() => _selectedTheme = theme),
                onStart: () => _startPuzzles(PuzzleMode.theme),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickPlayTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardColor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColorFor(context)),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        title: Text(
          title,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: AppTheme.textPrimaryFor(context),
          ),
        ),
        subtitle: Text(
          subtitle,
          style: GoogleFonts.inter(
            color: AppTheme.textSecondaryFor(context),
            fontSize: 13,
          ),
        ),
        trailing: Icon(
          Icons.chevron_right,
          color: AppTheme.textSecondaryFor(context).withValues(alpha: 0.5),
        ),
      ),
    );
  }

  void _startPuzzles(PuzzleMode mode) {
    final notifier = ref.read(puzzleProvider.notifier);

    // Configure based on mode
    switch (mode) {
      case PuzzleMode.journey:
        notifier.setModeConfig(mode: PuzzleFilterMode.journey);
        break;
      case PuzzleMode.daily:
        notifier.setModeConfig(mode: PuzzleFilterMode.daily);
        // Navigate to special daily puzzle screen
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const DailyPuzzleScreen()),
        );
        return; // Don't continue to regular puzzle screen

      case PuzzleMode.adaptive:
        notifier.setModeConfig(mode: PuzzleFilterMode.adaptive);
        break;
      case PuzzleMode.random:
        notifier.setModeConfig(mode: PuzzleFilterMode.random);
        break;
      case PuzzleMode.eloRange:
        notifier.setModeConfig(
          mode: PuzzleFilterMode.eloRange,
          minRating: _minElo,
          maxRating: _maxElo,
        );
        break;
      case PuzzleMode.theme:
        notifier.setModeConfig(
          mode: PuzzleFilterMode.theme,
          theme: _selectedTheme,
        );
        break;
    }

    // Navigate to regular puzzle screen for non-daily modes
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PuzzleScreen()),
    );
  }
}

/// Puzzle Journey Hero Card at the top of Puzzle menu screen
class _JourneyHeroCard extends StatelessWidget {
  final JourneyState journey;
  final VoidCallback onContinue;

  const _JourneyHeroCard({
    required this.journey,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    final isNotStarted = journey.solvedCount == 0;
    final buttonText = isNotStarted ? 'Start Journey →' : 'Continue Journey →';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardColor(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderColorFor(context)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Puzzle Journey',
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimaryFor(context),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${journey.completionPercent.toStringAsFixed(1)}%',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Level ${journey.currentLevel} / $kTotalJourneyLevels',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimaryFor(context),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceColor(context),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '${journey.solvedCount}',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                      Text(
                        'Solved',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: AppTheme.textSecondaryFor(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceColor(context),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '${journey.remainingCount}',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimaryFor(context),
                        ),
                      ),
                      Text(
                        'Remaining',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: AppTheme.textSecondaryFor(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: journey.completionPercent / 100,
              backgroundColor: AppTheme.borderColorFor(context),
              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onContinue,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                buttonText,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Stats card showing puzzle progress
class _StatsCard extends StatelessWidget {
  final PuzzleStats stats;

  const _StatsCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.borderColorFor(context)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.05),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            context,
            icon: Icons.emoji_events,
            value: '${stats.currentRating}',
            label: 'Rating',
            color: Colors.amber,
          ),
          Container(width: 1, height: 40, color: AppTheme.borderColorFor(context)),
          _buildStatItem(
            context,
            icon: Icons.check_circle_outline,
            value: '${stats.puzzlesSolved}',
            label: 'Solved',
            color: Colors.green,
          ),
          Container(width: 1, height: 40, color: AppTheme.borderColorFor(context)),
          _buildStatItem(
            context,
            icon: Icons.analytics_outlined,
            value: '${stats.successRate.toStringAsFixed(0)}%',
            label: 'Success',
            color: Colors.blue,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context, {
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimaryFor(context),
          ),
        ),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: AppTheme.textSecondaryFor(context),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

/// ELO range selector
class _EloRangeSelector extends StatelessWidget {
  final int minElo;
  final int maxElo;
  final ValueChanged<int> onMinChanged;
  final ValueChanged<int> onMaxChanged;
  final VoidCallback onStart;

  const _EloRangeSelector({
    required this.minElo,
    required this.maxElo,
    required this.onMinChanged,
    required this.onMaxChanged,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardColor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColorFor(context)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$minElo',
                style: GoogleFonts.inter(
                  color: AppTheme.textPrimaryFor(context),
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Text(
                'Rating Range',
                style: GoogleFonts.inter(
                  color: AppTheme.textSecondaryFor(context),
                  fontSize: 12,
                ),
              ),
              Text(
                '$maxElo',
                style: GoogleFonts.inter(
                  color: AppTheme.textPrimaryFor(context),
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          RangeSlider(
            values: RangeValues(minElo.toDouble(), maxElo.toDouble()),
            min: 400,
            max: 2500,
            divisions: 42,
            activeColor: AppTheme.primaryColor,
            inactiveColor: AppTheme.surfaceColor(context),
            onChanged: (values) {
              onMinChanged(values.start.round());
              onMaxChanged(values.end.round());
            },
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onStart,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Start Practice',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Theme selector
class _ThemeSelector extends StatelessWidget {
  final List<String> themes;
  final String selectedTheme;
  final ValueChanged<String> onThemeSelected;
  final VoidCallback onStart;

  const _ThemeSelector({
    required this.themes,
    required this.selectedTheme,
    required this.onThemeSelected,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  themes.map((theme) {
                    final isSelected = theme == selectedTheme;
                    return ChoiceChip(
                      label: Text(_formatTheme(theme)),
                      selected: isSelected,
                      onSelected: (_) => onThemeSelected(theme),
                      selectedColor: AppTheme.primaryColor,
                      backgroundColor: AppTheme.cardColor(context),
                      disabledColor: AppTheme.cardColor(context),
                      labelStyle: GoogleFonts.inter(
                        color:
                            isSelected ? Colors.white : AppTheme.textSecondaryFor(context),
                        fontSize: 12,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                      shape: RoundedRectangleBorder(
                        side: BorderSide(
                          color:
                              isSelected
                                  ? Colors.transparent
                                  : AppTheme.borderColorFor(context),
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                    );
                  }).toList(),
            );
          },
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: onStart,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Start ${_formatTheme(selectedTheme)}',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  String _formatTheme(String theme) {
    if (theme == 'all') return 'All';
    final words = theme.replaceAllMapped(
      RegExp(r'([A-Z])'),
      (match) => ' ${match.group(1)}',
    );
    return words
        .trim()
        .split(' ')
        .map((word) {
          if (word.isEmpty) return word;
          return word[0].toUpperCase() + word.substring(1).toLowerCase();
        })
        .join(' ');
  }
}
