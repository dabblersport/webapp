import 'package:flutter/foundation.dart';

/// Simple logger.
///
/// Output is emitted only in debug builds via [debugPrint]. In release builds
/// nothing is logged, so diagnostic detail (and any PII passed in) never reaches
/// device logs (`adb logcat`) or crash-reporter breadcrumbs.
class Logger {
  static void info(String message, [dynamic error]) =>
      _log('INFO', message, error);

  static void error(String message, [dynamic error]) =>
      _log('ERROR', message, error);

  static void warning(String message, [dynamic error]) =>
      _log('WARNING', message, error);

  static void debug(String message, [dynamic error]) =>
      _log('DEBUG', message, error);

  static void _log(String level, String message, dynamic error) {
    if (!kDebugMode) return;
    debugPrint('[$level] $message${error != null ? ' - $error' : ''}');
  }
}
