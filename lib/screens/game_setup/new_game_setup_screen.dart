import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:chess_master/core/theme/app_theme.dart';
import 'package:chess_master/core/constants/app_constants.dart';
import 'package:chess_master/providers/game_session_viewmodel.dart';
import 'package:chess_master/screens/game/game_screen.dart';
import 'package:chess_master/screens/analysis/analysis_screen.dart';

class NewGameSetupScreen extends ConsumerStatefulWidget {
  final GameMode initialMode;
  
  const NewGameSetupScreen({
    super.key,
    this.initialMode = GameMode.bot,
  });

  @override
  ConsumerState<NewGameSetupScreen> createState() => _NewGameSetupScreenState();
}

class _NewGameSetupScreenState extends ConsumerState<NewGameSetupScreen> {
  late GameMode _selectedMode;
  BotType _selectedBotType = BotType.simple;
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
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader('Game Mode'),
                  const SizedBox(height: 12),
                  _buildModeSelectionGrid(),
                  
                  if (_selectedMode == GameMode.bot) ...[
                    const SizedBox(height: 32),
                    _buildSectionHeader('Opponent'),
                    const SizedBox(height: 12),
                    _buildBotSelection(),
                    const SizedBox(height: 24),
                    _buildDifficultySlider(),
                  ],

                  if (_selectedMode == GameMode.bot || _selectedMode == GameMode.localMultiplayer) ...[
                    const SizedBox(height: 32),
                    _buildSectionHeader('Play As'),
                    const SizedBox(height: 12),
                    _buildColorSelection(),
                    
                    const SizedBox(height: 32),
                    _buildSectionHeader('Time Control'),
                    const SizedBox(height: 12),
                    _buildTimerSelection(),
                  ],
                  
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
                  color: AppTheme.primaryColor.withOpacity(0.4),
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

  Widget _buildModeSelectionGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.3,
      children: [
        _ModeCard(
          title: 'vs Bot',
          icon: Icons.smart_toy_outlined,
          isSelected: _selectedMode == GameMode.bot,
          onTap: () => setState(() => _selectedMode = GameMode.bot),
        ),
        _ModeCard(
          title: 'Local 2P',
          icon: Icons.people_outline,
          isSelected: _selectedMode == GameMode.localMultiplayer,
          onTap: () => setState(() => _selectedMode = GameMode.localMultiplayer),
        ),
        _ModeCard(
          title: 'Puzzle',
          icon: Icons.extension_outlined,
          isSelected: _selectedMode == GameMode.puzzle,
          onTap: () => setState(() => _selectedMode = GameMode.puzzle),
        ),
        _ModeCard(
          title: 'Analysis',
          icon: Icons.analytics_outlined,
          isSelected: _selectedMode == GameMode.analysis,
          onTap: () => setState(() => _selectedMode = GameMode.analysis),
        ),
      ],
    );
  }

  Widget _buildBotSelection() {
    return Row(
      children: [
        Expanded(
          child: _EngineCard(
            title: 'Simple AI',
            desc: 'Fast & Lightweight',
            isSelected: _selectedBotType == BotType.simple,
            onTap: () => setState(() => _selectedBotType = BotType.simple),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _EngineCard(
            title: 'Stockfish',
            desc: 'Maximum Strength',
            isSelected: _selectedBotType == BotType.stockfish,
            onTap: () => setState(() => _selectedBotType = BotType.stockfish),
          ),
        ),
      ],
    );
  }

  Widget _buildDifficultySlider() {
    final diffInfo = AppConstants.difficultyLevels[_difficultyLevel.toInt() - 1];
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
            overlayColor: AppTheme.primaryColor.withOpacity(0.2),
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
              color: isSelected ? AppTheme.primaryColor.withOpacity(0.2) : Colors.white.withOpacity(0.05),
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
    if (_selectedMode == GameMode.puzzle) {
      // Navigate to puzzle screen (assuming we have one or use GameScreen)
      // Usually puzzle mode initializes via PuzzleNotifier, but we can refactor later.
      // For now, if user clicks Puzzle, maybe we route to a PuzzleScreen.
      // E.g. Navigator.push(context, MaterialPageRoute(builder: (_) => PuzzleScreen()));
      return; 
    }
    if (_selectedMode == GameMode.analysis) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const AnalysisScreen()));
      return;
    }

    final diffLevel = AppConstants.difficultyLevels[_difficultyLevel.toInt() - 1];
    final timerControl = AppConstants.timeControls[_selectedTimerIndex];

    ref.read(gameSessionProvider.notifier).startNewGame(
      gameMode: _selectedMode,
      playerColor: _selectedColor,
      botType: _selectedBotType,
      difficulty: diffLevel,
      timeControl: timerControl,
    );
    
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const GameScreen()),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _ModeCard({
    required this.title,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor.withOpacity(0.15) : AppTheme.surfaceDark,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : Colors.white10,
            width: 2,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: AppTheme.primaryColor.withOpacity(0.2), blurRadius: 12)]
              : [],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 32,
              color: isSelected ? AppTheme.primaryColor : Colors.white54,
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EngineCard extends StatelessWidget {
  final String title;
  final String desc;
  final bool isSelected;
  final VoidCallback onTap;

  const _EngineCard({
    required this.title,
    required this.desc,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor.withOpacity(0.15) : AppTheme.surfaceDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : Colors.white10,
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Text(
              title,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : Colors.white70,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              desc,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: Colors.white54,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
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
          boxShadow: isSelected
              ? [BoxShadow(color: AppTheme.primaryColor.withOpacity(0.4), blurRadius: 12)]
              : [],
        ),
        child: Center(
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: centerColor,
              border: Border.all(color: ringColor.withOpacity(0.5), width: 1),
            ),
            child: icon != null ? Icon(icon, color: iconColor) : null,
          ),
        ),
      ),
    );
  }
}
