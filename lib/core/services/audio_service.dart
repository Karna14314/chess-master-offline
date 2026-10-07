import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Service for playing chess game sounds using lowLatency (SoundPool)
/// to eliminate MediaPlayer main-thread Binder polling and ANRs.
class AudioService {
  static AudioService? _instance;
  AudioPlayer? _movePlayer;
  AudioPlayer? _capturePlayer;
  AudioPlayer? _checkPlayer;
  AudioPlayer? _gameEndPlayer;

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
    try {
      _configureAudioContext();
    } catch (_) {}
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
    ),
  );

  AudioPlayer? _createPlayerSafe(String id) {
    try {
      return AudioPlayer(playerId: id);
    } catch (e) {
      debugPrint('AudioService: Failed to create AudioPlayer $id: $e');
      return null;
    }
  }

  AudioPlayer? get movePlayer => _movePlayer ??= _createPlayerSafe('chess_move');
  AudioPlayer? get capturePlayer => _capturePlayer ??= _createPlayerSafe('chess_capture');
  AudioPlayer? get checkPlayer => _checkPlayer ??= _createPlayerSafe('chess_check');
  AudioPlayer? get gameEndPlayer => _gameEndPlayer ??= _createPlayerSafe('chess_game_end');

  /// Set up audio context for low latency playback and background music mixing
  void _configureAudioContext() {
    try {
      AudioPlayer.global.setAudioContext(_ambientContext).catchError((e) {
        debugPrint('AudioService: Failed to configure AudioContext: $e');
      });
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
            final players = [movePlayer, capturePlayer, checkPlayer, gameEndPlayer]
                .whereType<AudioPlayer>()
                .toList();

            for (final player in players) {
              try {
                await player.setAudioContext(_ambientContext);
                await player.setPlayerMode(PlayerMode.lowLatency);
                await player.setReleaseMode(ReleaseMode.stop);
              } catch (e) {
                debugPrint('Audio player configuration warning: $e');
              }
            }

            // Preload sources defensively
            try {
              if (movePlayer != null) await movePlayer!.setSource(AssetSource('sounds/move.mp3'));
              if (capturePlayer != null) await capturePlayer!.setSource(AssetSource('sounds/capture.mp3'));
              if (checkPlayer != null) await checkPlayer!.setSource(AssetSource('sounds/check.mp3'));
              if (gameEndPlayer != null) await gameEndPlayer!.setSource(AssetSource('sounds/game_end.mp3'));
            } catch (e) {
              debugPrint('Audio preload sources warning: $e');
            }

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
  void _playSound(AudioPlayer? player, AssetSource source) {
    if (!_enabled || player == null) return;

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
    _playSound(movePlayer, AssetSource('sounds/move.mp3'));
  }

  /// Play capture sound
  Future<void> playCapture() async {
    _playSound(capturePlayer, AssetSource('sounds/capture.mp3'));
  }

  /// Play check sound
  Future<void> playCheck() async {
    _playSound(checkPlayer, AssetSource('sounds/check.mp3'));
  }

  /// Play castle sound
  Future<void> playCastle() async {
    await playMove();
  }

  /// Play game start sound
  Future<void> playGameStart() async {
    _playSound(movePlayer, AssetSource('sounds/game_start.mp3'));
  }

  /// Play game end sound
  Future<void> playGameEnd() async {
    _playSound(gameEndPlayer, AssetSource('sounds/game_end.mp3'));
  }

  /// Play low time warning
  Future<void> playLowTime() async {
    _playSound(movePlayer, AssetSource('sounds/low_time.mp3'));
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
    try {
      _movePlayer?.dispose();
    } catch (_) {}
    try {
      _capturePlayer?.dispose();
    } catch (_) {}
    try {
      _checkPlayer?.dispose();
    } catch (_) {}
    try {
      _gameEndPlayer?.dispose();
    } catch (_) {}
    _movePlayer = null;
    _capturePlayer = null;
    _checkPlayer = null;
    _gameEndPlayer = null;
  }
}

/// Provider for audio service
final audioServiceProvider = Provider<AudioService>((ref) {
  return AudioService.instance;
});
