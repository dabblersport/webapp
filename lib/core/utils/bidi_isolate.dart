import 'package:flutter/widgets.dart';

const String _fsi = '\u2068';
const String _pdi = '\u2069';

/// Wraps user-generated [text] in a first-strong isolate (FSI … PDI) when the
/// surrounding direction is right-to-left, so a Latin title or handle inside an
/// Arabic sentence cannot reorder the punctuation or words around it.
///
/// Left-to-right output is returned unchanged, byte for byte. Null and empty
/// become the empty string, and text that is already isolated is not wrapped
/// twice.
String bidiIsolate(String? text, TextDirection direction) {
  if (text == null || text.isEmpty) return '';
  if (direction != TextDirection.rtl) return text;
  if (text.startsWith(_fsi) && text.endsWith(_pdi)) return text;
  return '$_fsi$text$_pdi';
}

/// Isolates a trailing Latin brand [token] (optionally followed by `!` or `.`)
/// in right-to-left [sentence], so the punctuation resolves to the RTL run.
/// Left-to-right output is returned unchanged.
String bidiIsolateTrailingToken(
  String sentence,
  String token,
  TextDirection direction,
) {
  if (direction != TextDirection.rtl) return sentence;
  return sentence.replaceFirst(
    RegExp('${RegExp.escape(token)}(?=[!.]?\$)'),
    bidiIsolate(token, direction),
  );
}

extension BidiIsolateContext on BuildContext {
  /// [bidiIsolate] using the ambient [Directionality].
  String isolate(String? text) => bidiIsolate(text, Directionality.of(this));

  /// [bidiIsolateTrailingToken] using the ambient [Directionality].
  String isolateTrailing(String sentence, String token) =>
      bidiIsolateTrailingToken(sentence, token, Directionality.of(this));
}
