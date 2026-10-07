import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:ui' show Color;

String _hex(Color c) {
  String two(double v) =>
      (v * 255).round().clamp(0, 255).toRadixString(16).padLeft(2, '0');
  return '#${two(c.r)}${two(c.g)}${two(c.b)}';
}

/// Paints the document ground and the browser's `theme-color` with [color].
///
/// index.html starts both at the launch purple for the splash video; once the
/// app is showing (and on every theme toggle) this hands them to the page
/// background, so the PWA's status bar and the area behind the page match it.
/// Any `theme-color` meta (including `media` variants) is replaced by one
/// without `media`, because the app's theme mode, not the OS, decides.
void setWebChromeColor(Color color) {
  final hex = _hex(color);
  final doc = globalContext['document'] as JSObject?;
  if (doc == null) return;

  final metas = doc.callMethod<JSObject>(
    'querySelectorAll'.toJS,
    'meta[name="theme-color"]'.toJS,
  );
  final count = (metas['length'] as JSNumber).toDartInt;
  for (var i = 0; i < count; i++) {
    (metas.callMethod<JSObject>(
      'item'.toJS,
      i.toJS,
    )).callMethod<JSAny?>('remove'.toJS);
  }
  final meta = doc.callMethod<JSObject>('createElement'.toJS, 'meta'.toJS);
  meta.callMethod<JSAny?>('setAttribute'.toJS, 'name'.toJS, 'theme-color'.toJS);
  meta.callMethod<JSAny?>('setAttribute'.toJS, 'content'.toJS, hex.toJS);
  (doc['head'] as JSObject).callMethod<JSAny?>('appendChild'.toJS, meta);

  for (final key in ['documentElement', 'body']) {
    final el = doc[key] as JSObject?;
    final style = el?['style'] as JSObject?;
    style?['backgroundColor'] = hex.toJS;
  }
}
