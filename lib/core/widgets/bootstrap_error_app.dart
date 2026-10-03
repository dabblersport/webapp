import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show MaterialApp, ThemeData, ThemeExtension;
import 'package:flutter/widgets.dart';

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
/// `MyApp`'s widget tree reads `Supabase.instance`/`the Material theme` immediately,
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
    // The design-system colours resolve without any bootstrap state, so this
    // screen can always render. `MaterialApp` is only the non-visual host the
    // design-system components require.
    final colors = DabblerColors.resolve(
      theme: DabblerTheme.main,
      brightness: Brightness.light,
    );
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(extensions: <ThemeExtension<dynamic>>[colors]),
      home: Builder(
        builder: (context) {
          final direction = Directionality.of(context);
          return DabblerPage(
            body: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(DabblerSpacing.space8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DabblerBanner(
                      tone: DabblerBannerTone.error,
                      title: 'Dabbler failed to start',
                      message: '$error',
                    ),
                    if (kDebugMode && stackTrace != null) ...[
                      const SizedBox(height: DabblerSpacing.space4),
                      Text(
                        '$stackTrace',
                        maxLines: 16,
                        overflow: TextOverflow.fade,
                        style: DabblerType.caption2
                            .resolveForDirection(direction)
                            .copyWith(color: colors.textTertiary),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
