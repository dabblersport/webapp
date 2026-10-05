/// The sheet-convention gate (KAN-434).
///
/// One look for every bottom sheet: the app opens a sheet only through
/// `showDabblerSheet` (or the `showComposerSheet` helper over it), content-sized
/// (`detent: DabblerSheetDetent.content`, never `detents:`), and the content
/// passes widgets only — the design system's `DabblerSheet` owns the surface,
/// the handle, the title row and the body padding (`components/sheet.md`, "The
/// one sheet convention").
///
/// This test scans `lib/` for every sheet call and the options each passes. A
/// call outside the convention fails the test unless it has a line in
/// [_allowList] with a one-line reason. Conversion seats REMOVE their lines as
/// they convert; a line whose call now conforms (or no longer exists) also
/// fails, so the list can only shrink and never goes stale.
///
/// A call is keyed `<path>#<n>`: `n` is its 1-based position among ALL sheet
/// calls in that file (conforming ones count), so converting one call does not
/// renumber the others.
///
/// The convention rules the scanner enforces, per primitive:
///  * `showDabblerSheet` / `DabblerSheetRoute`: must pass
///    `detent: DabblerSheetDetent.content`; must not pass `detents` or
///    `snapTo`; may pass only the options in [_sheetOptions].
///  * `showComposerSheet`: may pass only `title`, `builder`, `subtitle`,
///    `onClear`, `confirm`; `tall` is outside the convention.
///  * `showModalBottomSheet` / `showBottomSheet` / a raw `DabblerSheet(`:
///    always outside the convention.
///
/// Content check (a heuristic, source-level): the ROOT widget the `builder:`
/// returns, followed through any widget class defined in `lib/` (its `build`'s
/// first `return` / `=>`, through a `State` class too, up to [_maxDepth]
/// hops), must not be a panel or a padder: `Padding`, `Container` with
/// padding / margin / colour / decoration, `Card`, `Material`, `Ink`,
/// `DecoratedBox`, `DabblerCard`, `Scaffold`, or a `ListView` / `GridView` /
/// `SingleChildScrollView` with `padding:`. The sheet owns the surface and the
/// inset (`components/sheet.md`). It cannot see padding deeper than the root,
/// nor a root it cannot resolve (a tear-off, a builder passed through); the
/// design-system tests assert the single surface and single inset, and the
/// call-site inventory records the rest by hand.
///
/// Header band: a sheet with no `title` / `titleWidget` / `titleSpan` and no
/// `headerActionBuilder` but the default close button draws an EMPTY band (the
/// X alone under the handle). If the resolved content's first `DabblerText`
/// uses a title-like style (`largeTitle`, `title1..3`, `headline`, `display*`)
/// the title sits under that band: pass it as `title:` (or `titleWidget:`) so
/// it lives in the header. A false positive is allow-listed with a reason like
/// any other line.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Calls outside the convention that are not yet converted. One per line:
/// `<path>#<n> | <reason>`. Remove the line when the call is converted.
const String _allowList = '''
lib/core/widgets/composer_drawer_kit.dart#1 | tall composer keeps its fixed 0.82 fraction: Home Feed.dc.html:650 draws the vibes sheet at hint-size 100%,82%; every other composer sheet is content-sized
lib/features/home/presentation/screens/home_screen.dart#3 | city sheet keeps its fixed 0.66 fraction: Home Feed frame city sheet is 0.66 of the viewport (KAN-433 measure, panel 393x562.31 matches); content padding is HomeLocationPickerSheet's (location seat)
lib/features/social/presentation/widgets/composer_vibes_sheet.dart#1 | `tall: true` keeps the 0.82 fraction: Home Feed.dc.html:650 vibes sheet is drawn at 100%,82%
''';

/// Options a `showDabblerSheet` call may pass (everything the DS route takes
/// except `detents`, which is the fixed-fraction escape the convention drops).
const Set<String> _sheetOptions = <String>{
  'context',
  'builder',
  'title',
  'titleSpan',
  'titleWidget',
  'headerActionBuilder',
  'footerBuilder',
  'dismissible',
  'closeLabel',
  'scrimLabel',
  'detent',
  'contentMaxFraction',
  'pageBackground',
  'hairlineOutside',
  'showCloseButton',
  'headerDivider',
  'dragHandle',
  'settings',
};

const Set<String> _composerOptions = <String>{
  'title',
  'builder',
  'subtitle',
  'onClear',
  'confirm',
};

/// One sheet call found in a source file.
class SheetCall {
  SheetCall({
    required this.path,
    required this.ordinal,
    required this.line,
    required this.helper,
    required this.options,
    required this.violations,
    this.contentRoot,
  });

  final String path;
  final int ordinal;
  final int line;
  final String helper;

  /// Named option -> its value source text.
  final Map<String, String> options;
  final List<String> violations;

  /// The widget the builder's content starts with, when it could be resolved
  /// (`Padding`, `Column` ...), with the classes followed to reach it.
  final String? contentRoot;

  String get key => '$path#$ordinal';
  bool get conforms => violations.isEmpty;
}

// ---------------------------------------------------------------------------
// Scanner
// ---------------------------------------------------------------------------

/// [source] with comments blanked to spaces (newlines kept, so offsets and
/// line numbers are unchanged). String literals, including `${…}` nesting, are
/// left alone so a `//` inside a URL is not taken for a comment.
String stripComments(String source, {bool maskStrings = false}) {
  final StringBuffer out = StringBuffer();
  final List<_Mode> stack = <_Mode>[];
  int i = 0;
  final int n = source.length;
  bool startsWith(String t) => source.startsWith(t, i);

  while (i < n) {
    final _Mode? top = stack.isEmpty ? null : stack.last;
    if (top == null || top is _Interp) {
      if (startsWith('//')) {
        while (i < n && source[i] != '\n') {
          out.write(' ');
          i++;
        }
        continue;
      }
      if (startsWith('/*')) {
        while (i < n && !startsWith('*/')) {
          out.write(source[i] == '\n' ? '\n' : ' ');
          i++;
        }
        if (i < n) {
          out.write('  ');
          i += 2;
        }
        continue;
      }
      final String c = source[i];
      if (c == "'" || c == '"') {
        final bool raw =
            i > 0 &&
            source[i - 1] == 'r' &&
            (i < 2 || !RegExp(r'[A-Za-z0-9_$]').hasMatch(source[i - 2]));
        final bool triple = startsWith(c * 3);
        stack.add(_Str(c, triple, raw));
        out.write(triple ? c * 3 : c);
        i += triple ? 3 : 1;
        continue;
      }
      if (top is _Interp) {
        if (c == '{') {
          top.depth++;
        } else if (c == '}') {
          if (top.depth == 0) {
            stack.removeLast();
          } else {
            top.depth--;
          }
        }
      }
      out.write(c);
      i++;
      continue;
    }
    final _Str str = top as _Str;
    final String c = source[i];
    if (!str.raw && c == r'\' && i + 1 < n) {
      out.write(source.substring(i, i + 2));
      i += 2;
      continue;
    }
    if (!str.raw && c == r'$' && i + 1 < n && source[i + 1] == '{') {
      stack.add(_Interp());
      out.write(r'${');
      i += 2;
      continue;
    }
    final String close = str.triple ? str.quote * 3 : str.quote;
    if (startsWith(close)) {
      stack.removeLast();
      out.write(close);
      i += close.length;
      continue;
    }
    out.write(maskStrings && c != '\n' ? ' ' : c);
    i++;
  }
  return out.toString();
}

abstract class _Mode {}

class _Str extends _Mode {
  _Str(this.quote, this.triple, this.raw);
  final String quote;
  final bool triple;
  final bool raw;
}

class _Interp extends _Mode {
  int depth = 0;
}

/// Index just past the string literal that starts at [start].
int _skipString(String s, int start) {
  final String q = s[start];
  final bool triple = s.startsWith(q * 3, start);
  final bool raw = start > 0 && s[start - 1] == 'r';
  int i = start + (triple ? 3 : 1);
  while (i < s.length) {
    if (!raw && s[i] == r'\') {
      i += 2;
      continue;
    }
    if (!raw && s[i] == r'$' && i + 1 < s.length && s[i + 1] == '{') {
      i = _skipBalanced(s, i + 1, '{', '}') + 1;
      continue;
    }
    if (s.startsWith(triple ? q * 3 : q, i)) return i + (triple ? 3 : 1);
    i++;
  }
  return s.length;
}

/// Index of the bracket that closes the one at [open].
int _skipBalanced(String s, int open, String o, String c) {
  int depth = 0;
  int i = open;
  while (i < s.length) {
    final String ch = s[i];
    if (ch == "'" || ch == '"') {
      i = _skipString(s, i);
      continue;
    }
    if (ch == o) depth++;
    if (ch == c) {
      depth--;
      if (depth == 0) return i;
    }
    i++;
  }
  return s.length - 1;
}

/// Named arguments of the call whose `(` is at [open]: name -> value text.
Map<String, String> parseNamedArgs(String s, int open) {
  final int close = _skipBalanced(s, open, '(', ')');
  final String args = s.substring(open + 1, close);
  final List<String> pieces = <String>[];
  int depth = 0;
  int start = 0;
  int i = 0;
  while (i < args.length) {
    final String ch = args[i];
    if (ch == "'" || ch == '"') {
      i = _skipString(args, i);
      continue;
    }
    if ('([{'.contains(ch)) depth++;
    if (')]}'.contains(ch)) depth--;
    if (ch == ',' && depth == 0) {
      pieces.add(args.substring(start, i));
      start = i + 1;
    }
    i++;
  }
  pieces.add(args.substring(start));
  final Map<String, String> named = <String, String>{};
  for (final String p in pieces) {
    final RegExpMatch? m = RegExp(
      r'^\s*(\w+)\s*:\s*([\s\S]*?)\s*$',
    ).firstMatch(p);
    if (m != null) named[m.group(1)!] = m.group(2)!;
  }
  return named;
}

final RegExp _callPattern = RegExp(
  r'\b(showDabblerSheet|showModalBottomSheet|showBottomSheet|showComposerSheet|DabblerSheetRoute|DabblerSheet)\b\s*(?:<[^()]*?>)?\s*\(',
);

const Set<String> _callKeywords = <String>{
  'await',
  'return',
  'else',
  'in',
  'yield',
  'case',
};

/// True when the match at [start] is a declaration (`Future<T?> name<T>(`),
/// not a call.
bool _isDeclaration(String s, int start) {
  int i = start - 1;
  while (i >= 0 && ' \t\r\n'.contains(s[i])) {
    i--;
  }
  if (i < 0) return false;
  if (s[i] == '.') return false;
  if (i >= 1 && s.substring(i - 1, i + 1) == '=>') return false;
  if (s[i] == '>') return true; // `Future<T?> name(`
  if (RegExp(r'[A-Za-z0-9_$?]').hasMatch(s[i])) {
    int j = i;
    while (j >= 0 && RegExp(r'[A-Za-z0-9_$?]').hasMatch(s[j])) {
      j--;
    }
    final String word = s.substring(j + 1, i + 1);
    return !_callKeywords.contains(word); // `void name(`
  }
  return false;
}

/// Violations of the convention for one call.
List<String> judge(String helper, Map<String, String> options) {
  final List<String> v = <String>[];
  switch (helper) {
    case 'showDabblerSheet' || 'DabblerSheetRoute':
      if (options.containsKey('detents')) {
        v.add('passes `detents:` (fixed fractions)');
      }
      if (options.containsKey('snapTo')) v.add('passes `snapTo:`');
      final String? detent = options['detent'];
      if (detent == null) {
        v.add('no `detent: DabblerSheetDetent.content` (defaults to 0.5)');
      } else if (detent != 'DabblerSheetDetent.content') {
        v.add('`detent: $detent` is not DabblerSheetDetent.content');
      }
      for (final String o in options.keys) {
        if (!_sheetOptions.contains(o) && o != 'detents' && o != 'snapTo') {
          v.add('unknown option `$o:`');
        }
      }
    case 'showComposerSheet':
      for (final String o in options.keys) {
        if (!_composerOptions.contains(o)) v.add('passes `$o:`');
      }
    case 'showModalBottomSheet' || 'showBottomSheet':
      v.add('Material bottom sheet, not DabblerSheet');
    case 'DabblerSheet':
      v.add('raw DabblerSheet outside showDabblerSheet');
  }
  return v;
}

/// Every sheet call in [source] (a file at [path]).
List<SheetCall> scanSource(
  String path,
  String source, [
  Map<String, String> classes = const <String, String>{},
]) {
  final String code = stripComments(source);
  // Same offsets with string contents blanked: names are matched there, so a
  // helper's name inside a string literal is not taken for a call.
  final String masked = stripComments(source, maskStrings: true);
  final List<SheetCall> calls = <SheetCall>[];
  int ordinal = 0;
  for (final RegExpMatch m in _callPattern.allMatches(masked)) {
    if (_isDeclaration(masked, m.start)) continue;
    ordinal++;
    final String helper = m.group(1)!;
    final int open = m.end - 1;
    final Map<String, String> options = parseNamedArgs(code, open);
    final List<String> violations = judge(helper, options);
    String? contentRoot;
    if (helper != 'DabblerSheet') {
      final String? builder = options['builder'];
      if (builder != null) {
        final ({String? chain, String? offender, String text}) r =
            resolveContent(builder, classes);
        contentRoot = r.chain;
        if (r.offender != null) {
          violations.add('content root is ${r.offender} (${r.chain})');
        }
        if (hasEmptyHeaderBand(options) && startsWithTitle(r.text)) {
          violations.add(
            'title drawn in the content under an empty header band: pass '
            '`title:` (or `titleWidget:`) so it lives in the sheet header',
          );
        }
      }
    }
    calls.add(
      SheetCall(
        path: path,
        ordinal: ordinal,
        line: '\n'.allMatches(code.substring(0, m.start)).length + 1,
        helper: helper,
        options: options,
        violations: violations,
        contentRoot: contentRoot,
      ),
    );
  }
  return calls;
}

// ---------------------------------------------------------------------------
// Content root
// ---------------------------------------------------------------------------

const int _maxDepth = 4;

final RegExp _classDecl = RegExp(
  r'^(?:abstract\s+|final\s+|base\s+)*class\s+(\w+)(?:<[^{]*?>)?\s+extends\s+(\w+)(?:<(\w+)>)?',
  multiLine: true,
);

/// Widget class name -> its source text; a `State<W>` class is filed under
/// `$state:W` so a stateful widget's `build` can be found.
Map<String, String> classIndex(List<String> sources) {
  final Map<String, String> out = <String, String>{};
  for (final String src in sources) {
    final List<RegExpMatch> ms = _classDecl.allMatches(src).toList();
    for (int i = 0; i < ms.length; i++) {
      final String body = src.substring(
        ms[i].start,
        i + 1 < ms.length ? ms[i + 1].start : src.length,
      );
      final String name = ms[i].group(1)!;
      final String parent = ms[i].group(2)!;
      final String? arg = ms[i].group(3);
      if (parent == 'State' || parent.endsWith('State')) {
        if (arg != null) out[r'$state:' + arg] = body;
      } else {
        out[name] = body;
      }
    }
  }
  return out;
}

const Set<String> _panelRoots = <String>{
  'Padding',
  'Card',
  'Material',
  'Ink',
  'DecoratedBox',
  'DabblerCard',
  'Scaffold',
};

const Set<String> _scrollRoots = <String>{
  'ListView',
  'GridView',
  'SingleChildScrollView',
  'CustomScrollView',
};

const Set<String> _containerPaint = <String>{
  'padding',
  'margin',
  'color',
  'decoration',
};

/// The first widget a builder expression returns, as `(name, args)`.
({String name, String args})? _rootOf(String text) {
  final String code = text.trim();
  int from = 0;
  final RegExpMatch? arrow = RegExp(r'=>').firstMatch(code);
  final RegExpMatch? ret = RegExp(r'\breturn\b').firstMatch(code);
  final bool block =
      code.contains('{') && (arrow == null || code.indexOf('{') < arrow.start);
  if (block) {
    if (ret == null) return null;
    from = ret.end;
  } else if (arrow != null) {
    from = arrow.end;
  } else if (!RegExp(r'^(?:const\s+)?_?[A-Z]').hasMatch(code)) {
    return null; // a tear-off such as `builder: builder`
  }
  final Match? m = RegExp(
    r'\s*(?:const\s+|new\s+)?(_?[A-Z]\w*)(?:\.\w+)?\s*(?:<[^()]*?>)?\s*\(',
  ).matchAsPrefix(code, from);
  if (m == null) return null;
  final int open = m.end - 1;
  final int close = _skipBalanced(code, open, '(', ')');
  return (name: m.group(1)!, args: code.substring(open + 1, close));
}

/// The sheet draws a header row when it has a title, a header action, or a
/// close button (the default). With none of the three the row is absent; with
/// only the close button it is an EMPTY band (handle, then an X on its own).
bool hasEmptyHeaderBand(Map<String, String> options) {
  final bool hasTitle =
      options.containsKey('title') ||
      options.containsKey('titleWidget') ||
      options.containsKey('titleSpan');
  final bool hasAction = options.containsKey('headerActionBuilder');
  final bool close = options['showCloseButton'] != 'false';
  return !hasTitle && !hasAction && close;
}

final RegExp _titleStyle = RegExp(
  r'DabblerType\.(?:largeTitle|title[123]?|headline|display\w*)\b',
);

/// Heuristic: the first `DabblerText(` in the builder's resolved source uses a
/// title-like style (`largeTitle`, `title1..3`, `headline`, `display*`). A
/// heading that is not the first text, or drawn by another widget, is not
/// seen.
bool startsWithTitle(String source) {
  final int at = source.indexOf('DabblerText(');
  if (at < 0) return false;
  final int open = source.indexOf('(', at);
  final int close = _skipBalanced(source, open, '(', ')');
  final String args = source.substring(open, close);
  return _titleStyle.hasMatch(args);
}

/// Follows the builder's root through lib-defined widgets; `chain` is the
/// path (`_Host > Padding`), `offender` the panel/padder root, if any.
({String? chain, String? offender, String text}) resolveContent(
  String builder,
  Map<String, String> classes,
) {
  String? chain;
  String text = builder;
  for (int depth = 0; depth < _maxDepth; depth++) {
    final ({String name, String args})? root = _rootOf(text);
    if (root == null) return (chain: chain, offender: null, text: text);
    chain = chain == null ? root.name : '$chain > ${root.name}';
    final String n = root.name;
    final Map<String, String> named = parseNamedArgs('(${root.args})', 0);
    if (_panelRoots.contains(n) ||
        (n == 'Container' && named.keys.any(_containerPaint.contains)) ||
        (_scrollRoots.contains(n) && named.containsKey('padding'))) {
      return (chain: chain, offender: n, text: text);
    }
    final String? body = classes[n];
    if (body == null) return (chain: chain, offender: null, text: text);
    final String buildSrc = classes[r'$state:' + n] ?? body;
    final int at = buildSrc.indexOf(RegExp(r'Widget\s+build\s*\('));
    if (at < 0) return (chain: chain, offender: null, text: text);
    text = buildSrc.substring(at);
  }
  return (chain: chain, offender: null, text: text);
}

List<SheetCall> scanLib(Directory lib) {
  final List<SheetCall> all = <SheetCall>[];
  final List<File> files =
      lib
          .listSync(recursive: true)
          .whereType<File>()
          .where((File f) => f.path.endsWith('.dart'))
          .toList()
        ..sort((File a, File b) => a.path.compareTo(b.path));
  final Map<String, String> classes = classIndex(<String>[
    for (final File f in files) stripComments(f.readAsStringSync()),
  ]);
  for (final File f in files) {
    all.addAll(scanSource(f.path, f.readAsStringSync(), classes));
  }
  return all;
}

/// Allow-list entries by key. A line without ` | <reason>` is itself an error.
Map<String, String> parseAllowList(String text, List<String> problems) {
  final Map<String, String> out = <String, String>{};
  for (final String raw in text.split('\n')) {
    final String line = raw.trim();
    if (line.isEmpty || line.startsWith('#')) continue;
    final int bar = line.indexOf(' | ');
    final String reason = bar < 0 ? '' : line.substring(bar + 3).trim();
    final String key = bar < 0 ? line : line.substring(0, bar).trim();
    if (reason.isEmpty) {
      problems.add('allow-list line has no reason: "$line"');
      continue;
    }
    out[key] = reason;
  }
  return out;
}

/// Problems: unlisted violations, and allow-list lines that are stale.
List<String> evaluate(List<SheetCall> calls, String allowList) {
  final List<String> problems = <String>[];
  final Map<String, String> allowed = parseAllowList(allowList, problems);
  final Map<String, SheetCall> byKey = <String, SheetCall>{
    for (final SheetCall c in calls) c.key: c,
  };
  for (final SheetCall c in calls) {
    if (!c.conforms && !allowed.containsKey(c.key)) {
      problems.add(
        '${c.path}:${c.line} ${c.helper} outside the convention: '
        '${c.violations.join('; ')}. Convert it, or add the line '
        '"${c.key} | <reason>" to the allow-list.',
      );
    }
  }
  for (final String key in allowed.keys) {
    final SheetCall? c = byKey[key];
    if (c == null) {
      problems.add('stale allow-list line "$key": no such sheet call.');
    } else if (c.conforms) {
      problems.add(
        'stale allow-list line "$key": ${c.path}:${c.line} now conforms; '
        'remove the line.',
      );
    }
  }
  return problems;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  test('every sheet call in lib/ is in the convention or allow-listed', () {
    final List<SheetCall> calls = scanLib(Directory('lib'));
    expect(calls, isNotEmpty, reason: 'the scanner found no sheet calls');
    if (const bool.fromEnvironment('SHEETS_INVENTORY')) {
      for (final SheetCall c in calls) {
        // ignore: avoid_print
        print(
          'INV|${c.path}|${c.line}|${c.ordinal}|${c.helper}|'
          '${c.options.keys.join(',')}|${c.contentRoot}|'
          '${c.violations.join('; ')}',
        );
      }
    }
    final List<String> problems = evaluate(calls, _allowList);
    expect(problems, isEmpty, reason: problems.join('\n'));
  });

  group('scanner self-test', () {
    List<SheetCall> scan(String src) => scanSource('lib/x.dart', src);

    test('a content-sized call with a title conforms', () {
      final List<SheetCall> c = scan('''
void f(BuildContext context) {
  showDabblerSheet<void>(
    context: context,
    title: 'Sort',
    detent: DabblerSheetDetent.content,
    builder: (context) => const Text('x'),
  );
}''');
      expect(c, hasLength(1));
      expect(c.single.conforms, isTrue, reason: '${c.single.violations}');
      expect(c.single.options['title'], "'Sort'");
    });

    test('detents: is outside the convention', () {
      final SheetCall c = scan('''
void f() => showDabblerSheet<bool>(
  context: context,
  detents: const <double>[0.6],
  builder: (context) => x,
);''').single;
      expect(c.conforms, isFalse);
      expect(c.violations, contains('passes `detents:` (fixed fractions)'));
    });

    test('a missing detent is outside the convention', () {
      final SheetCall c = scan(
        'Future<void> f() => showDabblerSheet<void>(context: c, builder: b);',
      ).single;
      expect(c.violations.single, contains('no `detent:'));
    });

    test('a conditional detent is outside the convention', () {
      final SheetCall c = scan('''
x() => showDabblerSheet<T>(
  context: context,
  detent: tall ? DabblerSheetDetent.fractions : DabblerSheetDetent.content,
  builder: b,
);''').single;
      expect(
        c.violations.single,
        contains('is not DabblerSheetDetent.content'),
      );
    });

    test('an unknown option is outside the convention', () {
      final SheetCall c = scan('''
x() { showDabblerSheet<void>(
  context: context, detent: DabblerSheetDetent.content,
  backgroundColor: Colors.red, builder: b); }''').single;
      expect(c.violations, contains('unknown option `backgroundColor:`'));
    });

    test('showModalBottomSheet and a raw DabblerSheet always fail', () {
      expect(
        scan(
          'x() { showModalBottomSheet<void>(context: c, builder: b); }',
        ).single.conforms,
        isFalse,
      );
      expect(scan('x() => DabblerSheet(child: y);').single.conforms, isFalse);
    });

    test('showComposerSheet: tall is outside, the rest is fine', () {
      final List<SheetCall> c = scan('''
a() { showComposerSheet<void>(context, title: 't', builder: b, confirm: k); }
b() { showComposerSheet<void>(context, title: 't', builder: b, tall: true); }
''');
      expect(c[0].conforms, isTrue);
      expect(c[1].violations, contains('passes `tall:`'));
    });

    test('declarations are not calls; `=>` and `await` calls are', () {
      final List<SheetCall> c = scan('''
Future<T?> showComposerSheet<T>(BuildContext context, {required String title}) =>
    showDabblerSheet<T>(context: context, builder: b);
Future<void> g() async { await showModalBottomSheet<void>(context: c, builder: b); }
''');
      expect(c.map((SheetCall e) => e.helper), <String>[
        'showDabblerSheet',
        'showModalBottomSheet',
      ]);
    });

    test('comments and strings do not hide or invent calls', () {
      final List<SheetCall> c = scan('''
// showModalBottomSheet(context: c);
/* showModalBottomSheet(context: c); */
/// Opens via [showDabblerSheet].
void f() {
  final u = 'https://example.com//x';
  showDabblerSheet<void>(
    context: context,
    title: 'a, b: \${x['k']}',
    detent: DabblerSheetDetent.content,
    builder: (c) => Text("showModalBottomSheet("),
  );
}''');
      expect(c, hasLength(1));
      expect(c.single.helper, 'showDabblerSheet');
      expect(c.single.conforms, isTrue, reason: '${c.single.violations}');
    });

    test('a Padding / panel root in the builder is outside the convention', () {
      final SheetCall c = scan('''
x() { showDabblerSheet<void>(
  context: c, detent: DabblerSheetDetent.content,
  builder: (ctx) => Padding(padding: p, child: Column()),
); }''').single;
      expect(c.violations.single, contains('content root is Padding'));
      final SheetCall ok = scan('''
x() { showDabblerSheet<void>(
  context: c, detent: DabblerSheetDetent.content,
  builder: (ctx) { return const DabblerSheetBody(children: []); },
); }''').single;
      expect(ok.conforms, isTrue, reason: '${ok.violations}');
      final SheetCall box = scan('''
x() { showDabblerSheet<void>(
  context: c, detent: DabblerSheetDetent.content,
  builder: (ctx) => Container(padding: p, child: y),
); }''').single;
      expect(box.violations.single, contains('Container'));
      final SheetCall list = scan('''
x() { showDabblerSheet<void>(
  context: c, detent: DabblerSheetDetent.content,
  builder: (ctx) => ListView(padding: DabblerInsets.screen, children: []),
); }''').single;
      expect(list.violations.single, contains('ListView'));
    });

    test('a title in the content under an empty header band is outside', () {
      final Map<String, String> classes = classIndex(<String>[
        '''
class Drawer extends StatelessWidget {
  Widget build(BuildContext context) => Column(children: [
    DabblerIconTile.named('x'),
    DabblerText('Stay', style: DabblerType.title2),
  ]);
}
class Plain extends StatelessWidget {
  Widget build(BuildContext context) => Column(children: [
    DabblerText('Body', style: DabblerType.body),
  ]);
}''',
      ]);
      String call(String name, String extra) =>
          'x() { showDabblerSheet<void>(context: c, '
          'detent: DabblerSheetDetent.content, $extra builder: (_) => $name()); }';
      final SheetCall bad = scanSource(
        'lib/x.dart',
        call('Drawer', ''),
        classes,
      ).single;
      expect(bad.violations.single, contains('empty header band'));
      for (final String ok in <String>[
        call('Drawer', "title: 'Stay',"),
        call('Drawer', 'showCloseButton: false,'),
        call('Plain', ''),
      ]) {
        final SheetCall c = scanSource('lib/x.dart', ok, classes).single;
        expect(c.conforms, isTrue, reason: '$ok ${c.violations}');
      }
    });

    test('a title in the content under an empty header band is outside', () {
      final Map<String, String> classes = classIndex(<String>[
        '''
class Drawer extends StatelessWidget {
  Widget build(BuildContext context) => Column(children: [
    DabblerIconTile.named('x'),
    DabblerText('Stay', style: DabblerType.title2),
  ]);
}
class Plain extends StatelessWidget {
  Widget build(BuildContext context) => Column(children: [
    DabblerText('Body', style: DabblerType.body),
  ]);
}''',
      ]);
      String call(String name, String extra) =>
          'x() { showDabblerSheet<void>(context: c, '
          'detent: DabblerSheetDetent.content, $extra builder: (_) => $name()); }';
      final SheetCall bad = scanSource(
        'lib/x.dart',
        call('Drawer', ''),
        classes,
      ).single;
      expect(bad.violations.single, contains('empty header band'));
      for (final String ok in <String>[
        call('Drawer', "title: 'Stay',"),
        call('Drawer', 'showCloseButton: false,'),
        call('Plain', ''),
      ]) {
        final SheetCall c = scanSource('lib/x.dart', ok, classes).single;
        expect(c.conforms, isTrue, reason: '$ok ${c.violations}');
      }
    });

    test('the content root is followed through widget classes', () {
      final Map<String, String> classes = classIndex(<String>[
        '''
class Outer extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Inner();
}
class Inner extends StatefulWidget {
  State<Inner> createState() => _InnerState();
}
class _InnerState extends State<Inner> {
  @override
  Widget build(BuildContext context) {
    return Padding(padding: p, child: x);
  }
}
class Clean extends StatelessWidget {
  @override
  Widget build(BuildContext context) { return DabblerSheetBody(children: []); }
}''',
      ]);
      const String call = '''
x() { showDabblerSheet<void>(
  context: c, detent: DabblerSheetDetent.content, builder: (_) => Outer()); }''';
      final SheetCall bad = scanSource('lib/x.dart', call, classes).single;
      expect(bad.contentRoot, 'Outer > Inner > Padding');
      expect(bad.conforms, isFalse);
      final SheetCall good = scanSource(
        'lib/x.dart',
        call.replaceAll('Outer()', 'Clean()'),
        classes,
      ).single;
      expect(good.conforms, isTrue, reason: '${good.violations}');
    });

    test('ordinals count conforming calls, so keys stay stable', () {
      final List<SheetCall> c = scan('''
a() { showDabblerSheet<void>(context: c, detent: DabblerSheetDetent.content, builder: b); }
b() { showDabblerSheet<void>(context: c, detents: const [0.5], builder: b); }
''');
      expect(c.map((SheetCall e) => e.key), <String>[
        'lib/x.dart#1',
        'lib/x.dart#2',
      ]);
      expect(c[0].conforms, isTrue);
      expect(c[1].conforms, isFalse);
    });

    test('the allow-list admits listed calls and rejects stale lines', () {
      final List<SheetCall> c = scan('''
a() { showDabblerSheet<void>(context: c, detent: DabblerSheetDetent.content, builder: b); }
b() { showDabblerSheet<void>(context: c, detents: const [0.5], builder: b); }
''');
      expect(evaluate(c, ''), hasLength(1), reason: 'b is unlisted');
      expect(evaluate(c, 'lib/x.dart#2 | pending conversion KAN-434'), isEmpty);
      // Listed but now conforming, and listed but gone.
      expect(
        evaluate(c, 'lib/x.dart#1 | r\nlib/x.dart#2 | r\nlib/x.dart#9 | r'),
        hasLength(2),
      );
      // A line with no reason is an error, and the call stays unlisted.
      expect(evaluate(c, 'lib/x.dart#2'), hasLength(2));
    });
  });
}
