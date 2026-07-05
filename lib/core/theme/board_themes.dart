import 'package:flutter/material.dart';

/// Chess board visual themes
enum BoardThemeType { classicWood, modernBlue, forestGreen }

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

  /// Get theme by type
  static BoardTheme fromType(BoardThemeType type) {
    switch (type) {
      case BoardThemeType.classicWood:
        return classicWood;
      case BoardThemeType.modernBlue:
        return modernBlue;
      case BoardThemeType.forestGreen:
        return forestGreen;
    }
  }

  /// Get all available themes
  static List<BoardTheme> get allThemes => [
    classicWood,
    modernBlue,
    forestGreen,
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
