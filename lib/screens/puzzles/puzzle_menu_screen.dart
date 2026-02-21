import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chess_master/core/theme/app_theme.dart';
import 'package:chess_master/providers/puzzle_provider.dart';
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
    final statsAsync = ref.watch(puzzleStatsProvider);

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Puzzles',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history, color: AppTheme.textSecondary),
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
              // Stats card
              statsAsync.when(
                data: (stats) => _StatsCard(stats: stats),
                loading: () => const _StatsCardLoading(),
                error: (error, __) => _StatsCardError(error: error.toString()),
              ),
              const SizedBox(height: 32),

              // Quick play section
              Text(
                'Quick Play',
                style: GoogleFonts.inter(
                  color: AppTheme.textPrimary,
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

              // Custom ELO range
              Text(
                'Custom Range',
                style: GoogleFonts.inter(
                  color: AppTheme.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              _EloRangeSelector(
                minElo: _minElo,
                maxElo: _maxElo,
                onMinChanged: (v) => setState(() => _minElo = v),
                onMaxChanged: (v) => setState(() => _maxElo = v),
                onStart: () => _startPuzzles(PuzzleMode.eloRange),
              ),
              const SizedBox(height: 32),

              // Theme selection
              Text(
                'By Theme',
                style: GoogleFonts.inter(
                  color: AppTheme.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              _ThemeSelector(
                themes: _themes,
                selectedTheme: _selectedTheme,
                onThemeSelected:
                    (theme) => setState(() => _selectedTheme = theme),
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
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          onTap: onTap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          title: Text(
            title,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
              fontSize: 16,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: GoogleFonts.inter(
              color: AppTheme.textSecondary,
              fontSize: 13,
            ),
          ),
          trailing: Icon(
            Icons.chevron_right,
            color: AppTheme.textSecondary.withOpacity(0.5),
          ),
        ),
      ),
    );
  }

  void _startPuzzles(PuzzleMode mode) {
    final notifier = ref.read(puzzleProvider.notifier);

    // Configure based on mode
    switch (mode) {
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

/// Stats card showing puzzle progress
class _StatsCard extends StatelessWidget {
  final PuzzleStats stats;

  const _StatsCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.05),
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
          Container(width: 1, height: 40, color: AppTheme.borderColor),
          _buildStatItem(
            context,
            icon: Icons.check_circle_outline,
            value: '${stats.puzzlesSolved}',
            label: 'Solved',
            color: Colors.green,
          ),
          Container(width: 1, height: 40, color: AppTheme.borderColor),
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
            color: AppTheme.textPrimary,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _StatsCardLoading extends StatelessWidget {
  const _StatsCardLoading();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(16),
      ),
      height: 120,
      child: const Center(child: CircularProgressIndicator()),
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
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$minElo',
                style: GoogleFonts.inter(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Text(
                'Rating Range',
                style: GoogleFonts.inter(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                ),
              ),
              Text(
                '$maxElo',
                style: GoogleFonts.inter(
                  color: AppTheme.textPrimary,
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
            inactiveColor: AppTheme.surfaceDark,
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
                      backgroundColor: AppTheme.cardDark,
                      disabledColor: AppTheme.cardDark,
                      labelStyle: GoogleFonts.inter(
                        color:
                            isSelected ? Colors.white : AppTheme.textSecondary,
                        fontSize: 12,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                      shape: RoundedRectangleBorder(
                        side: BorderSide(
                          color:
                              isSelected
                                  ? Colors.transparent
                                  : AppTheme.borderColor,
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

class _StatsCardError extends StatelessWidget {
  final String error;

  const _StatsCardError({required this.error});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.error.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          const Icon(Icons.error_outline, color: AppTheme.error, size: 36),
          const SizedBox(height: 12),
          Text(
            'Failed to load stats',
            style: GoogleFonts.inter(
              color: AppTheme.error,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            error,
            style: GoogleFonts.inter(color: AppTheme.textHint, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
