// logger.dart
// Simple logger utility for Dabbler

import 'package:flutter/foundation.dart';

class Logger {
  static void log(String message) {
    if (kDebugMode) {
      // ignore: avoid_print
      print('[LOG] $message');
    }
  }

  static void info(String message) {
    if (kDebugMode) {
      // ignore: avoid_print
      print('[INFO] $message');
    }
  }

  static void error(String message, [Object? error, StackTrace? stackTrace]) {
    if (kDebugMode) {
      // ignore: avoid_print
      print('[ERROR] $message');
      if (error != null) {
        // ignore: avoid_print
        print('Error: $error');
      }
      if (stackTrace != null) {
        // ignore: avoid_print
        print('StackTrace: $stackTrace');
      }
    }
  }
}
