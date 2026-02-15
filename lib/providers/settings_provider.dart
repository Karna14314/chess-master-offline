import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:chess_master/core/theme/board_themes.dart';
import 'package:chess_master/core/constants/app_constants.dart';

/// Provider for user settings
final settingsProvider = StateNotifierProvider<SettingsNotifier, AppSettings>((
  ref,
) {
  return SettingsNotifier();
});

/// Animation speed options
enum AnimationSpeed {
  off(Duration.zero, 'Off'),
  fast(Duration(milliseconds: 100), 'Fast'),
  medium(Duration(milliseconds: 200), 'Medium'),
  slow(Duration(milliseconds: 400), 'Slow');

  final Duration duration;
  final String label;

  const AnimationSpeed(this.duration, this.label);
}

/// User app settings
class AppSettings {
  final BoardThemeType boardTheme;
  final PieceSetType pieceSet;
  final bool showCoordinates;
  final bool showLegalMoves;
  final bool showLastMove;
  final AnimationSpeed animationSpeed;
  final bool soundEnabled;
  final bool vibrationEnabled;
  final bool boardFlipped;
  final bool autoFlipBoard; // Auto flip for black pieces (default OFF)
  final int lastDifficultyLevel;
  final int lastTimeControlIndex;

  const AppSettings({
    this.boardTheme = BoardThemeType.classicWood,
    this.pieceSet = PieceSetType.traditional,
    this.showCoordinates = true,
    this.showLegalMoves = true,
    this.showLastMove = true,
    this.animationSpeed = AnimationSpeed.medium,
    this.soundEnabled = true,
    this.vibrationEnabled = true,
    this.boardFlipped = false,
    this.autoFlipBoard = false, // Default OFF as requested
    this.lastDifficultyLevel = 5,
    this.lastTimeControlIndex = 0,
  });

  BoardTheme get currentBoardTheme => BoardTheme.fromType(boardTheme);
  PieceSet get currentPieceSet => PieceSet.fromType(pieceSet);
  DifficultyLevel get lastDifficulty =>
      AppConstants.difficultyLevels[lastDifficultyLevel - 1];
  TimeControl get lastTimeControl =>
      AppConstants.timeControls[lastTimeControlIndex];

  AppSettings copyWith({
    BoardThemeType? boardTheme,
    PieceSetType? pieceSet,
    bool? showCoordinates,
    bool? showLegalMoves,
    bool? showLastMove,
    AnimationSpeed? animationSpeed,
    bool? soundEnabled,
    bool? vibrationEnabled,
    bool? boardFlipped,
    bool? autoFlipBoard,
    int? lastDifficultyLevel,
    int? lastTimeControlIndex,
  }) {
    return AppSettings(
      boardTheme: boardTheme ?? this.boardTheme,
      pieceSet: pieceSet ?? this.pieceSet,
      showCoordinates: showCoordinates ?? this.showCoordinates,
      showLegalMoves: showLegalMoves ?? this.showLegalMoves,
      showLastMove: showLastMove ?? this.showLastMove,
      animationSpeed: animationSpeed ?? this.animationSpeed,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
      boardFlipped: boardFlipped ?? this.boardFlipped,
      autoFlipBoard: autoFlipBoard ?? this.autoFlipBoard,
      lastDifficultyLevel: lastDifficultyLevel ?? this.lastDifficultyLevel,
      lastTimeControlIndex: lastTimeControlIndex ?? this.lastTimeControlIndex,
    );
  }
}

/// Settings state notifier
class SettingsNotifier extends StateNotifier<AppSettings> {
  SettingsNotifier() : super(const AppSettings()) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    state = AppSettings(
      boardTheme: BoardThemeType.values[prefs.getInt('boardTheme') ?? 0],
      pieceSet: PieceSetType.values[prefs.getInt('pieceSet') ?? 0],
      showCoordinates: prefs.getBool('showCoordinates') ?? true,
      showLegalMoves: prefs.getBool('showLegalMoves') ?? true,
      showLastMove: prefs.getBool('showLastMove') ?? true,
      animationSpeed:
          AnimationSpeed.values[prefs.getInt('animationSpeed') ?? 2],
      soundEnabled: prefs.getBool('soundEnabled') ?? true,
      vibrationEnabled: prefs.getBool('vibrationEnabled') ?? true,
      boardFlipped: prefs.getBool('boardFlipped') ?? false,
      autoFlipBoard: prefs.getBool('autoFlipBoard') ?? false,
      lastDifficultyLevel: prefs.getInt('lastDifficultyLevel') ?? 5,
      lastTimeControlIndex: prefs.getInt('lastTimeControlIndex') ?? 0,
    );
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setInt('boardTheme', state.boardTheme.index);
    await prefs.setInt('pieceSet', state.pieceSet.index);
    await prefs.setBool('showCoordinates', state.showCoordinates);
    await prefs.setBool('showLegalMoves', state.showLegalMoves);
    await prefs.setBool('showLastMove', state.showLastMove);
    await prefs.setInt('animationSpeed', state.animationSpeed.index);
    await prefs.setBool('soundEnabled', state.soundEnabled);
    await prefs.setBool('vibrationEnabled', state.vibrationEnabled);
    await prefs.setBool('boardFlipped', state.boardFlipped);
    await prefs.setBool('autoFlipBoard', state.autoFlipBoard);
    await prefs.setInt('lastDifficultyLevel', state.lastDifficultyLevel);
    await prefs.setInt('lastTimeControlIndex', state.lastTimeControlIndex);
  }

  void toggleAutoFlipBoard() {
    state = state.copyWith(autoFlipBoard: !state.autoFlipBoard);
    _saveSettings();
  }

  void toggleShowLegalMoves() {
    state = state.copyWith(showLegalMoves: !state.showLegalMoves);
    _saveSettings();
  }

  void setBoardTheme(BoardThemeType theme) {
    state = state.copyWith(boardTheme: theme);
    _saveSettings();
  }

  void setPieceSet(PieceSetType pieceSet) {
    state = state.copyWith(pieceSet: pieceSet);
    _saveSettings();
  }

  void toggleCoordinates() {
    state = state.copyWith(showCoordinates: !state.showCoordinates);
    _saveSettings();
  }

  void toggleLegalMoves() {
    state = state.copyWith(showLegalMoves: !state.showLegalMoves);
    _saveSettings();
  }

  void toggleLastMove() {
    state = state.copyWith(showLastMove: !state.showLastMove);
    _saveSettings();
  }

  void setAnimationSpeed(AnimationSpeed speed) {
    state = state.copyWith(animationSpeed: speed);
    _saveSettings();
  }

  void toggleSound() {
    state = state.copyWith(soundEnabled: !state.soundEnabled);
    _saveSettings();
  }

  void toggleVibration() {
    state = state.copyWith(vibrationEnabled: !state.vibrationEnabled);
    _saveSettings();
  }

  void toggleBoardFlip() {
    state = state.copyWith(boardFlipped: !state.boardFlipped);
    _saveSettings();
  }

  void setLastDifficulty(int level) {
    state = state.copyWith(lastDifficultyLevel: level);
    _saveSettings();
  }

  void setLastTimeControl(int index) {
    state = state.copyWith(lastTimeControlIndex: index);
    _saveSettings();
  }
}
