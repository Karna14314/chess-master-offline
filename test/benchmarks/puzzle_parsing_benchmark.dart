import 'dart:convert';
import 'dart:io';
import 'package:chess_master/models/puzzle_model.dart';

void main() {
  final file = File('assets/puzzles/puzzles.json');
  if (!file.existsSync()) {
    print('Error: assets/puzzles/puzzles.json not found');
    exit(1);
  }

  final jsonString = file.readAsStringSync();

  print(
    'Starting benchmark for JSON parsing (Size: ${(jsonString.length / 1024).toStringAsFixed(2)} KB)...',
  );

  final stopwatch = Stopwatch()..start();

  // Measure decoding
  final List<dynamic> jsonList = json.decode(jsonString);
  final decodeTime = stopwatch.elapsedMilliseconds;

  // Measure mapping
  final puzzles = jsonList.map((j) => Puzzle.fromJson(j)).toList();
  final totalTime = stopwatch.elapsedMilliseconds;

  print('JSON Decode Time: ${decodeTime}ms');
  print('Mapping Time: ${totalTime - decodeTime}ms');
  print('Total Time: ${totalTime}ms');
  print('Parsed ${puzzles.length} puzzles.');
}
