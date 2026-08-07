import re

with open('lib/providers/analysis_provider.dart', 'r') as f:
    content = f.read()

# Make sure goToMove uses stopAnalysis properly by waiting after calling it
old_goToMove = '''  Future<void> goToMove(int moveIndex) async {
    if (moveIndex < -1 || moveIndex >= state.originalMoves.length) return;

    // Cancel any running analysis
    stopAnalysis();
    // Give the engine loop a chance to exit before starting new analysis
    await Future.delayed(Duration.zero);'''

new_goToMove = '''  Future<void> goToMove(int moveIndex) async {
    if (moveIndex < -1 || moveIndex >= state.originalMoves.length) return;

    // Cancel any running analysis
    stopAnalysis();
    // Give the engine loop a chance to exit before starting new analysis
    await Future.delayed(Duration.zero);'''

# Actually we want to check what is in goToMove right now
