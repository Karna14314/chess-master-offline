import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:chess_master/core/theme/app_theme.dart';
import 'package:chess_master/core/constants/app_constants.dart';
import 'package:chess_master/providers/game_session_viewmodel.dart';
import 'package:chess_master/screens/game/game_screen.dart';

class NewGameSetupScreen extends ConsumerStatefulWidget {
  final GameMode initialMode;

  const NewGameSetupScreen({super.key, this.initialMode = GameMode.bot});

  @override
  ConsumerState<NewGameSetupScreen> createState() => _NewGameSetupScreenState();
}

class _NewGameSetupScreenState extends ConsumerState<NewGameSetupScreen> {
  late GameMode _selectedMode;
  double _difficultyLevel = 3.0;
  PlayerColor _selectedColor = PlayerColor.random;
  int _selectedTimerIndex = 0; // Default to 'No Timer'

  @override
  void initState() {
    super.initState();
    _selectedMode = widget.initialMode;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: AppTheme.backgroundDark,
            elevation: 0,
            pinned: true,
            title: Text(
              'New Game',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            centerTitle: true,
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 20.0,
                vertical: 16.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_selectedMode == GameMode.bot) ...[
                    _buildSectionHeader('Opponent Difficulty'),
                    const SizedBox(height: 12),
                    _buildDifficultySlider(),
                  ],

                  const SizedBox(height: 32),
                  _buildSectionHeader('Play As'),
                  const SizedBox(height: 12),
                  _buildColorSelection(),

                  const SizedBox(height: 32),
                  _buildSectionHeader('Time Control'),
                  const SizedBox(height: 12),
                  _buildTimerSelection(),

                  const SizedBox(height: 100), // Space for button
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: Padding(
        padding: const EdgeInsets.all(20.0),
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryColor.withValues(alpha: 0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: _startGame,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
                elevation: 0,
              ),
              child: Text(
                'Start Game',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.spaceGrotesk(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: Colors.white70,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildDifficultySlider() {
    final diffInfo =
        AppConstants.difficultyLevels[_difficultyLevel.toInt() - 1];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Difficulty: Level ${_difficultyLevel.toInt()}',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 16,
                color: Colors.white,
              ),
            ),
            Text(
              '~${diffInfo.elo} ELO (${diffInfo.name})',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 14,
                color: AppTheme.primaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: AppTheme.primaryColor,
            inactiveTrackColor: Colors.white12,
            thumbColor: Colors.white,
            overlayColor: AppTheme.primaryColor.withValues(alpha: 0.2),
            valueIndicatorColor: AppTheme.primaryColor,
            trackHeight: 6,
          ),
          child: Slider(
            value: _difficultyLevel,
            min: 1,
            max: 10,
            divisions: 9,
            onChanged: (val) {
              setState(() {
                _difficultyLevel = val;
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildColorSelection() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _ColorCircle(
          color: PlayerColor.white,
          isSelected: _selectedColor == PlayerColor.white,
          onTap: () => setState(() => _selectedColor = PlayerColor.white),
        ),
        const SizedBox(width: 24),
        _ColorCircle(
          color: PlayerColor.random,
          isSelected: _selectedColor == PlayerColor.random,
          onTap: () => setState(() => _selectedColor = PlayerColor.random),
        ),
        const SizedBox(width: 24),
        _ColorCircle(
          color: PlayerColor.black,
          isSelected: _selectedColor == PlayerColor.black,
          onTap: () => setState(() => _selectedColor = PlayerColor.black),
        ),
      ],
    );
  }

  Widget _buildTimerSelection() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: List.generate(AppConstants.timeControls.length, (index) {
        final timer = AppConstants.timeControls[index];
        final isSelected = _selectedTimerIndex == index;
        return GestureDetector(
          onTap: () => setState(() => _selectedTimerIndex = index),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color:
                  isSelected
                      ? AppTheme.primaryColor.withValues(alpha: 0.2)
                      : Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? AppTheme.primaryColor : Colors.white12,
                width: 1.5,
              ),
            ),
            child: Text(
              timer.displayString,
              style: GoogleFonts.spaceGrotesk(
                color: isSelected ? Colors.white : Colors.white70,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ),
        );
      }),
    );
  }

  void _startGame() {
    final diffLevel =
        AppConstants.difficultyLevels[_difficultyLevel.toInt() - 1];
    final timerControl = AppConstants.timeControls[_selectedTimerIndex];

    ref
        .read(gameSessionProvider.notifier)
        .startNewGame(
          gameMode: _selectedMode,
          playerColor: _selectedColor,
          botType: BotType.stockfish,
          difficulty: diffLevel,
          timeControl: timerControl,
        );

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const GameScreen()),
    );
  }
}

class _ColorCircle extends StatelessWidget {
  final PlayerColor color;
  final bool isSelected;
  final VoidCallback onTap;

  const _ColorCircle({
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color ringColor = Colors.transparent;
    Color centerColor = Colors.transparent;
    IconData? icon;
    Color iconColor = Colors.transparent;

    if (color == PlayerColor.white) {
      ringColor = Colors.white;
      centerColor = Colors.white;
    } else if (color == PlayerColor.black) {
      ringColor = Colors.white;
      centerColor = Colors.black;
    } else {
      ringColor = AppTheme.primaryColor;
      centerColor = AppTheme.surfaceDark;
      icon = Icons.shuffle;
      iconColor = AppTheme.primaryColor;
    }

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : Colors.white12,
            width: isSelected ? 3 : 1,
          ),
          boxShadow:
              isSelected
                  ? [
                    BoxShadow(
                      color: AppTheme.primaryColor.withValues(alpha: 0.4),
                      blurRadius: 12,
                    ),
                  ]
                  : [],
        ),
        child: Center(
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: centerColor,
              border: Border.all(
                color: ringColor.withValues(alpha: 0.5),
                width: 1,
              ),
            ),
            child: icon != null ? Icon(icon, color: iconColor) : null,
          ),
        ),
      ),
    );
  }
}
