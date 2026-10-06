import 'dart:io';

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// Folder a render test writes a geometry dump to
/// (`--dart-define=GEOMETRY_DIR=<dir>`); empty writes nothing.
const String kGeometryDir = String.fromEnvironment('GEOMETRY_DIR');

/// Writes every visible text run and decorated box under the test view —
/// rect, font size/leading/weight, colour, radius, border — so a render can be
/// measured against the design's computed CSS (`listings/diff-table.md`).
void dumpGeometry(WidgetTester tester, String name) {
  if (kGeometryDir.isEmpty) return;
  final StringBuffer out = StringBuffer();
  String r(Rect x) =>
      '[${x.left.toStringAsFixed(1)},${x.top.toStringAsFixed(1)} '
      '${x.width.toStringAsFixed(1)}x${x.height.toStringAsFixed(1)}]';
  void visit(RenderObject o, int depth) {
    if (o is RenderBox && o.hasSize && o.attached) {
      final Rect rect = o.localToGlobal(Offset.zero) & o.size;
      if (rect.top < 1400) {
        if (o is RenderParagraph) {
          final TextStyle? s = o.text.style;
          final String t = o.text.toPlainText().replaceAll('\n', ' ');
          final InlineSpan span = o.text;
          TextStyle? leaf = s;
          span.visitChildren((c) {
            if (c is TextSpan && c.style != null) leaf = s?.merge(c.style) ?? c.style;
            return false;
          });
          out.writeln('${'  ' * depth}text ${r(rect)} "${t.length > 40 ? t.substring(0, 40) : t}" '
              '${leaf?.fontFamily} ${leaf?.fontSize}/${leaf?.height == null ? '-' : ((leaf!.height! * (leaf!.fontSize ?? 0))).toStringAsFixed(1)} '
              'w${leaf?.fontWeight?.value} c=${leaf?.color?.toARGB32().toRadixString(16)}');
        } else if (o is RenderDecoratedBox && o.decoration is BoxDecoration) {
          final BoxDecoration d = o.decoration as BoxDecoration;
          out.writeln('${'  ' * depth}box ${r(rect)} bg=${d.color?.toARGB32().toRadixString(16)} '
              'r=${d.borderRadius} border=${d.border?.top.width}/${d.border?.top.color.toARGB32().toRadixString(16)}');
        } else if (o is RenderPhysicalShape || o is RenderClipRRect) {
          out.writeln('${'  ' * depth}${o.runtimeType} ${r(rect)}');
        }
      }
    }
    o.visitChildren((c) => visit(c, depth + 1));
  }

  visit(tester.binding.renderViews.first, 0);
  Directory(kGeometryDir).createSync(recursive: true);
  File('$kGeometryDir/$name.txt').writeAsStringSync(out.toString());
}
