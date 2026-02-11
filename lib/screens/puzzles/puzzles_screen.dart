import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chess_master/core/theme/app_theme.dart';

class PuzzlesScreen extends ConsumerWidget {
  const PuzzlesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: Center(
        child: Text('Puzzles Screen'),
      ),
    );
  }
}
