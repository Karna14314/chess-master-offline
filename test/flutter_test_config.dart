import 'dart:async';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  // Initialize sqflite for ffi tests
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  await testMain();
}
