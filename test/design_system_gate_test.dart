// Permanent design-system gate: the app inherits every visual value from
// `dabbler_design_system`. This test scans `lib/**/*.dart` and fails on any
// hard-coded visual literal or raw Material/Flutter visual primitive, listing
// `file:line: kind: source line` for each hit.
//
// Policy decisions (documented here so the gate cannot drift silently):
// - Comments and string-literal contents are stripped before matching;
//   matching runs over the whole file, so a call split across lines is
//   matched as one call.
// - Numeric named arguments are checked over the whole argument value up to
//   the next top-level comma, so `opacity: on ? 1 : 0` is a hit, not only
//   `opacity: 1`. Arguments nested inside another constructor call (an
//   identifier starting with an upper-case letter) are left to that call's
//   own rule; arguments inside lower-case calls (`math.max(8, x)`) count.
// - Zero is NOT exempt. `top: 0` positions a widget and is visual; use
//   `Positioned.fill`, `EdgeInsets.zero`, `Duration.zero` and friends. No
//   listed name (`size`, `height`, ... ) is used for a non-visual value in
//   lib/ today, so there is no non-visual exemption; `flex` is not a listed
//   name and is never matched.
// - `Duration(minutes|hours|days: N)` is its own kind, "Domain duration
//   literal": no animation or interaction timing is measured in minutes, so
//   these are business data (retention, game length, cooldowns) and are
//   allow-listed per file. Sub-minute units stay "Duration literal" and are
//   allowed only in lib/core/constants/timing/.
// - Anything that genuinely cannot come from the design system goes on the
//   explicit [allowList] below, one narrow entry per file and kind, with a
//   one-line reason. An entry that suppresses nothing fails the test.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// One gate hit.
class GateHit {
  GateHit(this.path, this.line, this.kind, this.source);
  final String path;
  final int line;
  final String kind;
  final String source;
  @override
  String toString() => '$path:$line: $kind: ${source.trim()}';
}

/// An explicit, reasoned exception. [path] is a file, or a directory when it
/// ends with `/`. When [match] is set, the hit's source line must also
/// contain it, so the entry covers one expression rather than the whole file.
class GateAllow {
  const GateAllow(this.path, this.kinds, this.reason, {this.match});
  final String path;
  final List<String> kinds;
  final String reason;
  final String? match;
  bool covers(GateHit h) =>
      kinds.contains(h.kind) &&
      (path.endsWith('/') ? h.path.startsWith(path) : h.path == path) &&
      (match == null || h.source.contains(match!));
}

const _maxWidthReason =
    'Layout max/min-size constraint: the design system has no content '
    'max-width or constraint role yet (filed as a DS gap).';
const _aspectReason =
    'Media aspect ratio: the design system has no media aspect-ratio role '
    'yet (filed as a DS gap).';
const _alphaReason =
    'Tint alpha over a DS colour: the design system has no tint/overlay alpha '
    'role yet (filed as a DS gap).';
const _radiusNoneReason =
    'Full-bleed square edge: the DS radius ramp has no none step '
    '(filed as a DS gap).';
const _pickerReason =
    'Image-picker downscale bound in pixels for upload size; not rendered.';
const _domainDurationReason =
    'Business-data durations (dates, retention, cache TTLs, game lengths); '
    'not design timing.';

const List<GateAllow> allowList = [
  GateAllow(
    'lib/core/constants/timing/',
    ['Duration literal', 'Domain duration literal'],
    'Named domain and mock timing constants; the one directory where a '
        'Duration literal may live.',
  ),
  GateAllow(
    'lib/utils/transitions/page_transitions.dart',
    ['Material visual widget'],
    'Transparent Material ancestor required by route plumbing for ink and '
        'text descendants; it paints nothing.',
    match: 'Material(',
  ),
  GateAllow(
    'lib/utils/transitions/page_transitions.dart',
    ['numeric named arg'],
    'Zero lower clamp bound that keeps the sheet max-height non-negative; '
        'arithmetic safety, not a design value.',
    match: 'mobileHeightFactor).clamp(',
  ),
  GateAllow(
    'lib/features/social/presentation/widgets/post_media_carousel.dart',
    ['Material visual widget'],
    'Opacity computed from the live drag gesture as interaction feedback; '
        'no fixed visual value.',
    match: 'Opacity(',
  ),
  GateAllow(
    'lib/features/social/presentation/widgets/post_media_carousel.dart',
    ['numeric named arg'],
    'Drag-dismiss fade factor and clamp bounds of the gesture-driven opacity.',
    match: 'progress * 2.5',
  ),
  GateAllow(
    'lib/features/auth_onboarding/presentation/screens/email_password_screen.dart',
    ['numeric named arg'],
    _maxWidthReason,
    match: 'maxWidth: 480',
  ),
  GateAllow(
    'lib/features/auth_onboarding/presentation/screens/auth_welcome_screen.dart',
    ['numeric named arg'],
    _maxWidthReason,
    match: 'maxWidth: 480',
  ),
  GateAllow(
    'lib/features/auth_onboarding/presentation/screens/welcome_screen.dart',
    ['numeric named arg'],
    _maxWidthReason,
    match: 'maxWidth: 480',
  ),
  GateAllow(
    'lib/features/auth_onboarding/presentation/screens/email_input_screen.dart',
    ['numeric named arg'],
    _maxWidthReason,
    match: 'maxWidth: 480',
  ),
  GateAllow(
    'lib/features/auth_onboarding/presentation/screens/landing_screen.dart',
    ['numeric named arg'],
    _maxWidthReason,
    match: 'maxWidth: 480',
  ),
  GateAllow(
    'lib/features/auth_onboarding/presentation/widgets/onboarding_step_frame.dart',
    ['numeric named arg'],
    _maxWidthReason,
    match: 'maxWidth: 480',
  ),
  GateAllow(
    'lib/features/profile/presentation/screens/profile/user_profile_screen.dart',
    ['numeric named arg'],
    _maxWidthReason,
    match: 'maxWidth: 700',
  ),
  GateAllow(
    'lib/features/profile/presentation/screens/profile/sport_profile_screen.dart',
    ['numeric named arg'],
    _maxWidthReason,
    match: 'maxWidth: 700',
  ),
  GateAllow(
    'lib/core/widgets/composer_drawer_kit.dart',
    ['numeric named arg'],
    _maxWidthReason,
    match: 'maxWidth: 190',
  ),
  GateAllow(
    'lib/features/location/presentation/widgets/location_search_field.dart',
    ['numeric named arg'],
    _maxWidthReason,
    match: 'maxHeight: 280',
  ),
  GateAllow(
    'lib/features/home/presentation/widgets/home_post_row.dart',
    ['numeric named arg'],
    _aspectReason,
    match: 'aspectRatio: 16 / 9',
  ),
  GateAllow(
    'lib/features/social/presentation/screens/post_detail_screen.dart',
    ['numeric named arg'],
    _aspectReason,
    match: 'aspectRatio: 16 / 9',
  ),
  GateAllow(
    'lib/features/social/presentation/widgets/post_media_carousel.dart',
    ['numeric named arg'],
    _aspectReason,
    match: 'aspectRatio: 16 / 9',
  ),
  GateAllow(
    'lib/features/news/presentation/screens/news_detail_screen.dart',
    ['numeric named arg'],
    _aspectReason,
    match: 'aspectRatio: 4 / 5',
  ),
  GateAllow(
    'lib/features/profile/presentation/screens/profile/user_profile_screen.dart',
    ['numeric named arg'],
    _radiusNoneReason,
    match: 'radius: 0,',
  ),
  GateAllow(
    'lib/features/social/presentation/screens/post_composer_screen.dart',
    ['numeric named arg'],
    _pickerReason,
    match: '1920',
  ),
  GateAllow(
    'lib/features/social/presentation/screens/post_detail_screen.dart',
    ['numeric named arg'],
    _pickerReason,
    match: '1920',
  ),
  GateAllow(
    'lib/features/profile/presentation/screens/profile_edit_screen.dart',
    ['numeric named arg'],
    _pickerReason,
    match: '1200',
  ),
  GateAllow(
    'lib/data/models/social/chat_message_model.dart',
    ['numeric named arg'],
    'Attachment byte size parsed from JSON; a data field named size, not a '
        'visual size.',
    match: '?? 0',
  ),
  GateAllow('lib/core/config/supabase_config.dart', [
    'Domain duration literal',
  ], _domainDurationReason),
  GateAllow('lib/core/services/cache_service.dart', [
    'Domain duration literal',
  ], _domainDurationReason),
  GateAllow('lib/core/services/location_service.dart', [
    'Domain duration literal',
  ], _domainDurationReason),
  GateAllow('lib/core/services/profile_cache_service.dart', [
    'Domain duration literal',
  ], _domainDurationReason),
  GateAllow('lib/data/models/activities/activity_log.dart', [
    'Domain duration literal',
  ], _domainDurationReason),
  GateAllow('lib/data/models/core/booking_model.dart', [
    'Domain duration literal',
  ], _domainDurationReason),
  GateAllow('lib/data/models/core/game_creation_model.dart', [
    'Domain duration literal',
  ], _domainDurationReason),
  GateAllow('lib/data/models/core/match_model.dart', [
    'Domain duration literal',
  ], _domainDurationReason),
  GateAllow('lib/data/models/games/booking_model.dart', [
    'Domain duration literal',
  ], _domainDurationReason),
  GateAllow('lib/data/models/games/booking.dart', [
    'Domain duration literal',
  ], _domainDurationReason),
  GateAllow('lib/data/models/games/game_model.dart', [
    'Domain duration literal',
  ], _domainDurationReason),
  GateAllow('lib/data/models/games/game_session.dart', [
    'Domain duration literal',
  ], _domainDurationReason),
  GateAllow('lib/data/models/games/game.dart', [
    'Domain duration literal',
  ], _domainDurationReason),
  GateAllow('lib/data/models/profile/sports_profile.dart', [
    'Domain duration literal',
  ], _domainDurationReason),
  GateAllow('lib/data/models/social/chat_message_model.dart', [
    'Domain duration literal',
  ], _domainDurationReason),
  GateAllow(
    'lib/features/activities/presentation/widgets/activity_event_card.dart',
    ['Domain duration literal'],
    _domainDurationReason,
  ),
  GateAllow(
    'lib/features/auth_onboarding/presentation/screens/create_user_information.dart',
    ['Domain duration literal'],
    _domainDurationReason,
  ),
  GateAllow('lib/features/games/data/datasources/venues_datasource.dart', [
    'Domain duration literal',
  ], _domainDurationReason),
  GateAllow(
    'lib/features/games/data/repositories/bookings_repository_impl.dart',
    ['Domain duration literal'],
    _domainDurationReason,
  ),
  GateAllow(
    'lib/features/games/data/repositories/venues_repository_impl.dart',
    ['Domain duration literal'],
    _domainDurationReason,
  ),
  GateAllow(
    'lib/features/games/presentation/controllers/games_controller.dart',
    ['Domain duration literal'],
    _domainDurationReason,
  ),
  GateAllow(
    'lib/features/games/presentation/controllers/my_games_controller.dart',
    ['Domain duration literal'],
    _domainDurationReason,
  ),
  GateAllow(
    'lib/features/games/presentation/controllers/venues_controller.dart',
    ['Domain duration literal'],
    _domainDurationReason,
  ),
  GateAllow(
    'lib/features/games/presentation/screens/game_composer_screen.dart',
    ['Domain duration literal'],
    _domainDurationReason,
  ),
  GateAllow('lib/features/games/utils/constants/sports_constants.dart', [
    'Domain duration literal',
  ], _domainDurationReason),
  GateAllow('lib/features/games/utils/game_helpers.dart', [
    'Domain duration literal',
  ], _domainDurationReason),
  GateAllow('lib/features/profile/data/datasources/profile_data_sources.dart', [
    'Domain duration literal',
  ], _domainDurationReason),
  GateAllow('lib/features/profile/services/data_export_service.dart', [
    'Domain duration literal',
  ], _domainDurationReason),
  GateAllow('lib/features/profile/services/data_retention_service.dart', [
    'Domain duration literal',
  ], _domainDurationReason),
  GateAllow(
    'lib/features/social/presentation/controllers/chat_controller.dart',
    ['Domain duration literal'],
    _domainDurationReason,
  ),
  GateAllow(
    'lib/features/social/presentation/controllers/friend_requests_controller.dart',
    ['Domain duration literal'],
    _domainDurationReason,
  ),
  GateAllow(
    'lib/features/social/presentation/controllers/friends_controller.dart',
    ['Domain duration literal'],
    _domainDurationReason,
  ),
  GateAllow(
    'lib/features/social/presentation/screens/post_composer_screen.dart',
    ['Domain duration literal'],
    _domainDurationReason,
  ),
  GateAllow(
    'lib/services/notifications/push_notification_service_mobile.dart',
    ['Domain duration literal'],
    _domainDurationReason,
  ),
  GateAllow('lib/services/notifications/push_notification_service_web.dart', [
    'Domain duration literal',
  ], _domainDurationReason),
  GateAllow('lib/services/post_service.dart', [
    'Domain duration literal',
  ], _domainDurationReason),
  GateAllow('lib/utils/constants/app_constants.dart', [
    'Domain duration literal',
  ], _domainDurationReason),
  GateAllow('lib/utils/constants/privacy_constants.dart', [
    'Domain duration literal',
  ], _domainDurationReason),
  GateAllow('lib/utils/constants/profile_constants.dart', [
    'Domain duration literal',
  ], _domainDurationReason),
  GateAllow('lib/utils/helpers/date_formatter.dart', [
    'Domain duration literal',
  ], _domainDurationReason),
];

// ---------------------------------------------------------------------------
// Scanner
// ---------------------------------------------------------------------------

const _id = r'(?<![A-Za-z0-9_])';
final _digit = RegExp(r'(?<![A-Za-z0-9_.])\d');

const _materialWidgets =
    'Scaffold|AppBar|ElevatedButton|TextButton|OutlinedButton|FilledButton|'
    'IconButton|Card|ListTile|CircleAvatar|Chip|TextField|TextFormField|'
    'AlertDialog|SnackBar|CircularProgressIndicator|LinearProgressIndicator|'
    'Divider|Switch|Checkbox|Radio|InkWell|Material|Tooltip|'
    'FloatingActionButton|BottomSheet|Drawer|TabBar|DropdownButton|'
    'PopupMenuButton|Dialog|Opacity';

const _namedArgs =
    'size|height|width|spacing|runSpacing|maxWidth|minWidth|maxHeight|'
    'minHeight|labelWidth|top|bottom|left|right|elevation|thickness|'
    'strokeWidth|blurRadius|opacity|alpha|radius|aspectRatio';

/// Kinds matched by presence alone.
final Map<String, RegExp> _plainRules = {
  'Colors.': RegExp('${_id}Colors\\.'),
  'Color(0x': RegExp('${_id}Color\\(\\s*0x'),
  'Color.from': RegExp('${_id}Color\\.from'),
  'TextStyle(': RegExp('${_id}TextStyle\\('),
  'FontWeight.': RegExp('${_id}FontWeight\\.'),
  'fontSize:': RegExp('${_id}fontSize\\s*:'),
  'letterSpacing:': RegExp('${_id}letterSpacing\\s*:'),
  'raw Text(': RegExp('${_id}Text\\('),
  'raw Text.rich': RegExp('${_id}Text\\.rich\\('),
  'raw Icon(': RegExp('${_id}Icon\\('),
  'Image.': RegExp('${_id}Image\\.(network|asset|file|memory)\\('),
  'Curves.': RegExp('${_id}Curves\\.'),
  'Material visual widget': RegExp('$_id($_materialWidgets)\\('),
};

/// Kinds matched when the call's arguments contain a numeric literal.
final Map<String, RegExp> _callRules = {
  'EdgeInsets numeric': RegExp(
    '${_id}EdgeInsets(Directional)?(\\.[A-Za-z]+)?\\(',
  ),
  'SizedBox numeric': RegExp('${_id}SizedBox(\\.[A-Za-z]+)?\\('),
  'BorderRadius numeric': RegExp(
    '${_id}BorderRadius(Directional)?(\\.[A-Za-z]+)?\\(',
  ),
  'Radius numeric': RegExp('${_id}Radius\\.(circular|elliptical)\\('),
  'withOpacity literal': RegExp(r'\.withOpacity\('),
  'withValues literal': RegExp(r'\.withValues\('),
  'AnimatedOpacity literal': RegExp('${_id}AnimatedOpacity\\('),
};

final _durationCall = RegExp('${_id}Duration\\(');
final _durationUnit = RegExp(
  r'(milliseconds|seconds|microseconds)\s*:\s*[^,]*?(?<![A-Za-z0-9_.])\d',
);
final _domainDurationUnit = RegExp(
  r'(minutes|hours|days)\s*:\s*[^,]*?(?<![A-Za-z0-9_.])\d',
);
final _namedArg = RegExp('$_id($_namedArgs)\\s*:(?!:)');

/// Replaces comments and string-literal contents with spaces, keeping every
/// newline so offsets map back to source lines.
String stripCode(String src) {
  final out = StringBuffer();
  var i = 0;
  while (i < src.length) {
    final c = src[i];
    final next = i + 1 < src.length ? src[i + 1] : '';
    if (c == '/' && next == '/') {
      while (i < src.length && src[i] != '\n') {
        out.write(' ');
        i++;
      }
    } else if (c == '/' && next == '*') {
      final end = src.indexOf('*/', i + 2);
      final stop = end < 0 ? src.length : end + 2;
      for (; i < stop; i++) {
        out.write(src[i] == '\n' ? '\n' : ' ');
      }
    } else if (c == "'" || c == '"') {
      final triple = src.startsWith(c * 3, i);
      final quote = triple ? c * 3 : c;
      final raw = i > 0 && src[i - 1] == 'r';
      out.write(quote);
      i += quote.length;
      while (i < src.length && !src.startsWith(quote, i)) {
        if (!triple && src[i] == '\n') break;
        if (!raw && src[i] == r'\' && i + 1 < src.length) {
          out.write('  ');
          i += 2;
          continue;
        }
        out.write(src[i] == '\n' ? '\n' : ' ');
        i++;
      }
      if (src.startsWith(quote, i)) {
        out.write(quote);
        i += quote.length;
      }
    } else {
      out.write(c);
      i++;
    }
  }
  return out.toString();
}

/// Text from [start] up to the delimiter that closes the current argument
/// list ([toComma]: also stop at a top-level comma). Groups opened by an
/// upper-case constructor call are blanked; they have their own rules.
String argText(String code, int start, {required bool toComma}) {
  final out = StringBuffer();
  var depth = 0;
  var blankUntil = -1;
  for (var i = start; i < code.length; i++) {
    final c = code[i];
    if (c == '(' || c == '[' || c == '{') {
      if (c == '(' && depth >= 0 && blankUntil < 0) {
        final m = RegExp(
          r'_?([A-Za-z][A-Za-z0-9_.]*)\s*(<[^()]*>)?\s*$',
        ).firstMatch(code.substring(start, i));
        final name = m?.group(1) ?? '';
        if (name.isNotEmpty && name[0].toUpperCase() == name[0]) {
          blankUntil = depth;
        }
      }
      depth++;
    } else if (c == ')' || c == ']' || c == '}') {
      depth--;
      if (depth < 0) break;
      if (blankUntil >= 0 && depth == blankUntil) {
        blankUntil = -1;
        continue;
      }
    } else if (c == ',' && depth == 0 && toComma) {
      break;
    } else if (c == ';' && depth <= 0) {
      break;
    }
    if (blankUntil < 0) out.write(c);
  }
  return out.toString();
}

/// Scans one file's source. [path] is only used for reporting.
List<GateHit> scanSource(String path, String src) {
  final code = stripCode(src);
  final lines = src.split('\n');
  final starts = <int>[0];
  for (var i = 0; i < src.length; i++) {
    if (src[i] == '\n') starts.add(i + 1);
  }
  int lineOf(int off) {
    var lo = 0, hi = starts.length - 1;
    while (lo < hi) {
      final mid = (lo + hi + 1) >> 1;
      if (starts[mid] <= off) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    return lo;
  }

  final hits = <GateHit>[];
  void add(String kind, int off) {
    final l = lineOf(off);
    hits.add(GateHit(path, l + 1, kind, lines[l]));
  }

  _plainRules.forEach((kind, rx) {
    for (final m in rx.allMatches(code)) {
      add(kind, m.start);
    }
  });
  _callRules.forEach((kind, rx) {
    for (final m in rx.allMatches(code)) {
      if (_digit.hasMatch(argText(code, m.end, toComma: false))) {
        add(kind, m.start);
      }
    }
  });
  for (final m in _durationCall.allMatches(code)) {
    final args = argText(code, m.end, toComma: false);
    if (_durationUnit.hasMatch(args)) {
      add('Duration literal', m.start);
    } else if (_domainDurationUnit.hasMatch(args)) {
      add('Domain duration literal', m.start);
    }
  }
  for (final m in _namedArg.allMatches(code)) {
    if (_digit.hasMatch(argText(code, m.end, toComma: true))) {
      add('numeric named arg', m.start);
    }
  }
  hits.sort((a, b) => a.line.compareTo(b.line));
  return hits;
}

bool _skipped(String rel) =>
    rel.endsWith('.g.dart') ||
    rel.endsWith('.freezed.dart') ||
    rel.endsWith('.gen.dart') ||
    rel.startsWith('lib/l10n/');

// ---------------------------------------------------------------------------
// Fidelity gate (KAN-425/426): app presentation code composes Dabbler*
// components and layout only. Any visual primitive in a widget file under
// lib/features/**/presentation means the app is painting something by hand
// that belongs in the design system.
//
// Ratchet: files that predate the fidelity rebuild are listed in
// test/fidelity_pending.txt. That list may only shrink: a file that is not
// listed must have zero hits, and a listed file with zero hits is stale and
// must be removed. FIDELITY_ALLOW below is for the rare permanent exception
// and must stay tiny, each with a reason.
final RegExp _visualPrimitive = RegExp(
  r'(?<![A-Za-z0-9_.])(Container|DecoratedBox|ColoredBox|CustomPaint|ClipRRect|'
  r'ClipOval|ClipPath|ClipRect|PhysicalModel|PhysicalShape|BackdropFilter|'
  r'ShaderMask|Stack|BoxDecoration|ShapeDecoration|RoundedRectangleBorder|'
  r'CircleBorder|StadiumBorder|LinearGradient|RadialGradient|BoxShadow|'
  r'CustomPainter|Ink)\s*(<[^()]*>)?\s*\(',
);
final RegExp _widgetClass = RegExp(
  r'class\s+\w+\s+extends\s+(StatelessWidget|StatefulWidget|ConsumerWidget|'
  r'ConsumerStatefulWidget|HookWidget|HookConsumerWidget|State<[^>]*>|'
  r'ConsumerState<[^>]*>|CustomPainter)',
);

/// Reasoned, permanent exceptions to the fidelity gate (path -> reason).
const Map<String, String> fidelityAllow = {};

List<GateHit> scanStructure(String path, String src) {
  final code = stripCode(src);
  if (!_widgetClass.hasMatch(code)) return const [];
  final lines = src.split('\n');
  final hits = <GateHit>[];
  for (final m in _visualPrimitive.allMatches(code)) {
    final l = '\n'.allMatches(code.substring(0, m.start)).length;
    hits.add(GateHit(path, l + 1, 'App-local visual primitive', lines[l]));
  }
  return hits;
}

bool _isPresentation(String rel) =>
    rel.startsWith('lib/features/') && rel.contains('/presentation/');

void main() {
  group('design system gate (self-test)', () {
    List<String> kindsOf(String snippet) =>
        scanSource('x.dart', snippet).map((h) => h.kind).toList();

    const bad = <String, String>{
      'Colors.': 'final c = Colors.red;',
      'Color(0x': 'final c = Color(0xFF000000);',
      'Color.from': 'final c = Color.fromARGB(1, 2, 3, 4);',
      'TextStyle(': 'final s = TextStyle();',
      'FontWeight.': 'final w = FontWeight.w600;',
      'fontSize:': 'x(fontSize: s);',
      'letterSpacing:': 'x(letterSpacing: s);',
      'Duration literal': 'const d = Duration(milliseconds: 300);',
      'EdgeInsets numeric':
          'const e = EdgeInsets.symmetric(\n  horizontal: 8,\n);',
      'SizedBox numeric': 'const b = SizedBox(height: 8);',
      'BorderRadius numeric': 'final r = BorderRadius.circular(12);',
      'Radius numeric': 'const r = Radius.circular(4);',
      'numeric named arg': 'x(opacity: on ? 1 : 0);',
      'withOpacity literal': 'c.withOpacity(0.5);',
      'withValues literal': 'c.withValues(alpha: 0.5);',
      'AnimatedOpacity literal': 'AnimatedOpacity(opacity: on ? 1.0 : 0.0);',
      'raw Text(': "const t = Text('a');",
      'raw Text.rich': 'Text.rich(span);',
      'raw Icon(': 'Icon(icon);',
      'Image.': "Image.network(url);",
      'Curves.': 'final c = Curves.easeOut;',
      'Material visual widget': 'return Scaffold(body: b);',
    };
    bad.forEach((kind, snippet) {
      test('catches $kind', () => expect(kindsOf(snippet), contains(kind)));
    });

    test('catches every listed Material widget and Opacity', () {
      for (final w in _materialWidgets.split('|')) {
        expect(
          kindsOf('$w(child: c);'),
          contains('Material visual widget'),
          reason: w,
        );
      }
    });

    test('catches other duration units and multi-line named args', () {
      expect(
        kindsOf('Duration(\n  seconds: 5,\n)'),
        contains('Duration literal'),
      );
      expect(
        kindsOf('Duration(microseconds: 1)'),
        contains('Duration literal'),
      );
      expect(
        kindsOf('Duration(\n  minutes: 5,\n)'),
        contains('Domain duration literal'),
      );
      expect(
        kindsOf('Duration(hours: 1)'),
        contains('Domain duration literal'),
      );
      expect(kindsOf('Duration(days: 2)'), contains('Domain duration literal'));
      expect(kindsOf('x(\n  top:\n    0,\n)'), contains('numeric named arg'));
      expect(
        kindsOf('x(size: widget.size ?? 24)'),
        contains('numeric named arg'),
      );
    });

    const good = [
      "DabblerText('a', style: DabblerType.body);",
      'DabblerText.rich(spans);',
      'const g = SizedBox(height: DabblerSpacing.space4);',
      'const e = EdgeInsets.all(DabblerSpacing.space4);',
      'final d = Duration.zero;',
      'final d = DabblerMotion.fast;',
      'DabblerCard(child: c);',
      'DabblerIcon(name, size: DabblerSizing.iconMd);',
      'showDialog(context: c);',
      'MaterialApp.router(routerConfig: r);',
      "// Colors.red and Text('x') in a comment",
      "final s = 'Colors.red height: 8 Text(';",
      'x(flex: 2);',
      'x(maxLines: 2, child: DabblerText(a));',
      'SizedBox(child: Foo(count: 3));',
      'Positioned.fill(bottom: DabblerSpacing.space11 + DabblerSpacing.space4);',
    ];
    for (final snippet in good) {
      test('allows: $snippet', () => expect(kindsOf(snippet), isEmpty));
    }
  });

  test('lib/ contains no hard-coded visual values', () {
    final hits = <GateHit>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final rel = f.path.replaceAll(r'\', '/');
      if (_skipped(rel)) continue;
      hits.addAll(scanSource(rel, f.readAsStringSync()));
    }
    final used = <GateAllow>{};
    final failures = <GateHit>[];
    for (final h in hits) {
      final a = allowList.where((a) => a.covers(h));
      if (a.isEmpty) {
        failures.add(h);
      } else {
        used.addAll(a);
      }
    }
    final stale = allowList.where((a) => !used.contains(a)).toList();
    expect(
      failures.map((h) => h.toString()).toList(),
      isEmpty,
      reason:
          'Hard-coded visual values in lib/ (use design-system tokens, or '
          'add a narrow allow-list entry with an honest reason):\n'
          '${failures.join('\n')}',
    );
    expect(
      stale.map((a) => '${a.path} ${a.kinds}').toList(),
      isEmpty,
      reason: 'Stale allow-list entries (they suppress nothing; remove them).',
    );
  });

  group('fidelity gate (self-test)', () {
    List<GateHit> h(String src) => scanStructure('x.dart', src);
    test('catches hand-built visuals in a widget', () {
      for (final w in [
        'Container(child: c)',
        'DecoratedBox(decoration: d)',
        'ClipRRect(child: c)',
        'CustomPaint(painter: p)',
        'Stack(children: [])',
        'ColoredBox(color: c)',
      ]) {
        expect(
          h('class A extends StatelessWidget { Widget build(c) => $w; }'),
          isNotEmpty,
          reason: w,
        );
      }
    });
    test('allows DS components and layout', () {
      expect(
        h(
          'class A extends ConsumerWidget { Widget build(c, r) => '
          'Column(children: [DabblerCard(child: Padding(padding: p, '
          'child: Row(children: [Expanded(child: DabblerText(a))])))]); }',
        ),
        isEmpty,
      );
    });
    test('ignores files with no widget class', () {
      expect(h('final x = Container(child: c);'), isEmpty);
    });
  });

  test('app presentation widgets compose design-system components only', () {
    final pending = File('test/fidelity_pending.txt')
        .readAsLinesSync()
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty && !l.startsWith('#'))
        .toSet();
    final dump = <String>{};
    final newViolations = <GateHit>[];
    final withHits = <String>{};
    for (final f in Directory('lib/features').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final rel = f.path.replaceAll(r'\', '/');
      if (_skipped(rel) || !_isPresentation(rel)) continue;
      if (fidelityAllow.containsKey(rel)) continue;
      final hits = scanStructure(rel, f.readAsStringSync());
      if (hits.isEmpty) continue;
      withHits.add(rel);
      dump.add(rel);
      if (!pending.contains(rel)) newViolations.addAll(hits);
    }
    if (const bool.fromEnvironment('FIDELITY_DUMP')) {
      final sorted = dump.toList()..sort();
      File('test/fidelity_pending.txt').writeAsStringSync(
        '# Files that still paint by hand (pre-fidelity). This list may only '
        'shrink: remove a file as soon as its screen is rebuilt.\n'
        '${sorted.join('\n')}\n',
      );
      return;
    }
    expect(
      newViolations.map((h) => h.toString()).toList(),
      isEmpty,
      reason:
          'App widgets must compose Dabbler* components and layout only. '
          'Move the visual into the design system (alpha-ds), then use it.',
    );
    final stale = pending.where((p) => !withHits.contains(p)).toList()..sort();
    expect(
      stale,
      isEmpty,
      reason:
          'These files are clean now: remove them from '
          'test/fidelity_pending.txt (the ratchet only shrinks).',
    );
  });

}
