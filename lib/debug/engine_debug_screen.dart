import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chess_master/core/services/stockfish_service.dart';
import 'package:chess_master/providers/engine_provider.dart';

/// Debug screen to test Stockfish engine functionality
class EngineDebugScreen extends ConsumerStatefulWidget {
  const EngineDebugScreen({super.key});

  @override
  ConsumerState<EngineDebugScreen> createState() => _EngineDebugScreenState();
}

class _EngineDebugScreenState extends ConsumerState<EngineDebugScreen> {
  String _status = 'Not initialized';
  String _testResult = '';
  bool _isTesting = false;

  @override
  Widget build(BuildContext context) {
    final engineState = ref.watch(engineProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Engine Debug'),
        backgroundColor: Colors.green[900],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Stockfish Engine Status',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            _buildStatusCard('Initialization Status', _status),
            _buildStatusCard(
              'Engine Ready',
              StockfishService.instance.isReady ? 'Yes ✓' : 'No ✗',
            ),
            _buildStatusCard(
              'Currently Thinking',
              engineState.isThinking ? 'Yes' : 'No',
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isTesting ? null : _testInitialization,
              child: const Text('Test Initialization'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _isTesting ? null : _testBestMove,
              child: const Text('Test Best Move (Starting Position)'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _isTesting ? null : _testDifferentElo,
              child: const Text('Test Different ELO Levels'),
            ),
            const SizedBox(height: 24),
            if (_isTesting) const Center(child: CircularProgressIndicator()),
            if (_testResult.isNotEmpty)
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      _testResult,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(String label, String value) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(label),
        trailing: Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Future<void> _testInitialization() async {
    setState(() {
      _isTesting = true;
      _testResult = 'Testing initialization...\n';
    });

    try {
      final service = StockfishService.instance;
      final startTime = DateTime.now();

      await service.initialize();

      final elapsed = DateTime.now().difference(startTime);

      setState(() {
        _status = 'Initialized successfully';
        _testResult += 'Success! Took ${elapsed.inMilliseconds}ms\n';
        _testResult += 'Engine ready: ${service.isReady}\n';
        _isTesting = false;
      });
    } catch (e) {
      setState(() {
        _status = 'Failed: $e';
        _testResult += 'Error: $e\n';
        _isTesting = false;
      });
    }
  }

  Future<void> _testBestMove() async {
    setState(() {
      _isTesting = true;
      _testResult = 'Testing best move calculation...\n';
    });

    try {
      const startFen =
          'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

      final service = StockfishService.instance;
      if (!service.isReady) {
        await service.initialize();
      }

      final startTime = DateTime.now();

      final result = await service.getBestMove(
        fen: startFen,
        depth: 10,
        thinkTimeMs: 1500,
      );

      final elapsed = DateTime.now().difference(startTime);

      setState(() {
        _testResult += 'Success!\n';
        _testResult += 'Time taken: ${elapsed.inMilliseconds}ms\n';
        _testResult += 'Best move: ${result.bestMove}\n';
        _testResult += 'Evaluation: ${result.evaluation}\n';
        _testResult += 'Valid: ${result.isValid}\n';
        _isTesting = false;
      });
    } catch (e) {
      setState(() {
        _testResult += 'Error: $e\n';
        _isTesting = false;
      });
    }
  }

  Future<void> _testDifferentElo() async {
    setState(() {
      _isTesting = true;
      _testResult = 'Testing different ELO levels...\n';
    });

    try {
      const testFen =
          'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1';

      final service = StockfishService.instance;
      if (!service.isReady) {
        await service.initialize();
      }

      final eloLevels = [800, 1400, 2000];

      for (final elo in eloLevels) {
        _testResult += '\n--- Testing ELO $elo ---\n';
        setState(() {});

        // Awaited so the ELO options land before this iteration's `go`.
        await service.setSkillLevel(elo);

        final startTime = DateTime.now();
        final result = await service.getBestMove(
          fen: testFen,
          depth: 8,
          thinkTimeMs: 1000,
        );
        final elapsed = DateTime.now().difference(startTime);

        _testResult += 'Move: ${result.bestMove}\n';
        _testResult += 'Time: ${elapsed.inMilliseconds}ms\n';
        _testResult += 'Eval: ${result.evaluation}\n';
        setState(() {});
      }

      setState(() {
        _testResult += '\nAll tests completed!\n';
        _isTesting = false;
      });
    } catch (e) {
      setState(() {
        _testResult += 'Error: $e\n';
        _isTesting = false;
      });
    }
  }
}
