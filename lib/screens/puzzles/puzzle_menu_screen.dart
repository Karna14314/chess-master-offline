import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chess_master/core/theme/app_theme.dart';
import 'package:chess_master/providers/puzzle_provider.dart';
import 'package:chess_master/screens/puzzles/puzzle_screen.dart';

/// Puzzle mode selection
enum PuzzleMode {
  adaptive,   // Based on current rating
  daily,      // Daily puzzle
  random,     // Random puzzles
  eloRange,   // Specific ELO range
  theme,      // By theme
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
        backgroundColor: AppTheme.surfaceDark,
        title: const Text('Puzzles'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Stats card
            statsAsync.when(
              data: (stats) => _StatsCard(stats: stats),
              loading: () => const _StatsCardLoading(),
              error: (_, __) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 24),

            // Quick play section
            const Text(
              'Quick Play',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _QuickPlayCard(
              icon: Icons.calendar_today,
              title: 'Daily Puzzle',
              subtitle: 'New challenge every day',
              color: Colors.orange,
              onTap: () => _startPuzzles(PuzzleMode.daily),
            ),
            const SizedBox(height: 8),
            _QuickPlayCard(
              icon: Icons.auto_awesome,
              title: 'Adaptive',
              subtitle: 'Puzzles matched to your rating',
              color: AppTheme.primaryColor,
              onTap: () => _startPuzzles(PuzzleMode.adaptive),
            ),
            const SizedBox(height: 8),
            _QuickPlayCard(
              icon: Icons.shuffle,
              title: 'Random',
              subtitle: 'Any puzzle from our 5000+ collection',
              color: Colors.purple,
              onTap: () => _startPuzzles(PuzzleMode.random),
            ),
            const SizedBox(height: 24),

            // Custom ELO range
            const Text(
              'Custom Rating Range',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _EloRangeSelector(
              minElo: _minElo,
              maxElo: _maxElo,
              onMinChanged: (v) => setState(() => _minElo = v),
              onMaxChanged: (v) => setState(() => _maxElo = v),
              onStart: () => _startPuzzles(PuzzleMode.eloRange),
            ),
            const SizedBox(height: 24),

            // Theme selection
            const Text(
              'By Theme',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 18,
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
    );
  }

  void _startPuzzles(PuzzleMode mode) {
    final notifier = ref.read(puzzleProvider.notifier);
    
    // Configure based on mode
    switch (mode) {
      case PuzzleMode.adaptive:
        notifier.setModeConfig(mode: PuzzleFilterMode.adaptive);
        break;
      case PuzzleMode.daily:
        notifier.setModeConfig(mode: PuzzleFilterMode.daily);
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor.withOpacity(0.2),
            AppTheme.primaryColor.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Rating
              Expanded(
                child: Column(
                  children: [
                    const Icon(Icons.star, color: AppTheme.accentColor, size: 32),
                    const SizedBox(height: 8),
                    Text(
                      '${stats.currentRating}',
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text(
                      'Rating',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Container(
                width: 1,
                height: 60,
                color: AppTheme.textHint.withOpacity(0.3),
              ),
              // Solved
              Expanded(
                child: Column(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green, size: 32),
                    const SizedBox(height: 8),
                    Text(
                      '${stats.puzzlesSolved}',
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text(
                      'Solved',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Container(
                width: 1,
                height: 60,
                color: AppTheme.textHint.withOpacity(0.3),
              ),
              // Success rate
              Expanded(
                child: Column(
                  children: [
                    const Icon(Icons.percent, color: Colors.blue, size: 32),
                    const SizedBox(height: 8),
                    Text(
                      '${stats.successRate.toStringAsFixed(0)}%',
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text(
                      'Success',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
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
      child: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}

/// Quick play option card
class _QuickPlayCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _QuickPlayCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.cardDark,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: color),
            ],
          ),
        ),
      ),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Min Rating',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$minElo',
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward, color: AppTheme.textHint),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'Max Rating',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$maxElo',
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          RangeSlider(
            values: RangeValues(minElo.toDouble(), maxElo.toDouble()),
            min: 400,
            max: 2500,
            divisions: 21,
            labels: RangeLabels('$minElo', '$maxElo'),
            activeColor: AppTheme.primaryColor,
            inactiveColor: AppTheme.surfaceDark,
            onChanged: (values) {
              onMinChanged(values.start.round());
              onMaxChanged(values.end.round());
            },
          ),
          const SizedBox(height: 8),
          // Preset buttons
          Wrap(
            spacing: 8,
            children: [
              _PresetButton(
                label: 'Beginner',
                onTap: () {
                  onMinChanged(400);
                  onMaxChanged(1000);
                },
              ),
              _PresetButton(
                label: 'Intermediate',
                onTap: () {
                  onMinChanged(1000);
                  onMaxChanged(1500);
                },
              ),
              _PresetButton(
                label: 'Advanced',
                onTap: () {
                  onMinChanged(1500);
                  onMaxChanged(2000);
                },
              ),
              _PresetButton(
                label: 'Expert',
                onTap: () {
                  onMinChanged(2000);
                  onMaxChanged(2500);
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onStart,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PresetButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _PresetButton({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label),
      onPressed: onTap,
      backgroundColor: AppTheme.surfaceDark,
      labelStyle: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: themes.map((theme) {
              final isSelected = theme == selectedTheme;
              return ChoiceChip(
                label: Text(_formatTheme(theme)),
                selected: isSelected,
                onSelected: (_) => onThemeSelected(theme),
                selectedColor: AppTheme.primaryColor,
                backgroundColor: AppTheme.surfaceDark,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : AppTheme.textSecondary,
                  fontSize: 12,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onStart,
              icon: const Icon(Icons.play_arrow),
              label: Text('Play ${_formatTheme(selectedTheme)} Puzzles'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTheme(String theme) {
    if (theme == 'all') return 'All Themes';
    // Convert camelCase to Title Case
    final words = theme.replaceAllMapped(
      RegExp(r'([A-Z])'),
      (match) => ' ${match.group(1)}',
    );
    return words.trim().split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }
}

