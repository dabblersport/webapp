import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:ui' show Brightness, Color;

String _hex(Color c) {
  String two(double v) =>
      (v * 255).round().clamp(0, 255).toRadixString(16).padLeft(2, '0');
  return '#${two(c.r)}${two(c.g)}${two(c.b)}';
}

/// Keeps both `theme-color` metas on [top] (the status bar's surface), the
/// document background on [bottom] (the surface under the browser's bottom
/// toolbar) and `color-scheme` on the app's theme [brightness]. Called again on
/// every route change.
///
/// index.html already ships the right static values for the OS scheme; this is
/// for the in-app theme toggle, which can differ from the OS. Both the light
/// and the dark `theme-color` meta get [color] (the app's mode, not the OS,
/// decides), and html/body get the same background and `color-scheme`.
void setWebChromeColor(Color top, Color bottom, Brightness brightness) {
  final hex = _hex(top);
  final bottomHex = _hex(bottom);
  final doc = globalContext['document'] as JSObject?;
  if (doc == null) return;

  final metas = doc.callMethod<JSObject>(
    'querySelectorAll'.toJS,
    'meta[name="theme-color"]'.toJS,
  );
  final count = (metas['length'] as JSNumber).toDartInt;
  if (count == 0) {
    final meta = doc.callMethod<JSObject>('createElement'.toJS, 'meta'.toJS);
    meta.callMethod<JSAny?>(
      'setAttribute'.toJS,
      'name'.toJS,
      'theme-color'.toJS,
    );
    meta.callMethod<JSAny?>('setAttribute'.toJS, 'content'.toJS, hex.toJS);
    (doc['head'] as JSObject).callMethod<JSAny?>('appendChild'.toJS, meta);
  }
  for (var i = 0; i < count; i++) {
    metas
        .callMethod<JSObject>('item'.toJS, i.toJS)
        .callMethod<JSAny?>('setAttribute'.toJS, 'content'.toJS, hex.toJS);
  }

  final scheme = brightness == Brightness.dark ? 'dark' : 'light';
  for (final key in ['documentElement', 'body']) {
    final style = (doc[key] as JSObject?)?['style'] as JSObject?;
    style?['backgroundColor'] = bottomHex.toJS;
    style?['colorScheme'] = scheme.toJS;
  }
}
