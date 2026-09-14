import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Service for playing chess game sounds using lowLatency (SoundPool)
/// to eliminate MediaPlayer main-thread Binder polling and ANRs.
class AudioService {
  static AudioService? _instance;
  final AudioPlayer _movePlayer = AudioPlayer(playerId: 'chess_move');
  final AudioPlayer _capturePlayer = AudioPlayer(playerId: 'chess_capture');
  final AudioPlayer _checkPlayer = AudioPlayer(playerId: 'chess_check');
  final AudioPlayer _gameEndPlayer = AudioPlayer(playerId: 'chess_game_end');

  bool _enabled = true;
  bool _initialized = false;
  bool _isInitializing = false;
  DateTime _lastSoundTime = DateTime.fromMillisecondsSinceEpoch(0);
  String _lastSoundPath = '';

  static AudioService get instance {
    _instance ??= AudioService._();
    return _instance!;
  }

  AudioService._() {
    _configureAudioContext();
  }

  static final AudioContext _ambientContext = AudioContext(
    android: const AudioContextAndroid(
      isSpeakerphoneOn: false,
      stayAwake: false,
      contentType: AndroidContentType.sonification,
      usageType: AndroidUsageType.game,
      audioFocus: AndroidAudioFocus.none,
    ),
    iOS: AudioContextIOS(
      category: AVAudioSessionCategory.ambient,
      options: const {AVAudioSessionOptions.mixWithOthers},
    ),
  );

  /// Set up audio context for low latency playback and background music mixing
  void _configureAudioContext() {
    try {
      AudioPlayer.global.setAudioContext(_ambientContext);
    } catch (e) {
      debugPrint('AudioService: Failed to configure AudioContext: $e');
    }
  }

  /// Non-blocking, lazy audio player initialization using SoundPool (lowLatency)
  Future<void> initialize() async {
    if (_initialized || _isInitializing) return;
    _isInitializing = true;

    // Run initialization asynchronously off the main frame loop
    unawaited(
      runZonedGuarded(
        () async {
          try {
            await Future.wait([
              _movePlayer.setAudioContext(_ambientContext),
              _capturePlayer.setAudioContext(_ambientContext),
              _checkPlayer.setAudioContext(_ambientContext),
              _gameEndPlayer.setAudioContext(_ambientContext),
            ]);

            await Future.wait([
              _movePlayer.setPlayerMode(PlayerMode.lowLatency),
              _capturePlayer.setPlayerMode(PlayerMode.lowLatency),
              _checkPlayer.setPlayerMode(PlayerMode.lowLatency),
              _gameEndPlayer.setPlayerMode(PlayerMode.lowLatency),
            ]);

            await Future.wait([
              _movePlayer.setReleaseMode(ReleaseMode.stop),
              _capturePlayer.setReleaseMode(ReleaseMode.stop),
              _checkPlayer.setReleaseMode(ReleaseMode.stop),
              _gameEndPlayer.setReleaseMode(ReleaseMode.stop),
            ]);

            // Preload sources
            await Future.wait([
              _movePlayer.setSource(AssetSource('sounds/move.mp3')),
              _capturePlayer.setSource(AssetSource('sounds/capture.mp3')),
              _checkPlayer.setSource(AssetSource('sounds/check.mp3')),
              _gameEndPlayer.setSource(AssetSource('sounds/game_end.mp3')),
            ]);

            _initialized = true;
          } catch (e) {
            debugPrint('Failed to initialize audio service sources: $e');
          } finally {
            _isInitializing = false;
          }
        },
        (error, stack) {
          debugPrint('AudioService init error: $error');
          _isInitializing = false;
        },
      ),
    );
  }

  /// Enable or disable sound effects
  void setEnabled(bool enabled) {
    _enabled = enabled;
  }

  /// Safely play audio on a player without blocking main UI thread or throwing.
  /// Uses PlayerMode.lowLatency (SoundPool) with a 40ms throttle guard.
  void _playSound(AudioPlayer player, AssetSource source) {
    if (!_enabled) return;

    final now = DateTime.now();
    if (_lastSoundPath == source.path &&
        now.difference(_lastSoundTime).inMilliseconds < 40) {
      return; // Drop rapid duplicate audio triggers to prevent buffer queue saturation
    }
    _lastSoundTime = now;
    _lastSoundPath = source.path;

    unawaited(
      runZonedGuarded(
        () async {
          try {
            await player.play(source, mode: PlayerMode.lowLatency);
          } catch (e) {
            debugPrint('Error playing sound ${source.path}: $e');
          }
        },
        (error, stack) {
          debugPrint('AudioService sound exception: $error');
        },
      ),
    );
  }

  /// Play move sound
  Future<void> playMove() async {
    _playSound(_movePlayer, AssetSource('sounds/move.mp3'));
  }

  /// Play capture sound
  Future<void> playCapture() async {
    _playSound(_capturePlayer, AssetSource('sounds/capture.mp3'));
  }

  /// Play check sound
  Future<void> playCheck() async {
    _playSound(_checkPlayer, AssetSource('sounds/check.mp3'));
  }

  /// Play castle sound
  Future<void> playCastle() async {
    await playMove();
  }

  /// Play game start sound
  Future<void> playGameStart() async {
    _playSound(_movePlayer, AssetSource('sounds/game_start.mp3'));
  }

  /// Play game end sound
  Future<void> playGameEnd() async {
    _playSound(_gameEndPlayer, AssetSource('sounds/game_end.mp3'));
  }

  /// Play low time warning
  Future<void> playLowTime() async {
    _playSound(_movePlayer, AssetSource('sounds/low_time.mp3'));
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

  /// Dispose audio players safely
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
