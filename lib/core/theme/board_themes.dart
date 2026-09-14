import 'package:flutter/material.dart';

/// Chess board visual themes
enum BoardThemeType {
  classicWood,
  modernBlue,
  forestGreen,
  midnightDark,
  royalNavy,
  slateGray,
  marble,
}

/// Cohesive app theme presets that synchronize ColorScheme, board theme, and accents
enum ThemePreset {
  classic,
  midnight,
  emerald,
  royal;

  String get displayName {
    switch (this) {
      case ThemePreset.classic:
        return 'Classic';
      case ThemePreset.midnight:
        return 'Midnight';
      case ThemePreset.emerald:
        return 'Emerald';
      case ThemePreset.royal:
        return 'Royal';
    }
  }

  String get description {
    switch (this) {
      case ThemePreset.classic:
        return 'Warm tournament wood with amber gold accents';
      case ThemePreset.midnight:
        return 'Dark OLED tournament with diamond cyan accents';
      case ThemePreset.emerald:
        return 'Deep tournament green with crisp contrast';
      case ThemePreset.royal:
        return 'Deep navy, ivory squares and restrained gold';
    }
  }

  BoardThemeType get defaultBoardTheme {
    switch (this) {
      case ThemePreset.classic:
        return BoardThemeType.classicWood;
      case ThemePreset.midnight:
        return BoardThemeType.midnightDark;
      case ThemePreset.emerald:
        return BoardThemeType.forestGreen;
      case ThemePreset.royal:
        return BoardThemeType.royalNavy;
    }
  }

  Color get accentColor {
    switch (this) {
      case ThemePreset.classic:
        return const Color(0xFFD4A373);
      case ThemePreset.midnight:
        return const Color(0xFF00E5FF);
      case ThemePreset.emerald:
        return const Color(0xFF10B981);
      case ThemePreset.royal:
        return const Color(0xFFF59E0B);
    }
  }

  Color get primaryColor {
    switch (this) {
      case ThemePreset.classic:
        return const Color(0xFF8D6E63);
      case ThemePreset.midnight:
        return const Color(0xFF0284C7);
      case ThemePreset.emerald:
        return const Color(0xFF10B981);
      case ThemePreset.royal:
        return const Color(0xFF3B82F6);
    }
  }

  PieceSetType get defaultPieceSet {
    switch (this) {
      case ThemePreset.classic:
        return PieceSetType.traditional;
      case ThemePreset.midnight:
        return PieceSetType.modern;
      case ThemePreset.emerald:
        return PieceSetType.traditional;
      case ThemePreset.royal:
        return PieceSetType.modern;
    }
  }
}

/// Configuration for a chess board theme
class BoardTheme {
  final String name;
  final Color lightSquare;
  final Color darkSquare;
  final Color lightSquareHighlight;
  final Color darkSquareHighlight;
  final Color lastMoveLightSquare;
  final Color lastMoveDarkSquare;
  final Color legalMoveDot;
  final Color legalMoveCapture;
  final Color checkHighlight;
  final Color selectedSquare;
  final Color coordinateLight;
  final Color coordinateDark;

  const BoardTheme({
    required this.name,
    required this.lightSquare,
    required this.darkSquare,
    required this.lightSquareHighlight,
    required this.darkSquareHighlight,
    required this.lastMoveLightSquare,
    required this.lastMoveDarkSquare,
    required this.legalMoveDot,
    required this.legalMoveCapture,
    required this.checkHighlight,
    required this.selectedSquare,
    required this.coordinateLight,
    required this.coordinateDark,
  });

  /// Classic Wood theme (Lichess style)
  static const BoardTheme classicWood = BoardTheme(
    name: 'Classic Wood',
    lightSquare: Color(0xFFF0D9B5),
    darkSquare: Color(0xFFB58863),
    lightSquareHighlight: Color(0xFFCDD26A),
    darkSquareHighlight: Color(0xFFAAA23A),
    lastMoveLightSquare: Color(0xFFCDD26A),
    lastMoveDarkSquare: Color(0xFFAAA23A),
    legalMoveDot: Color(0x40000000),
    legalMoveCapture: Color(0x40000000),
    checkHighlight: Color(0xFFFF6B6B),
    selectedSquare: Color(0x80FFEB3B),
    coordinateLight: Color(0xFFB58863),
    coordinateDark: Color(0xFFF0D9B5),
  );

  /// Modern Blue theme (Chess.com style)
  static const BoardTheme modernBlue = BoardTheme(
    name: 'Modern Blue',
    lightSquare: Color(0xFFEEEED2),
    darkSquare: Color(0xFF769656),
    lightSquareHighlight: Color(0xFFF7F769),
    darkSquareHighlight: Color(0xFFBBCB44),
    lastMoveLightSquare: Color(0xFFF7F769),
    lastMoveDarkSquare: Color(0xFFBBCB44),
    legalMoveDot: Color(0x40000000),
    legalMoveCapture: Color(0x40000000),
    checkHighlight: Color(0xFFFF6B6B),
    selectedSquare: Color(0x80FFEB3B),
    coordinateLight: Color(0xFF769656),
    coordinateDark: Color(0xFFEEEED2),
  );

  /// Forest Green theme
  static const BoardTheme forestGreen = BoardTheme(
    name: 'Forest Green',
    lightSquare: Color(0xFFE8E8D5),
    darkSquare: Color(0xFF6B8E5A),
    lightSquareHighlight: Color(0xFFD4E157),
    darkSquareHighlight: Color(0xFF9CCC65),
    lastMoveLightSquare: Color(0xFFD4E157),
    lastMoveDarkSquare: Color(0xFF9CCC65),
    legalMoveDot: Color(0x40000000),
    legalMoveCapture: Color(0x40000000),
    checkHighlight: Color(0xFFFF5252),
    selectedSquare: Color(0x80FFEB3B),
    coordinateLight: Color(0xFF6B8E5A),
    coordinateDark: Color(0xFFE8E8D5),
  );

  /// Midnight Dark theme (High contrast OLED)
  static const BoardTheme midnightDark = BoardTheme(
    name: 'Midnight Dark',
    lightSquare: Color(0xFF3A3F47),
    darkSquare: Color(0xFF20242B),
    lightSquareHighlight: Color(0xFF4F8A8B),
    darkSquareHighlight: Color(0xFF2F6668),
    lastMoveLightSquare: Color(0xFF4F8A8B),
    lastMoveDarkSquare: Color(0xFF2F6668),
    legalMoveDot: Color(0x6000E5FF),
    legalMoveCapture: Color(0x8000E5FF),
    checkHighlight: Color(0xFFFF5252),
    selectedSquare: Color(0x8000E5FF),
    coordinateLight: Color(0xFF8C9BAE),
    coordinateDark: Color(0xFF5A6678),
  );

  /// Royal Navy theme
  static const BoardTheme royalNavy = BoardTheme(
    name: 'Royal Navy',
    lightSquare: Color(0xFFDEE3E6),
    darkSquare: Color(0xFF4A607A),
    lightSquareHighlight: Color(0xFFF59E0B),
    darkSquareHighlight: Color(0xFFD97706),
    lastMoveLightSquare: Color(0x80F59E0B),
    lastMoveDarkSquare: Color(0x80D97706),
    legalMoveDot: Color(0x40000000),
    legalMoveCapture: Color(0x50F59E0B),
    checkHighlight: Color(0xFFFF5252),
    selectedSquare: Color(0x80F59E0B),
    coordinateLight: Color(0xFF4A607A),
    coordinateDark: Color(0xFFDEE3E6),
  );

  /// Slate Gray theme
  static const BoardTheme slateGray = BoardTheme(
    name: 'Slate Gray',
    lightSquare: Color(0xFFD8D8D8),
    darkSquare: Color(0xFF707880),
    lightSquareHighlight: Color(0xFF90A4AE),
    darkSquareHighlight: Color(0xFF607D8B),
    lastMoveLightSquare: Color(0xFF90A4AE),
    lastMoveDarkSquare: Color(0xFF607D8B),
    legalMoveDot: Color(0x40000000),
    legalMoveCapture: Color(0x40000000),
    checkHighlight: Color(0xFFFF5252),
    selectedSquare: Color(0x8090A4AE),
    coordinateLight: Color(0xFF707880),
    coordinateDark: Color(0xFFD8D8D8),
  );

  /// Marble theme
  static const BoardTheme marble = BoardTheme(
    name: 'Marble',
    lightSquare: Color(0xFFE9E4DC),
    darkSquare: Color(0xFF9B9184),
    lightSquareHighlight: Color(0xFFC2B8A3),
    darkSquareHighlight: Color(0xFFA69A84),
    lastMoveLightSquare: Color(0xFFC2B8A3),
    lastMoveDarkSquare: Color(0xFFA69A84),
    legalMoveDot: Color(0x40000000),
    legalMoveCapture: Color(0x40000000),
    checkHighlight: Color(0xFFFF5252),
    selectedSquare: Color(0x80D4A373),
    coordinateLight: Color(0xFF9B9184),
    coordinateDark: Color(0xFFE9E4DC),
  );

  /// Get theme by type
  static BoardTheme fromType(BoardThemeType type) {
    switch (type) {
      case BoardThemeType.classicWood:
        return classicWood;
      case BoardThemeType.modernBlue:
        return modernBlue;
      case BoardThemeType.forestGreen:
        return forestGreen;
      case BoardThemeType.midnightDark:
        return midnightDark;
      case BoardThemeType.royalNavy:
        return royalNavy;
      case BoardThemeType.slateGray:
        return slateGray;
      case BoardThemeType.marble:
        return marble;
    }
  }

  /// Get all available themes
  static List<BoardTheme> get allThemes => [
    classicWood,
    forestGreen,
    modernBlue,
    midnightDark,
    royalNavy,
    slateGray,
    marble,
  ];
}

/// Piece set types
enum PieceSetType {
  traditional,
  modern,
  classic,
  neo,
  wood,
  glass,
  alpha,
  merida,
  cburnett,
  minimal,
  fantasy,
}

/// Configuration for a piece set
class PieceSet {
  final String name;
  final String assetPath;

  const PieceSet({required this.name, required this.assetPath});

  static const PieceSet traditional = PieceSet(
    name: 'Traditional',
    assetPath: 'assets/pieces/traditional/',
  );

  static const PieceSet modern = PieceSet(
    name: 'Modern',
    assetPath: 'assets/pieces/modern/',
  );

  static const PieceSet classic = PieceSet(
    name: 'Classic',
    assetPath: 'assets/pieces/traditional/', // Use fallback until assets exist
  );

  static const PieceSet neo = PieceSet(
    name: 'Neo',
    assetPath: 'assets/pieces/modern/', // Use fallback
  );

  static const PieceSet wood = PieceSet(
    name: 'Wood',
    assetPath: 'assets/pieces/traditional/', // Use fallback
  );

  static const PieceSet glass = PieceSet(
    name: 'Glass',
    assetPath: 'assets/pieces/modern/', // Use fallback
  );

  static const PieceSet alpha = PieceSet(
    name: 'Alpha',
    assetPath: 'assets/pieces/traditional/', // Use fallback
  );

  static const PieceSet merida = PieceSet(
    name: 'Merida',
    assetPath: 'assets/pieces/modern/', // Use fallback
  );

  static const PieceSet cburnett = PieceSet(
    name: 'CBurnett',
    assetPath: 'assets/pieces/traditional/', // Use fallback
  );

  static const PieceSet minimal = PieceSet(
    name: 'Minimal',
    assetPath: 'assets/pieces/modern/', // Use fallback
  );

  static const PieceSet fantasy = PieceSet(
    name: 'Fantasy',
    assetPath: 'assets/pieces/traditional/', // Use fallback
  );

  static PieceSet fromType(PieceSetType type) {
    switch (type) {
      case PieceSetType.traditional:
        return traditional;
      case PieceSetType.modern:
        return modern;
      case PieceSetType.classic:
        return classic;
      case PieceSetType.neo:
        return neo;
      case PieceSetType.wood:
        return wood;
      case PieceSetType.glass:
        return glass;
      case PieceSetType.alpha:
        return alpha;
      case PieceSetType.merida:
        return merida;
      case PieceSetType.cburnett:
        return cburnett;
      case PieceSetType.minimal:
        return minimal;
      case PieceSetType.fantasy:
        return fantasy;
    }
  }

  static List<PieceSet> get allSets => [
    traditional,
    modern,
    classic,
    neo,
    wood,
    glass,
    alpha,
    merida,
    cburnett,
    minimal,
    fantasy,
  ];

  /// Get the asset path for a specific piece
  /// [piece] is in format: 'wK', 'bQ', etc.
  String getAssetPath(String piece) => '$assetPath$piece.svg';
}
