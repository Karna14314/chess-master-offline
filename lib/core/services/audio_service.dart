import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Service for playing chess game sounds
class AudioService {
  static AudioService? _instance;
  final AudioPlayer _movePlayer = AudioPlayer();
  final AudioPlayer _capturePlayer = AudioPlayer();
  final AudioPlayer _checkPlayer = AudioPlayer();
  final AudioPlayer _gameEndPlayer = AudioPlayer();

  bool _enabled = true;
  bool _initialized = false;

  static AudioService get instance {
    _instance ??= AudioService._();
    return _instance!;
  }

  AudioService._();

  /// Initialize audio players with sources
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Preload sounds for faster playback
      await _movePlayer.setSource(AssetSource('sounds/move.mp3'));
      await _capturePlayer.setSource(AssetSource('sounds/capture.mp3'));
      await _checkPlayer.setSource(AssetSource('sounds/check.mp3'));
      await _gameEndPlayer.setSource(AssetSource('sounds/game_end.mp3'));

      // Reset players after preloading
      await _movePlayer.stop();
      await _capturePlayer.stop();
      await _checkPlayer.stop();
      await _gameEndPlayer.stop();

      _initialized = true;
    } catch (e) {
      print('Failed to initialize audio service: $e');
      // Continue without sound if initialization fails
    }
  }

  /// Enable or disable sound effects
  void setEnabled(bool enabled) {
    _enabled = enabled;
  }

  /// Play move sound
  Future<void> playMove() async {
    if (!_enabled) return;
    try {
      await _movePlayer.stop();
      await _movePlayer.play(AssetSource('sounds/move.mp3'));
    } catch (e) {
      print('Error playing move sound: $e');
    }
  }

  /// Play capture sound
  Future<void> playCapture() async {
    if (!_enabled) return;
    try {
      await _capturePlayer.stop();
      await _capturePlayer.play(AssetSource('sounds/capture.mp3'));
    } catch (e) {
      print('Error playing capture sound: $e');
    }
  }

  /// Play check sound
  Future<void> playCheck() async {
    if (!_enabled) return;
    try {
      await _checkPlayer.stop();
      await _checkPlayer.play(AssetSource('sounds/check.mp3'));
    } catch (e) {
      print('Error playing check sound: $e');
    }
  }

  /// Play castle sound (same as move for now)
  Future<void> playCastle() async {
    await playMove();
  }

  /// Play game start sound
  Future<void> playGameStart() async {
    if (!_enabled) return;
    try {
      await _movePlayer.stop();
      await _movePlayer.play(AssetSource('sounds/game_start.mp3'));
    } catch (e) {
      print('Error playing game start sound: $e');
    }
  }

  /// Play game end sound
  Future<void> playGameEnd() async {
    if (!_enabled) return;
    try {
      await _gameEndPlayer.stop();
      await _gameEndPlayer.play(AssetSource('sounds/game_end.mp3'));
    } catch (e) {
      print('Error playing game end sound: $e');
    }
  }

  /// Play low time warning
  Future<void> playLowTime() async {
    if (!_enabled) return;
    try {
      await _movePlayer.stop();
      await _movePlayer.play(AssetSource('sounds/low_time.mp3'));
    } catch (e) {
      print('Error playing low time sound: $e');
    }
  }

  /// Play sound based on move type
  Future<void> playMoveSound({
    bool isCapture = false,
    bool isCheck = false,
    bool isCheckmate = false,
    bool isCastle = false,
  }) async {
    if (isCheckmate) {
      await playGameEnd();
    } else if (isCheck) {
      await playCheck();
    } else if (isCapture) {
      await playCapture();
    } else if (isCastle) {
      await playCastle();
    } else {
      await playMove();
    }
  }

  /// Dispose audio players
  void dispose() {
    _movePlayer.dispose();
    _capturePlayer.dispose();
    _checkPlayer.dispose();
    _gameEndPlayer.dispose();
  }
}

/// Provider for audio service
final audioServiceProvider = Provider<AudioService>((ref) {
  return AudioService.instance;
});
