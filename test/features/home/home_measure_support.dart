/// The measuring rig behind `home_mirror_measure_test.dart`: one [Measure] row
/// per Home element, the design's rect (from the measuring seat's table
/// `home-design-measure.md`) against the rect Flutter lays out, with the delta
/// asserted to be zero or a documented, pinned exception.
library;

import 'dart:io';

import 'package:flutter/painting.dart';

import 'home_measure_exceptions.dart';

/// Where the rows are written as a markdown table. Empty: nothing is written.
const String kMeasureOut = String.fromEnvironment('HOME_MEASURE_OUT');

/// Shorthand for a design rect.
Rect rc(double x, double y, double w, double h) => Rect.fromLTWH(x, y, w, h);

/// How a row is compared.
enum Basis {
  /// Left, top, width and height must each match.
  box,

  /// A DOM text span is its glyphs' content area (a 15/20 span is 16 high);
  /// Flutter's text box is the line box. Compared on the start edge, the
  /// centre line and the advance width.
  text,

  /// A block-level text line in the design (the span's width is its
  /// container's): start edge and centre line only.
  line,

  /// A box whose y the frame fixes only through content the app does not draw
  /// (the saved-place chips): left, width and height must match, y is not
  /// compared.
  inset,
}

/// A documented difference the design and the app are allowed to keep. The
/// delta must equal [dx]/[dy]/[dw]/[dh] (so a drifting exception fails).
class MeasureException {
  const MeasureException(
    this.reason, {
    this.dx = 0,
    this.dy = 0,
    this.dw = 0,
    this.dh = 0,
    this.tol = 0.01,
  });
  final String reason;
  final double dx, dy, dw, dh, tol;
}

class Measure {
  Measure(
    this.name,
    this.design, {
    this.basis = Basis.box,
    this.exception,
    this.token = '',
  });
  final String name;
  final Rect design;
  final Basis basis;
  MeasureException? exception;

  /// The DS token (or "off grid: named token") the value is built from.
  final String token;

  late Rect app;

  /// Set by [MeasureTable.add]: the direction this row was measured in. A text
  /// row is compared on its start edge, which is the right edge in RTL.
  bool rtl = false;

  /// Signed deltas, app minus design: (dx, dy, dw, dh). For [Basis.text] dy is
  /// the centre-line difference and dh is not compared (0).
  (double, double, double, double) get delta =>
      basis == Basis.box || basis == Basis.inset
      ? (
          app.left - design.left,
          basis == Basis.inset ? 0 : app.top - design.top,
          app.width - design.width,
          app.height - design.height,
        )
      : (
          rtl ? app.right - design.right : app.left - design.left,
          app.center.dy - design.center.dy,
          basis == Basis.line ? 0 : app.width - design.width,
          0,
        );
}

/// Text advances differ between Chromium and Flutter shaping by sub-pixels;
/// anything above this is a real width difference.
const double kTextAdvanceTolerance = 0.6;

String _f(double v) {
  final String s = v.toStringAsFixed(2);
  return s.endsWith('.00') ? s.substring(0, s.length - 3) : s;
}

String rectStr(Rect r) =>
    '${_f(r.left)},${_f(r.top)} ${_f(r.width)}x${_f(r.height)}';

String deltaStr((double, double, double, double) d) =>
    '(${_f(d.$1)}, ${_f(d.$2)}, ${_f(d.$3)}, ${_f(d.$4)})';

/// Whether [m]'s delta is zero (within tolerance), or equals its exception.
String? verdict(Measure m) {
  final (double dx, double dy, double dw, double dh) = m.delta;
  final double tolW = m.basis == Basis.box ? 0.05 : kTextAdvanceTolerance;
  final MeasureException? e = m.exception;
  bool near(double a, double b, double tol) => (a - b).abs() <= tol;
  if (e == null) {
    if (near(dx, 0, 0.05) &&
        near(dy, 0, m.basis == Basis.box ? 0.05 : 0.51) &&
        near(dw, 0, tolW) &&
        near(dh, 0, 0.05)) {
      return null;
    }
    return '${m.name}: design ${rectStr(m.design)} app ${rectStr(m.app)} '
        'delta ${deltaStr(m.delta)} (dx, dy, dw, dh) is not zero and has no '
        'documented exception';
  }
  if (near(dx, e.dx, e.tol + 0.05) &&
      near(dy, e.dy, e.tol + (m.basis == Basis.box ? 0.05 : 0.51)) &&
      near(dw, e.dw, e.tol + tolW) &&
      near(dh, e.dh, e.tol + 0.05)) {
    return null;
  }
  return '${m.name}: exception "${e.reason}" pins '
      '(${_f(e.dx)}, ${_f(e.dy)}, ${_f(e.dw)}, ${_f(e.dh)}) but the app is '
      '${deltaStr(m.delta)}';
}

/// Collects rows for one (state, direction) and writes the table.
class MeasureTable {
  MeasureTable({required this.rtl});
  final bool rtl;
  final List<(String, Measure)> rows = <(String, Measure)>[];

  void add(String section, Measure m) {
    m.rtl = rtl;
    final MeasureException? known =
        kMeasureExceptions['${rtl ? 'RTL' : 'LTR'}|$section|${m.name}'];
    if (known != null && m.exception == null) m.exception = known;
    rows.add((section, m));
  }

  List<String> failures() => <String>[
    for (final (String s, Measure m) in rows)
      if (verdict(m) case final String v) '[${rtl ? 'RTL' : 'LTR'}][$s] $v',
  ];

  /// Appends this table as markdown to [kMeasureOut].
  void write(String heading) {
    if (kMeasureOut.isEmpty) return;
    final StringBuffer b = StringBuffer('\n### $heading\n\n')
      ..writeln(
        '| element | design px | app px | delta (dx, dy, dw, dh) | token / exception |',
      )
      ..writeln('|---|---|---|---|---|');
    String? section;
    for (final (String s, Measure m) in rows) {
      if (s != section) {
        b.writeln('| **$s** | | | | |');
        section = s;
      }
      final MeasureException? e = m.exception;
      final String note = e != null
          ? 'EXCEPTION: ${e.reason}'
          : (m.token.isEmpty ? '0' : m.token);
      final String basis = m.basis == Basis.text
          ? ' (text: start edge/centre line/advance)'
          : m.basis == Basis.line
          ? ' (text line: start edge/centre line)'
          : '';
      b.writeln(
        '| ${m.name}$basis | ${rectStr(m.design)} | ${rectStr(m.app)} | '
        '${deltaStr(m.delta)} | $note |',
      );
    }
    File(kMeasureOut).writeAsStringSync(b.toString(), mode: FileMode.append);
  }
}
