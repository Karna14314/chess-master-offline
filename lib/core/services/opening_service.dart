import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import '../models/opening_book.dart';

/// Comprehensive Master Opening Playbook and offline opening database.
///
/// Loads dynamically from `assets/lessons/openings.json` (extracted from Lichess).
/// **Zero chess opening data is hardcoded in Dart source code.**
///
/// Used for:
/// 1. Identifying the played opening and ECO code in any game.
/// 2. Protecting opening book moves from false Inaccuracy/Mistake tags in analysis.
/// 3. Providing an interactive offline Opening Playbook explorer.
class OpeningService {
  OpeningService._();
  static final OpeningService instance = OpeningService._();

  static const String categoryE4 = "King's Pawn (1. e4)";
  static const String categoryD4 = "Queen's Pawn (1. d4)";
  static const String categoryFlank = "Flank & Modern";

  /// All categories in display order
  static const List<String> categories = [
    categoryE4,
    categoryD4,
    categoryFlank,
  ];

  final List<OpeningEntry> _openings = [];
  bool _isLoaded = false;

  bool get isLoaded => _isLoaded;

  /// Ensure data is loaded (reads from assets or local filesystem)
  Future<void> initialize([String? customJson]) async {
    if (_isLoaded && customJson == null) return;
    try {
      final String content;
      if (customJson != null) {
        content = customJson;
      } else {
        content = await rootBundle.loadString('assets/lessons/openings.json');
      }
      loadFromJsonString(content);
    } catch (_) {
      // In standalone tests or non-bundle environments, fallback to File IO
      _ensureLoadedFromFileSync();
    }
  }

  /// Synchronous fallback loader for unit test environments
  void _ensureLoadedFromFileSync() {
    if (_isLoaded) return;
    try {
      final file = File('assets/lessons/openings.json');
      if (file.existsSync()) {
        loadFromJsonString(file.readAsStringSync());
      }
    } catch (_) {}
  }

  /// Parse and populate openings from a JSON string
  void loadFromJsonString(String jsonString) {
    final List<dynamic> decoded = json.decode(jsonString);
    _openings.clear();
    for (final item in decoded) {
      if (item is Map<String, dynamic>) {
        _openings.add(OpeningEntry.fromMap(item));
      } else if (item is Map) {
        _openings.add(OpeningEntry.fromMap(Map<String, dynamic>.from(item)));
      }
    }
    _isLoaded = true;
  }

  /// Get all openings in the playbook
  List<OpeningEntry> get allOpenings {
    _ensureLoadedFromFileSync();
    return List.unmodifiable(_openings);
  }

  /// Get openings by category
  List<OpeningEntry> getOpeningsByCategory(String category) {
    _ensureLoadedFromFileSync();
    return _openings.where((o) {
      if (o.category == category) return true;
      if (category == categoryFlank &&
          (o.category == 'Flank Openings' || o.category == 'Flank & Modern')) {
        return true;
      }
      return false;
    }).toList();
  }

  /// Search openings by name, ECO code, or moves
  List<OpeningEntry> searchOpenings(String query) {
    _ensureLoadedFromFileSync();
    if (query.trim().isEmpty) return allOpenings;
    final q = query.trim().toLowerCase();
    return _openings.where((o) {
      return o.name.toLowerCase().contains(q) ||
          o.eco.toLowerCase().contains(q) ||
          o.formattedMoves.toLowerCase().contains(q) ||
          o.category.toLowerCase().contains(q);
    }).toList();
  }

  /// Identify the most specific opening matching a game's move sequence.
  ///
  /// Matches from deepest line to shallowest line.
  OpeningEntry? identifyOpening(List<String> movesSan) {
    _ensureLoadedFromFileSync();
    if (movesSan.isEmpty) return null;

    OpeningEntry? bestMatch;
    int bestMatchLength = 0;

    for (final opening in _openings) {
      final len = opening.movesSan.length;
      if (len <= movesSan.length) {
        bool matches = true;
        for (int i = 0; i < len; i++) {
          if (_normalizeSan(movesSan[i]) != _normalizeSan(opening.movesSan[i])) {
            matches = false;
            break;
          }
        }
        if (matches && len > bestMatchLength) {
          bestMatch = opening;
          bestMatchLength = len;
        }
      } else {
        bool isPrefix = true;
        for (int i = 0; i < movesSan.length; i++) {
          if (_normalizeSan(movesSan[i]) != _normalizeSan(opening.movesSan[i])) {
            isPrefix = false;
            break;
          }
        }
        if (isPrefix && movesSan.length > bestMatchLength) {
          bestMatch = opening;
          bestMatchLength = movesSan.length;
        }
      }
    }

    return bestMatch;
  }

  /// Check whether a candidate move continues a recognized opening line.
  ///
  /// Used in the analysis pipeline to grant `MoveClassification.book` immunity,
  /// preventing opening theory moves from being penalized by shallow engine noise.
  bool isBookMove(List<String> movesSoFar, String candidateMoveSan) {
    _ensureLoadedFromFileSync();
    final nextPly = movesSoFar.length;
    final normCandidate = _normalizeSan(candidateMoveSan);

    for (final opening in _openings) {
      if (opening.movesSan.length > nextPly) {
        bool match = true;
        for (int i = 0; i < nextPly; i++) {
          if (_normalizeSan(movesSoFar[i]) != _normalizeSan(opening.movesSan[i])) {
            match = false;
            break;
          }
        }
        if (match && _normalizeSan(opening.movesSan[nextPly]) == normCandidate) {
          return true;
        }
      }
    }
    return false;
  }

  /// Get candidate next book moves given the moves played so far
  List<String> getNextBookMoves(List<String> movesSoFar) {
    _ensureLoadedFromFileSync();
    final nextPly = movesSoFar.length;
    final Set<String> candidates = {};

    for (final opening in _openings) {
      if (opening.movesSan.length > nextPly) {
        bool match = true;
        for (int i = 0; i < nextPly; i++) {
          if (_normalizeSan(movesSoFar[i]) != _normalizeSan(opening.movesSan[i])) {
            match = false;
            break;
          }
        }
        if (match) {
          candidates.add(opening.movesSan[nextPly]);
        }
      }
    }
    return candidates.toList();
  }

  /// Normalize SAN for robust matching (removes check '+', mate '#', captures 'x')
  static String _normalizeSan(String san) {
    return san.replaceAll('+', '').replaceAll('#', '').replaceAll('x', '').trim();
  }
}
