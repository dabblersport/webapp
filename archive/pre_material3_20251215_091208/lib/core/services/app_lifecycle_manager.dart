import 'package:flutter/widgets.dart';

/// Service to manage app lifecycle events
/// Used to detect when the app resumes from background
class AppLifecycleManager with WidgetsBindingObserver {
  static final AppLifecycleManager _instance = AppLifecycleManager._internal();
  factory AppLifecycleManager() => _instance;
  AppLifecycleManager._internal();

  final List<VoidCallback> _resumeCallbacks = [];
  bool _isInitialized = false;

  /// Initialize the lifecycle manager
  void init() {
    if (_isInitialized) return;
    WidgetsBinding.instance.addObserver(this);
    _isInitialized = true;
    debugPrint('AppLifecycleManager initialized');
  }

  /// Dispose the lifecycle manager
  void dispose() {
    if (!_isInitialized) return;
    WidgetsBinding.instance.removeObserver(this);
    _resumeCallbacks.clear();
    _isInitialized = false;
  }

  /// Register a callback to be called when the app resumes
  void onResume(VoidCallback callback) {
    if (!_resumeCallbacks.contains(callback)) {
      _resumeCallbacks.add(callback);
    }
  }

  /// Unregister a callback
  void offResume(VoidCallback callback) {
    _resumeCallbacks.remove(callback);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    debugPrint('App lifecycle state changed to: $state');

    if (state == AppLifecycleState.resumed) {
      // App has returned from background
      debugPrint(
        'App resumed - triggering ${_resumeCallbacks.length} callbacks',
      );
      for (final callback in _resumeCallbacks) {
        try {
          callback();
        } catch (e) {
          debugPrint('Error in resume callback: $e');
        }
      }
    }
  }
}
