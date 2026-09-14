import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chess_master/core/theme/board_themes.dart';
import 'package:chess_master/providers/settings_provider.dart';

/// Centralized board wrapper that isolates theme styling, aspect ratio,
/// and provides an extension point for future board theme and piece set customizers.
class ThemedBoardContainer extends ConsumerWidget {
  final Widget child;
  final double aspectRatio;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final bool showShadow;

  const ThemedBoardContainer({
    super.key,
    required this.child,
    this.aspectRatio = 1.0,
    this.padding = const EdgeInsets.all(4.0),
    this.borderRadius = 10.0,
    this.showShadow = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    // Board theme & piece set loaded from settings, with space for future sets
    final boardTheme = BoardTheme.fromType(settings.boardTheme);

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: boardTheme.darkSquare.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(borderRadius + 2),
        border: Border.all(
          color: boardTheme.darkSquare.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: showShadow
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: AspectRatio(
          aspectRatio: aspectRatio,
          child: child,
        ),
      ),
    );
  }
}
