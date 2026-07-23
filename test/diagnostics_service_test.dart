import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chess_master/core/services/diagnostics_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('diagnostics_test_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'getApplicationDocumentsDirectory') {
          return tempDir.path;
        }
        return null;
      },
    );
    LocalDiagnosticsService.instance.resetForTesting();
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('LocalDiagnosticsService Tests', () {
    test('Service initializes log file locally in documents directory', () async {
      final service = LocalDiagnosticsService.instance;
      await service.initialize();

      expect(service.isInitialized, isTrue);
      expect(service.logFile, isNotNull);
      expect(await service.logFile!.exists(), isTrue);

      final content = await service.readLogs();
      expect(content, contains('ChessMaster Diagnostic Log Started'));
    });

    test('Writes INFO, WARN, and ERROR log entries correctly', () async {
      final service = LocalDiagnosticsService.instance;
      await service.initialize();

      await service.logInfo('Test info message');
      await service.logWarning('Test warning message');
      await service.logError('Test error message', stackTrace: StackTrace.current);

      final logs = await service.readLogs();
      expect(logs, contains('[INFO] Test info message'));
      expect(logs, contains('[WARN] Test warning message'));
      expect(logs, contains('[ERROR] Test error message'));
    });

    test('Clears log file content correctly', () async {
      final service = LocalDiagnosticsService.instance;
      await service.initialize();

      await service.logInfo('Sample log to be cleared');
      await service.clearLogs();

      final logs = await service.readLogs();
      expect(logs, contains('Log Cleared'));
      expect(logs, isNot(contains('Sample log to be cleared')));
    });
  });
}
