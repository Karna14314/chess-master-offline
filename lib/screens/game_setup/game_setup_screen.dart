import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chess_master/core/constants/app_constants.dart';
import 'package:chess_master/providers/settings_provider.dart';
import 'package:chess_master/providers/game_provider.dart';
import 'package:chess_master/providers/engine_provider.dart';
import 'package:chess_master/widgets/difficulty_selector.dart';
import 'package:chess_master/widgets/timer_selector.dart';
import 'package:chess_master/widgets/color_selector.dart';
import 'package:chess_master/screens/game/game_screen.dart';

/// Game setup screen for configuring a new game
class GameSetupScreen extends ConsumerStatefulWidget {
  const GameSetupScreen({super.key});

  @override
  ConsumerState<GameSetupScreen> createState() => _GameSetupScreenState();
}

class _GameSetupScreenState extends ConsumerState<GameSetupScreen> {
  late int _selectedDifficultyLevel;
  late int _selectedTimeControlIndex;
  late PlayerColor _selectedColor;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Load last used settings
    final settings = ref.read(settingsProvider);
    _selectedDifficultyLevel = settings.lastDifficultyLevel;
    _selectedTimeControlIndex = settings.lastTimeControlIndex;
    _selectedColor = PlayerColor.white;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('New Game'),
        centerTitle: true,
        elevation: 0,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Play as section
                _buildSection(
                  child: ColorSelector(
                    selectedColor: _selectedColor,
                    onChanged: (color) {
                      setState(() => _selectedColor = color);
                    },
                  ),
                ),
                const SizedBox(height: 24),

                // Difficulty section
                _buildSection(
                  child: DifficultySelector(
                    selectedLevel: _selectedDifficultyLevel,
                    onChanged: (difficulty) {
                      setState(() {
                        _selectedDifficultyLevel = difficulty.level;
                      });
                    },
                  ),
                ),
                const SizedBox(height: 24),

                // Time control section
                _buildSection(
                  child: TimerSelector(
                    selectedIndex: _selectedTimeControlIndex,
                    onChanged: (index) {
                      setState(() => _selectedTimeControlIndex = index);
                    },
                  ),
                ),
                const SizedBox(height: 32),

                // Game summary
                _buildGameSummary(),
                const SizedBox(height: 24),

                // Start button
                FilledButton.icon(
                  onPressed: _isLoading ? null : _startGame,
                  icon:
                      _isLoading
                          ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                          : const Icon(Icons.play_arrow_rounded),
                  label: Text(
                    _isLoading ? 'Starting...' : 'Start Game',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Quick start buttons
                _buildQuickStartButtons(),
                const SizedBox(height: 32),
              ],
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black26,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Widget _buildSection({required Widget child}) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withOpacity(0.3),
        ),
      ),
      child: child,
    );
  }

  Widget _buildGameSummary() {
    final theme = Theme.of(context);
    final difficulty =
        AppConstants.difficultyLevels[_selectedDifficultyLevel - 1];
    final timeControl = AppConstants.timeControls[_selectedTimeControlIndex];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primaryContainer.withOpacity(0.5),
            theme.colorScheme.secondaryContainer.withOpacity(0.5),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            'Game Summary',
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildSummaryItem(
                icon: Icons.person_outline_rounded,
                label: 'You',
                value: _selectedColor.displayName,
              ),
              _buildSummaryItem(
                icon: Icons.psychology_rounded,
                label: 'Bot',
                value: '${difficulty.name} (${difficulty.elo})',
              ),
              _buildSummaryItem(
                icon: Icons.timer_rounded,
                label: 'Time',
                value: timeControl.displayString,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: theme.colorScheme.primary),
        const SizedBox(height: 4),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildQuickStartButtons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            'Quick Start',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: _QuickStartButton(
                label: 'Easy',
                sublabel: 'Lv 3 • 10min',
                color: Colors.green,
                onTap: () => _quickStart(3, 7),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _QuickStartButton(
                label: 'Medium',
                sublabel: 'Lv 5 • 10min',
                color: Colors.orange,
                onTap: () => _quickStart(5, 7),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _QuickStartButton(
                label: 'Hard',
                sublabel: 'Lv 7 • 10min',
                color: Colors.red,
                onTap: () => _quickStart(7, 7),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _quickStart(int difficultyLevel, int timeControlIndex) async {
    setState(() {
      _selectedDifficultyLevel = difficultyLevel;
      _selectedTimeControlIndex = timeControlIndex;
      _selectedColor = PlayerColor.white;
    });
    await _startGame();
  }

  Future<void> _startGame() async {
    setState(() => _isLoading = true);

    try {
      // Save settings for next time
      ref
          .read(settingsProvider.notifier)
          .setLastDifficulty(_selectedDifficultyLevel);
      ref
          .read(settingsProvider.notifier)
          .setLastTimeControl(_selectedTimeControlIndex);

      // Initialize engine
      final engineNotifier = ref.read(engineProvider.notifier);
      await engineNotifier.initialize();
      engineNotifier.resetForNewGame();

      // Resolve random color
      PlayerColor actualColor = _selectedColor;
      if (_selectedColor == PlayerColor.random) {
        actualColor =
            DateTime.now().millisecond % 2 == 0
                ? PlayerColor.white
                : PlayerColor.black;
      }

      // Start new game
      final difficulty =
          AppConstants.difficultyLevels[_selectedDifficultyLevel - 1];
      final timeControl = AppConstants.timeControls[_selectedTimeControlIndex];

      ref
          .read(gameProvider.notifier)
          .startNewGame(
            playerColor: actualColor,
            difficulty: difficulty,
            timeControl: timeControl,
          );

      // Navigate to game screen
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const GameScreen()),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start game: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

class _QuickStartButton extends StatelessWidget {
  final String label;
  final String sublabel;
  final Color color;
  final VoidCallback onTap;

  const _QuickStartButton({
    required this.label,
    required this.sublabel,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Column(
            children: [
              Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                sublabel,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
