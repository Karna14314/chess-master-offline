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
  bool _isCustomTimer = false;
  int _customMinutes = 10;
  int _customIncrement = 5;

  @override
  void initState() {
    super.initState();
    _selectedMode = widget.initialMode;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            elevation: 0,
            pinned: true,
            title: Text(
              'New Game',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimaryFor(context),
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

                  if (_selectedMode != GameMode.bot) ...[
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
        color: AppTheme.textSecondaryFor(context),
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
                color: AppTheme.textPrimaryFor(context),
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
            inactiveTrackColor: AppTheme.borderColorFor(
              context,
            ).withValues(alpha: 0.3),
            thumbColor: Theme.of(context).colorScheme.onSurface,
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
    final children = <Widget>[];

    for (int index = 0; index < AppConstants.timeControls.length; index++) {
      final timer = AppConstants.timeControls[index];
      final isSelected = !_isCustomTimer && _selectedTimerIndex == index;
      children.add(
        GestureDetector(
          onTap: () => setState(() {
            _isCustomTimer = false;
            _selectedTimerIndex = index;
          }),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color:
                  isSelected
                      ? AppTheme.primaryColor.withValues(alpha: 0.2)
                      : AppTheme.cardColor(context).withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color:
                    isSelected
                        ? AppTheme.primaryColor
                        : AppTheme.borderColorFor(
                          context,
                        ).withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            child: Text(
              timer.displayString,
              style: GoogleFonts.spaceGrotesk(
                color:
                    isSelected
                        ? AppTheme.textPrimaryFor(context)
                        : AppTheme.textSecondaryFor(context),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ),
        ),
      );
    }

    // Custom Timer Option Chip
    children.add(
      GestureDetector(
        onTap: () => _showCustomTimerSheet(),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color:
                _isCustomTimer
                    ? AppTheme.primaryColor.withValues(alpha: 0.2)
                    : AppTheme.cardColor(context).withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color:
                  _isCustomTimer
                      ? AppTheme.primaryColor
                      : AppTheme.borderColorFor(
                        context,
                      ).withValues(alpha: 0.3),
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _isCustomTimer ? Icons.tune_rounded : Icons.add_rounded,
                size: 16,
                color:
                    _isCustomTimer
                        ? AppTheme.primaryColor
                        : AppTheme.textSecondaryFor(context),
              ),
              const SizedBox(width: 6),
              Text(
                _isCustomTimer
                    ? 'Custom $_customMinutes+$_customIncrement'
                    : 'Custom...',
                style: GoogleFonts.spaceGrotesk(
                  color:
                      _isCustomTimer
                          ? AppTheme.textPrimaryFor(context)
                          : AppTheme.textSecondaryFor(context),
                  fontWeight:
                      _isCustomTimer ? FontWeight.bold : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: children,
    );
  }

  void _showCustomTimerSheet() {
    int tempMinutes = _customMinutes;
    int tempIncrement = _customIncrement;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final textPrimary = AppTheme.textPrimaryFor(context);
            final textSecondary = AppTheme.textSecondaryFor(context);

            return Container(
              decoration: BoxDecoration(
                color: AppTheme.cardColor(context),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                border: Border.all(
                  color: AppTheme.borderColorFor(context),
                  width: 1,
                ),
              ),
              padding: EdgeInsets.fromLTRB(
                20,
                16,
                20,
                MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppTheme.borderColorFor(context),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.tune_rounded,
                            color: AppTheme.primaryColor,
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Custom Time Control',
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: textPrimary,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppTheme.primaryColor.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text(
                          '$tempMinutes min + ${tempIncrement}s',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Minutes Slider & Stepper
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Time per Player',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: textPrimary,
                        ),
                      ),
                      Text(
                        '$tempMinutes minutes',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ],
                  ),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: AppTheme.primaryColor,
                      inactiveTrackColor: AppTheme.borderColorFor(
                        context,
                      ).withValues(alpha: 0.3),
                      thumbColor: AppTheme.primaryColor,
                    ),
                    child: Slider(
                      value: tempMinutes.toDouble(),
                      min: 1,
                      max: 180,
                      divisions: 179,
                      onChanged: (val) {
                        setSheetState(() => tempMinutes = val.round());
                      },
                    ),
                  ),
                  // Quick Minute Presets
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children:
                          [1, 3, 5, 7, 10, 15, 20, 30, 45, 60, 90].map((m) {
                            final isCur = tempMinutes == m;
                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: ChoiceChip(
                                label: Text('${m}m'),
                                selected: isCur,
                                onSelected:
                                    (_) =>
                                        setSheetState(() => tempMinutes = m),
                                selectedColor: AppTheme.primaryColor,
                                labelStyle: GoogleFonts.inter(
                                  color: isCur ? Colors.white : textPrimary,
                                  fontSize: 12,
                                  fontWeight:
                                      isCur
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                ),
                              ),
                            );
                          }).toList(),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Increment Slider & Stepper
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Increment per Move',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: textPrimary,
                        ),
                      ),
                      Text(
                        '$tempIncrement seconds',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ],
                  ),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: AppTheme.primaryColor,
                      inactiveTrackColor: AppTheme.borderColorFor(
                        context,
                      ).withValues(alpha: 0.3),
                      thumbColor: AppTheme.primaryColor,
                    ),
                    child: Slider(
                      value: tempIncrement.toDouble(),
                      min: 0,
                      max: 60,
                      divisions: 60,
                      onChanged: (val) {
                        setSheetState(() => tempIncrement = val.round());
                      },
                    ),
                  ),
                  // Quick Increment Presets
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children:
                          [0, 1, 2, 3, 5, 10, 15, 20, 30].map((inc) {
                            final isCur = tempIncrement == inc;
                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: ChoiceChip(
                                label: Text('+${inc}s'),
                                selected: isCur,
                                onSelected:
                                    (_) => setSheetState(
                                      () => tempIncrement = inc,
                                    ),
                                selectedColor: AppTheme.primaryColor,
                                labelStyle: GoogleFonts.inter(
                                  color: isCur ? Colors.white : textPrimary,
                                  fontSize: 12,
                                  fontWeight:
                                      isCur
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                ),
                              ),
                            );
                          }).toList(),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            side: BorderSide(
                              color: AppTheme.borderColorFor(context),
                            ),
                          ),
                          child: Text(
                            'Cancel',
                            style: GoogleFonts.inter(
                              color: textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _customMinutes = tempMinutes;
                              _customIncrement = tempIncrement;
                              _isCustomTimer = true;
                            });
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            'Apply Time',
                            style: GoogleFonts.spaceGrotesk(
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _startGame() {
    final diffLevel =
        AppConstants.difficultyLevels[_difficultyLevel.toInt() - 1];
    final timerControl =
        _selectedMode == GameMode.bot
            ? AppConstants.timeControls[0]
            : _isCustomTimer
            ? TimeControl(
              name: 'Custom $_customMinutes+$_customIncrement',
              minutes: _customMinutes,
              increment: _customIncrement,
            )
            : AppConstants.timeControls[_selectedTimerIndex];

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
            color:
                isSelected
                    ? AppTheme.primaryColor
                    : AppTheme.borderColorFor(context).withValues(alpha: 0.3),
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
