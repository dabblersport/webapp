import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// Reloads the web page, so the browser fetches the latest deployed bundle.
void reloadPage() {
  final location = globalContext.getProperty<JSObject>('location'.toJS);
  location.callMethod<JSAny?>('reload'.toJS);
}
