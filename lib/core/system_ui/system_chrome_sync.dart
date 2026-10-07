import 'package:dabbler/core/system_ui/web_chrome_stub.dart'
    if (dart.library.js_interop) 'package:dabbler/core/system_ui/web_chrome_web.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart' show Theme;
import 'package:flutter/widgets.dart';

/// The overlay style for system bars sitting on [pageColor] in [brightness]:
/// both bars take the page ground, icons contrast with it.
///
/// Android reads `statusBarIconBrightness` / `systemNavigationBarIconBrightness`
/// (the icons' own brightness: dark icons on a light page); iOS reads
/// `statusBarBrightness` (the brightness of the bar's background, the
/// opposite of the icons).
SystemUiOverlayStyle systemOverlayStyleFor(
  Color pageColor,
  Brightness brightness,
) {
  final icons = brightness == Brightness.light
      ? Brightness.dark
      : Brightness.light;
  return SystemUiOverlayStyle(
    statusBarColor: pageColor,
    statusBarIconBrightness: icons,
    statusBarBrightness: brightness,
    systemNavigationBarColor: pageColor,
    systemNavigationBarDividerColor: pageColor,
    systemNavigationBarIconBrightness: icons,
    systemNavigationBarContrastEnforced: false,
  );
}

/// The single place that styles the platform chrome from the active theme:
/// the design system's page ground (`DabblerColors.bgPrimary`) and the theme
/// brightness decide the status bar and navigation bar (Android, iOS) and, on
/// the web, the document background and `theme-color`. Mount it once, inside
/// the app's Theme.
class SystemChromeSync extends StatelessWidget {
  const SystemChromeSync({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final page = DabblerColors.of(context).bgPrimary;
    final brightness = Theme.of(context).brightness;
    if (kIsWeb) {
      SchedulerBinding.instance.addPostFrameCallback(
        (_) => setWebChromeColor(page, brightness),
      );
    }
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: systemOverlayStyleFor(page, brightness),
      child: child,
    );
  }
}
