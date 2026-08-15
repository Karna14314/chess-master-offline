import 'dart:async';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  // Initialize FFI for tests
  sqfliteFfiInit();
  // Set database factory to FFI for all tests
  databaseFactory = databaseFactoryFfi;

  await testMain();
}
