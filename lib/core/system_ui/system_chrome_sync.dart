import 'package:dabbler/core/system_ui/web_chrome_stub.dart'
    if (dart.library.js_interop) 'package:dabbler/core/system_ui/web_chrome_web.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart' show Theme, ThemeData;
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// The overlay style for a status bar over [top] and a navigation bar over
/// [bottom]. Each icon set contrasts with the colour behind it, computed from
/// that colour's luminance (not from the theme).
///
/// Android reads `statusBarIconBrightness` / `systemNavigationBarIconBrightness`
/// (the icons' own brightness: dark icons on a light surface); iOS reads
/// `statusBarBrightness` (the brightness of the bar's background, the
/// opposite of the icons).
SystemUiOverlayStyle systemOverlayStyleFor(Color top, Color bottom) {
  Brightness icons(Color c) =>
      ThemeData.estimateBrightnessForColor(c) == Brightness.light
      ? Brightness.dark
      : Brightness.light;
  return SystemUiOverlayStyle(
    statusBarColor: top,
    statusBarIconBrightness: icons(top),
    statusBarBrightness: ThemeData.estimateBrightnessForColor(top),
    systemNavigationBarColor: bottom,
    systemNavigationBarDividerColor: bottom,
    systemNavigationBarIconBrightness: icons(bottom),
    systemNavigationBarContrastEnforced: false,
  );
}

class _Claim {
  _Claim(this.top, this.bottom);
  Color? top;
  Color? bottom;
}

/// What [SystemChromeSurface] talks to: claims the nearest [SystemChromeSync]
/// keeps, in the order they were first made. The last claim with a colour wins,
/// so a pushed route's surface covers the one below and popping it restores
/// that one.
class SystemChromeScope extends InheritedWidget {
  const SystemChromeScope({
    super.key,
    required this.state,
    required super.child,
  });

  final SystemChromeSyncState state;

  static SystemChromeSyncState? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<SystemChromeScope>()?.state;

  @override
  bool updateShouldNotify(SystemChromeScope oldWidget) =>
      oldWidget.state != state;
}

/// The single place that styles the platform chrome: the design system's page
/// ground (`DabblerColors.bgPrimary`) by default, or the surface a screen
/// declares through [SystemChromeSurface]. Drives the status and navigation
/// bars (Android, iOS) and, on the web, the `theme-color` metas and the
/// document background. Mount it once, inside the app's Theme.
class SystemChromeSync extends StatefulWidget {
  const SystemChromeSync({super.key, required this.child});

  final Widget child;

  @override
  State<SystemChromeSync> createState() => SystemChromeSyncState();
}

class SystemChromeSyncState extends State<SystemChromeSync> {
  final List<_Claim> _claims = <_Claim>[];

  /// Adds or updates [token]'s claim. Call outside of build.
  void claim(Object token, Color? top, Color? bottom) {
    final existing = _tokens[token];
    if (existing == null) {
      final c = _Claim(top, bottom);
      _tokens[token] = c;
      _claims.add(c);
    } else {
      existing.top = top;
      existing.bottom = bottom;
    }
    if (mounted) setState(() {});
  }

  /// Removes [token]'s claim. Call outside of build.
  void release(Object token) {
    final c = _tokens.remove(token);
    if (c == null) return;
    _claims.remove(c);
    if (mounted) setState(() {});
  }

  final Map<Object, _Claim> _tokens = <Object, _Claim>{};

  Color? _lastOf(Color? Function(_Claim c) pick) {
    for (final c in _claims.reversed) {
      final v = pick(c);
      if (v != null) return v;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final page = DabblerColors.of(context).bgPrimary;
    final brightness = Theme.of(context).brightness;
    final top = _lastOf((c) => c.top) ?? page;
    final bottom = _lastOf((c) => c.bottom) ?? page;
    if (kIsWeb) {
      SchedulerBinding.instance.addPostFrameCallback(
        (_) => setWebChromeColor(top, bottom, brightness),
      );
    }
    return SystemChromeScope(
      state: this,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: systemOverlayStyleFor(top, bottom),
        child: widget.child,
      ),
    );
  }
}

/// Declares the colour of the surface at the top and/or bottom of a screen, so
/// the status bar and navigation bar take it instead of the page background.
/// While this widget is in the tree it is the effective colour (the latest one
/// wins); when it leaves (the route is popped) the previous colour returns.
///
/// Give it the colour from the same token the header or bar paints with.
class SystemChromeSurface extends StatefulWidget {
  const SystemChromeSurface({
    super.key,
    this.top,
    this.bottom,
    required this.child,
  });

  /// The coloured band a detail header draws: the header's own fill, read
  /// through `DabblerDetailHeader.fillOf` with the same [tile] / [theme] the
  /// header gets, so the status bar can never disagree with the band.
  static Widget detailHeader({
    Key? key,
    DabblerDetailHeaderTile? tile,
    DabblerTheme theme = DabblerTheme.sport,
    required Widget child,
  }) => Builder(
    key: key,
    builder: (context) => SystemChromeSurface(
      top: DabblerDetailHeader.fillOf(context, tile: tile, theme: theme),
      child: child,
    ),
  );

  final Color? top;
  final Color? bottom;
  final Widget child;

  @override
  State<SystemChromeSurface> createState() => _SystemChromeSurfaceState();
}

class _SystemChromeSurfaceState extends State<SystemChromeSurface> {
  final Object _token = Object();
  SystemChromeSyncState? _sync;

  void _later(void Function(SystemChromeSyncState s) f) {
    final s = _sync;
    if (s == null) return;
    SchedulerBinding.instance.addPostFrameCallback((_) => f(s));
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync = SystemChromeScope.maybeOf(context);
    _later((s) => s.claim(_token, widget.top, widget.bottom));
  }

  @override
  void didUpdateWidget(SystemChromeSurface old) {
    super.didUpdateWidget(old);
    if (old.top != widget.top || old.bottom != widget.bottom) {
      _later((s) => s.claim(_token, widget.top, widget.bottom));
    }
  }

  @override
  void dispose() {
    _later((s) => s.release(_token));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
