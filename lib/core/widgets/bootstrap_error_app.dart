import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Rendered when app bootstrap (env/config/Firebase/Supabase/theme
/// initialization in `main()`) throws before [runApp] can mount the real
/// app tree.
///
/// KAN-196: this used to be a debug-mode `rethrow` in `main()`, which
/// propagates out of `runZonedGuarded`'s body into its `onError` handler,
/// which only prints -- `runApp()` is never called on that path, and the
/// user is left on a blank white page (web) or a splash screen that never
/// gets dismissed (iOS/native, since splash removal is tied to the first
/// Flutter frame). A "best-effort" `runApp(MyApp())` fallback was no better:
/// `MyApp`'s widget tree reads `Supabase.instance`/`AppTheme` immediately,
/// both uninitialized on this path, so it throws again deeper in the tree
/// with nothing rendered either way. Neither branch ever surfaced a real
/// error state. This widget has no dependency on anything bootstrap may
/// have failed to set up, so it can always render.
class BootstrapErrorApp extends StatelessWidget {
  const BootstrapErrorApp({super.key, required this.error, this.stackTrace});

  final Object error;
  final StackTrace? stackTrace;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF1A1025),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Dabbler failed to start',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '$error',
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  if (kDebugMode && stackTrace != null) ...[
                    const SizedBox(height: 12),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 240),
                      child: SingleChildScrollView(
                        child: Text(
                          '$stackTrace',
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 11,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
