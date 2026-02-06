/// Simple logger implementation for the profile service
class Logger {
  static void info(String message, [dynamic error]) {
    print('[INFO] $message${error != null ? ' - $error' : ''}');
  }

  static void error(String message, [dynamic error]) {
    print('[ERROR] $message${error != null ? ' - $error' : ''}');
  }

  static void warning(String message, [dynamic error]) {
    print('[WARNING] $message${error != null ? ' - $error' : ''}');
  }

  static void debug(String message, [dynamic error]) {
    print('[DEBUG] $message${error != null ? ' - $error' : ''}');
  }
}
