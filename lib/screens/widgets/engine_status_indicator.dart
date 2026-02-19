import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chess_master/core/models/chess_models.dart';
import 'package:chess_master/providers/engine_provider.dart';

class EngineStatusIndicator extends ConsumerWidget {
  const EngineStatusIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.watch(stockfishServiceProvider);

    return ValueListenableBuilder<EngineStatus>(
      valueListenable: service.statusNotifier,
      builder: (context, status, _) {
        Color color;
        String tooltip;

        switch (status) {
          case EngineStatus.ready:
            color = Colors.green;
            tooltip = 'Stockfish Active';
            break;
          case EngineStatus.usingFallback:
            color = Colors.amber;
            tooltip = 'Simple Bot (Stockfish Offline)';
            break;
          case EngineStatus.initializing:
            color = Colors.blue;
            tooltip = 'Initializing Engine...';
            break;
          case EngineStatus.failed:
            color = Colors.red;
            tooltip = 'Engine Error';
            break;
          case EngineStatus.disposed:
            color = Colors.grey;
            tooltip = 'Engine Stopped';
            break;
        }

        return Tooltip(
          message: tooltip,
          child: Container(
            width: 12,
            height: 12,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withOpacity(0.5),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.5),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
