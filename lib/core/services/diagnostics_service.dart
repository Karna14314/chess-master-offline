import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

final diagnosticsServiceProvider = Provider<LocalDiagnosticsService>((ref) {
  return LocalDiagnosticsService.instance;
});

/// Local-only, privacy-respecting diagnostic and crash log service.
/// All logs remain strictly on device and can only leave via explicit
/// user action using the native OS share sheet.
class LocalDiagnosticsService {
  LocalDiagnosticsService._();
  static final LocalDiagnosticsService instance = LocalDiagnosticsService._();

  File? _logFile;
  bool _initialized = false;
  static const int _maxLogSizeBytes = 512 * 1024; // 512 KB cap
  Future<void> _writeQueue = Future.value();

  File? get logFile => _logFile;
  bool get isInitialized => _initialized;

  @visibleForTesting
  void resetForTesting() {
    _initialized = false;
    _logFile = null;
    _writeQueue = Future.value();
  }

  Future<void> initialize() async {
    if (_initialized) return;
    try {
      final dir = await getApplicationDocumentsDirectory();
      _logFile = File('${dir.path}/chess_diagnostics.log');

      if (!await _logFile!.exists()) {
        await _logFile!.create(recursive: true);
        await _logFile!.writeAsString('=== ChessMaster Diagnostic Log Started [${DateTime.now().toIso8601String()}] ===\n');
      }

      // Capture uncaught Flutter framework errors
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (FlutterErrorDetails details) {
        if (originalOnError != null) {
          originalOnError(details);
        } else {
          FlutterError.presentError(details);
        }
        logError('FlutterFrameworkError: ${details.exceptionAsString()}', stackTrace: details.stack);
      };

      // Capture uncaught platform dispatcher errors
      PlatformDispatcher.instance.onError = (error, stack) {
        logError('Uncaught Platform Error: $error', stackTrace: stack);
        return true;
      };

      _initialized = true;
      logInfo('Local Diagnostics Service initialized successfully');
    } catch (e) {
      debugPrint('Failed to initialize local diagnostics service: $e');
    }
  }

  Future<void> logInfo(String message) async {
    await _writeLog('INFO', message);
  }

  Future<void> logWarning(String message) async {
    await _writeLog('WARN', message);
  }

  Future<void> logError(String message, {StackTrace? stackTrace}) async {
    final fullMessage = stackTrace != null ? '$message\n$stackTrace' : message;
    await _writeLog('ERROR', fullMessage);
  }

  Future<void> _writeLog(String level, String message) async {
    final completer = Completer<void>();
    _writeQueue = _writeQueue.then((_) async {
      try {
        if (_logFile == null) return;
        final timestamp = DateTime.now().toIso8601String();
        final line = '[$timestamp] [$level] $message\n';

        if (await _logFile!.exists()) {
          final length = await _logFile!.length();
          if (length > _maxLogSizeBytes) {
            final content = await _logFile!.readAsString();
            final halfIndex = content.length ~/ 2;
            await _logFile!.writeAsString('[LOG TRUNCATED FOR SIZE]\n${content.substring(halfIndex)}');
          }
        }

        await _logFile!.writeAsString(line, mode: FileMode.append, flush: true);
      } catch (e) {
        debugPrint('Failed to write to diagnostic log file: $e');
      } finally {
        completer.complete();
      }
    });
    return completer.future;
  }

  Future<String> readLogs() async {
    try {
      if (_logFile != null && await _logFile!.exists()) {
        return await _logFile!.readAsString();
      }
    } catch (e) {
      debugPrint('Error reading diagnostic log file: $e');
    }
    return 'No diagnostic logs found.';
  }

  Future<void> clearLogs() async {
    try {
      if (_logFile != null && await _logFile!.exists()) {
        await _logFile!.writeAsString('=== Log Cleared [${DateTime.now().toIso8601String()}] ===\n');
      }
    } catch (e) {
      debugPrint('Error clearing diagnostic log file: $e');
    }
  }

  Future<bool> exportLogFile() async {
    try {
      if (_logFile == null || !await _logFile!.exists()) {
        return false;
      }
      final result = await Share.shareXFiles(
        [XFile(_logFile!.path, mimeType: 'text/plain', name: 'chess_diagnostics.log')],
        subject: 'ChessMaster Offline Diagnostic Log',
      );
      return result.status != ShareResultStatus.dismissed;
    } catch (e) {
      debugPrint('Error sharing diagnostic log file: $e');
      return false;
    }
  }
}
