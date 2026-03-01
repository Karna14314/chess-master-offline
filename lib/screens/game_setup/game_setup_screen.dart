import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chess_master/core/constants/app_constants.dart';
import 'package:chess_master/providers/game_session_viewmodel.dart';
import 'package:chess_master/screens/game/game_screen.dart';
import 'dart:ui';

class GameSetupScreen extends ConsumerStatefulWidget {
  final GameMode initialMode;
  
  const GameSetupScreen({
    super.key, 
    this.initialMode = GameMode.bot,
  });

  @override
  ConsumerState<GameSetupScreen> createState() => _GameSetupScreenState();
}

class _GameSetupScreenState extends ConsumerState<GameSetupScreen> {
  late GameMode _selectedMode;
  BotType _selectedBot = BotType.simple;
  int _selectedDifficulty = 4; // 1 to 10
  int _selectedTimeControlIndex = 0; // No Timer usually
  PlayerColor _selectedColor = PlayerColor.white;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedMode = widget.initialMode;
  }

  void _startGame() async {
    setState(() => _isLoading = true);

    try {
      final difficulty = AppConstants.difficultyLevels[_selectedDifficulty - 1];
      final timeControl = AppConstants.timeControls[_selectedTimeControlIndex];

      bool isPuzzle = _selectedMode == GameMode.puzzle;
      
      await ref.read(gameSessionProvider.notifier).startNewGame(
        gameMode: _selectedMode,
        botType: _selectedBot,
        difficulty: difficulty,
        timeControl: timeControl,
        playerColor: _selectedColor,
        isPuzzle: isPuzzle,
      );

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const GameScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: const Color(0xFF121212), // Deep charcoal
      appBar: AppBar(
        title: const Text('New Game Setup', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // Background blobs
          Positioned(
            top: -50,
            left: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0x336200EA), // Deep purple glow
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            right: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0x332962FF), // Blue glow
              ),
            ),
          ),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
            child: Container(color: Colors.transparent),
          ),
          
          SafeArea(
            child: _isLoading 
                ? const Center(child: CircularProgressIndicator()) 
                : SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildSectionTitle('Choose Game Mode'),
                        const SizedBox(height: 12),
                        _buildModeGrid(),
                        
                        if (_selectedMode == GameMode.bot) ...[
                          const SizedBox(height: 24),
                          _buildSectionTitle('Bot Configuration'),
                          const SizedBox(height: 12),
                          _buildGlassCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildEngineToggle(),
                                const SizedBox(height: 16),
                                _buildDifficultySlider(),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildColorSelector(),
                        ],
                        
                        if (_selectedMode == GameMode.bot || _selectedMode == GameMode.localMultiplayer) ...[
                          const SizedBox(height: 24),
                          _buildSectionTitle('Time Control'),
                          const SizedBox(height: 12),
                          _buildTimerChips(),
                        ],

                        const SizedBox(height: 40),
                        
                        // Start Button
                        ElevatedButton(
                          onPressed: _startGame,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2962FF),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 8,
                            shadowColor: const Color(0xFF2962FF).withOpacity(0.5),
                          ),
                          child: const Text('Start Game', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white70),
    );
  }

  Widget _buildModeGrid() {
    return GridView.count(
      shrinkWrap: true,
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 2.5,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _buildModeCard(GameMode.bot, 'vs Bot', Icons.psychology),
        _buildModeCard(GameMode.localMultiplayer, 'Local 2P', Icons.people),
        _buildModeCard(GameMode.puzzle, 'Puzzle', Icons.extension),
        _buildModeCard(GameMode.analysis, 'Analysis', Icons.analytics),
      ],
    );
  }

  Widget _buildModeCard(GameMode mode, String title, IconData icon) {
    final isSelected = _selectedMode == mode;
    return GestureDetector(
      onTap: () => setState(() => _selectedMode = mode),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2962FF).withOpacity(0.2) : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF2962FF) : Colors.white.withOpacity(0.1),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isSelected ? const Color(0xFF2962FF) : Colors.white70, size: 20),
            const SizedBox(width: 8),
            Text(title, style: TextStyle(color: isSelected ? Colors.white : Colors.white70, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildGlassCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: child,
    );
  }

  Widget _buildEngineToggle() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text('Engine', style: TextStyle(color: Colors.white70)),
        SegmentedButton<BotType>(
          segments: const [
            ButtonSegment(value: BotType.simple, label: Text('Simple')),
            ButtonSegment(value: BotType.stockfish, label: Text('Stockfish')),
          ],
          selected: {_selectedBot},
          onSelectionChanged: (Set<BotType> newSelection) {
            setState(() => _selectedBot = newSelection.first);
          },
          style: SegmentedButton.styleFrom(
            backgroundColor: Colors.white.withOpacity(0.05),
            selectedForegroundColor: Colors.white,
            selectedBackgroundColor: const Color(0xFF2962FF),
            side: BorderSide(color: Colors.white.withOpacity(0.1)),
          ),
        ),
      ],
    );
  }

  Widget _buildDifficultySlider() {
    final difficulty = AppConstants.difficultyLevels[_selectedDifficulty - 1];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Difficulty', style: TextStyle(color: Colors.white70)),
            Text('${difficulty.name} (${difficulty.elo})', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.amber)),
          ],
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: const Color(0xFF2962FF),
            inactiveTrackColor: Colors.white.withOpacity(0.1),
            thumbColor: Colors.white,
            overlayColor: const Color(0xFF2962FF).withOpacity(0.2),
          ),
          child: Slider(
            value: _selectedDifficulty.toDouble(),
            min: 1,
            max: 10,
            divisions: 9,
            onChanged: (val) => setState(() => _selectedDifficulty = val.toInt()),
          ),
        ),
      ],
    );
  }

  Widget _buildColorSelector() {
    return _buildGlassCard(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildColorOption(PlayerColor.white, 'White', Icons.circle),
          _buildColorOption(PlayerColor.random, 'Random', Icons.help_outline),
          _buildColorOption(PlayerColor.black, 'Black', Icons.circle_outlined),
        ],
      ),
    );
  }

  Widget _buildColorOption(PlayerColor color, String label, IconData icon) {
    final isSelected = _selectedColor == color;
    return GestureDetector(
      onTap: () => setState(() => _selectedColor = color),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected ? const Color(0xFF2962FF).withOpacity(0.2) : Colors.transparent,
              border: Border.all(color: isSelected ? const Color(0xFF2962FF) : Colors.transparent),
            ),
            child: Icon(icon, color: isSelected ? Colors.white : Colors.white54, size: 28),
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.white54, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildTimerChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: AppConstants.timeControls.asMap().entries.map((entry) {
          final idx = entry.key;
          final tc = entry.value;
          final isSelected = _selectedTimeControlIndex == idx;
          
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(tc.displayString),
              selected: isSelected,
              onSelected: (val) {
                if(val) setState(() => _selectedTimeControlIndex = idx);
              },
              backgroundColor: Colors.white.withOpacity(0.05),
              selectedColor: const Color(0xFF2962FF),
              labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.white70),
              side: BorderSide(color: isSelected ? Colors.transparent : Colors.white.withOpacity(0.1)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
          );
        }).toList(),
      ),
    );
  }
}
