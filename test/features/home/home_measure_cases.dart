/// The element rows of the Home measurement, grouped by region. Design rects
/// are the measuring seat's numbers (`home-design-measure.md`, sections 3-7),
/// LTR first and RTL second, in the 393x852 frame.
library;

import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'home_measure_data.dart';
import 'home_measure_support.dart';

/// Pairs the design rect for this direction with the app's.
void row(
  MeasureTable t,
  String section,
  String name, {
  required Rect ltr,
  required Rect rtl,
  required Rect Function() app,
  Basis basis = Basis.box,
  MeasureException? exLtr,
  MeasureException? exRtl,
  String token = '',
}) {
  final Measure m = Measure(
    name,
    t.rtl ? rtl : ltr,
    basis: basis,
    exception: t.rtl ? exRtl : exLtr,
    token: token,
  );
  try {
    m.app = app();
  } catch (e) {
    m.app = Rect.zero;
  }
  t.add(section, m);
}

Rect _r(WidgetTester tester, Finder f, [int i = 0]) => tester.getRect(f.at(i));

Finder _within(Type ancestor, Finder f) =>
    find.descendant(of: find.byType(ancestor).first, matching: f);

Finder _icons(Type ancestor) => _within(ancestor, find.byType(DabblerIcon));

/// Header: wordmark, location row, search, bell, avatar (section 3).
void addHeaderRows(MeasureTable t, WidgetTester tester, {required bool rtl}) {
  const String s = 'Header (y 50-113)';
  final Finder bar = find.byType(DabblerNavigationTopBar);
  final Finder icons = _icons(DabblerNavigationTopBar);
  final Finder rings = _within(
    DabblerNavigationTopBar,
    find.byType(DabblerFocusRing),
  );
  row(
    t,
    s,
    'header row',
    ltr: rc(0, 50, 393, 63),
    rtl: rc(0, 50, 393, 63),
    app: () {
      final Rect b = _r(tester, bar);
      return Rect.fromLTRB(b.left, 50, b.right, b.bottom);
    },
  );
  row(
    t,
    s,
    'logo',
    ltr: rc(18, 59, 110, 21),
    rtl: rc(265, 59, 110, 21),
    app: () => _r(tester, find.byType(DabblerWordmark)),
  );
  row(
    t,
    s,
    'location pin',
    ltr: rc(18, 85, 13, 13),
    rtl: rc(362, 85, 13, 13),
    app: () => _r(tester, icons, 0),
  );
  row(
    t,
    s,
    'location text',
    ltr: rc(35, 85, 152.75, 12),
    rtl: rc(234.56, 83, 123.44, 17),
    basis: Basis.text,
    app: () => _r(tester, find.text(FrameData.of(rtl).location)),
  );
  row(
    t,
    s,
    'location chevron',
    ltr: rc(191.75, 85.5, 12, 12),
    rtl: rc(218.56, 85.5, 12, 12),
    app: () => _r(tester, icons, 1),
  );
  row(
    t,
    s,
    'search button',
    ltr: rc(237, 56, 45, 45),
    rtl: rc(111, 56, 45, 45),
    app: () => _r(tester, rings, 0),
  );
  row(
    t,
    s,
    'search glyph',
    ltr: rc(247.5, 66.5, 24, 24),
    rtl: rc(121.5, 66.5, 24, 24),
    app: () => _r(tester, icons, 2),
  );
  row(
    t,
    s,
    'bell button',
    ltr: rc(288, 56, 45, 45),
    rtl: rc(60, 56, 45, 45),
    app: () => _r(tester, rings, 1),
  );
  row(
    t,
    s,
    'bell glyph',
    ltr: rc(298.5, 66.5, 24, 24),
    rtl: rc(70.5, 66.5, 24, 24),
    app: () => _r(tester, icons, 3),
  );
  row(
    t,
    s,
    'bell unread dot',
    ltr: rc(311, 65, 13, 13),
    rtl: rc(83, 65, 13, 13),
    app: () => _r(tester, find.byKey(DabblerNavigationUnreadDot.dotKey)),
  );
  row(
    t,
    s,
    'avatar',
    ltr: rc(339, 60.5, 36, 36),
    rtl: rc(18, 60.5, 36, 36),
    app: () => _r(
      tester,
      _within(DabblerNavigationTopBar, find.byType(DabblerAvatar)),
    ),
  );
}

/// Upcoming reminder, default 3-item stack (section 4).
void addUpcomingRows(MeasureTable t, WidgetTester tester, {required bool rtl}) {
  const String s = 'Upcoming reminder (stack)';
  final Finder block = find.byType(DabblerUpcomingReminder);
  final Finder icons = _icons(DabblerUpcomingReminder);
  final Finder surfaces = _within(
    DabblerUpcomingReminder,
    find.byType(DabblerSurface),
  );
  row(
    t,
    s,
    'reminder block (inside the 18 gutter)',
    ltr: rc(18, 113, 357, 165),
    rtl: rc(18, 113, 357, 165),
    app: () => _r(tester, block),
  );
  row(
    t,
    s,
    'title',
    ltr: rc(18, 113, 120.83, 25),
    rtl: rc(285.7, 107, 89.3, 37),
    basis: Basis.text,
    app: () => _r(tester, find.textContaining('·').first),
  );
  row(
    t,
    s,
    'hide button',
    ltr: rc(349, 108.5, 34, 34),
    rtl: rc(18, 108.5, 34, 34),
    app: () => _r(
      tester,
      _within(DabblerUpcomingReminder, find.byType(DabblerExpandedHitArea)),
      1,
    ),
  );
  row(
    t,
    s,
    'hide glyph',
    ltr: rc(357, 116.5, 18, 18),
    rtl: rc(26, 116.5, 18, 18),
    app: () => _r(tester, icons, 0),
  );
  row(
    t,
    s,
    'back card (white)',
    ltr: rc(32, 194, 329, 42),
    rtl: rc(32, 194, 329, 42),
    app: () => _r(tester, surfaces, 0),
  );
  row(
    t,
    s,
    'back card (sunken)',
    ltr: rc(25, 201, 343, 42),
    rtl: rc(25, 201, 343, 42),
    app: () => _r(tester, surfaces, 1),
  );
  row(
    t,
    s,
    'front card',
    ltr: rc(18, 147, 357, 82),
    rtl: rc(18, 147, 357, 82),
    app: () => _r(tester, surfaces, 2),
  );
  row(
    t,
    s,
    'date block',
    ltr: rc(31, 160, 48, 56),
    rtl: rc(314, 160, 48, 56),
    app: () => _r(tester, surfaces, 3),
  );
  row(
    t,
    s,
    'month',
    ltr: rc(46.67, 170, 16.66, 12),
    rtl: rc(327.36, 166.5, 21.3, 17),
    basis: Basis.text,
    app: () => _r(tester, find.text('OCT')),
  );
  row(
    t,
    s,
    'card title',
    ltr: rc(91, 171, 99.89, 16),
    rtl: rc(219.86, 167.5, 82.14, 23),
    basis: Basis.text,
    app: () => _r(tester, find.text(FrameData.of(rtl).gameTitle)),
  );
  row(
    t,
    s,
    'meta line',
    ltr: rc(91, 191, 203, 16),
    rtl: rc(99, 192.5, 203, 16),
    basis: Basis.line,
    app: () => _r(tester, find.textContaining(FrameData.of(rtl).venue)),
  );
  row(
    t,
    s,
    'ring',
    ltr: rc(306, 160, 56, 56),
    rtl: rc(31, 160, 56, 56),
    app: () => _r(tester, find.byType(DabblerRing)),
  );
  row(
    t,
    s,
    'more row',
    ltr: rc(18, 246, 357, 32),
    rtl: rc(18, 246, 357, 32),
    app: () => tester.getRect(
      _within(DabblerUpcomingReminder, find.byType(DabblerFeedTappable)).last,
    ),
  );
  row(
    t,
    s,
    'more chevron',
    ltr: rc(234.44, 254, 16, 16),
    rtl: rc(137.03, 254, 16, 16),
    app: () => _r(tester, icons, 1),
  );
}

/// Tabs row (section 5): five tabs and the active underline.
void addTabRows(MeasureTable t, WidgetTester tester, {required bool rtl}) {
  const String s = 'Tabs row (y 290)';
  final Finder tabs = find.byType(DabblerTabs);
  row(
    t,
    s,
    'tabs strip (hairline runs edge to edge)',
    ltr: rc(0, 290, 393, 33),
    rtl: rc(0, 290, 393, 36),
    app: () => _r(tester, tabs),
  );
}

/// First post row of For you (section 7a).
void addPostRows(
  MeasureTable t,
  WidgetTester tester, {
  required bool rtl,
  required AppLocalizations l,
}) {
  const String s = 'Post row';
  final Finder post = find.byType(DabblerPostRow).first;
  final Finder icons = find.descendant(
    of: post,
    matching: find.byType(DabblerIcon),
  );
  final Finder actions = find.descendant(
    of: post,
    matching: find.byType(DabblerFeedAction),
  );
  Rect glyphOf(int i) => tester.getRect(
    find
        .descendant(of: actions.at(i), matching: find.byType(DabblerIcon))
        .first,
  );
  Finder inPost(Finder f) => find.descendant(of: post, matching: f);
  row(
    t,
    s,
    'post row',
    ltr: rc(18, 323, 357, 215),
    rtl: rc(18, 326, 357, 207),
    app: () => _r(tester, post),
  );
  row(
    t,
    s,
    'avatar',
    ltr: rc(18, 338, 36, 36),
    rtl: rc(339, 341, 36, 36),
    app: () => _r(tester, inPost(find.byType(DabblerAvatar))),
  );
  row(
    t,
    s,
    'author name',
    ltr: rc(66, 340, 69.56, 16),
    rtl: rc(258.38, 341, 68.63, 23),
    basis: Basis.text,
    app: () => _r(tester, inPost(find.text(FrameData.of(rtl).name))),
  );
  row(
    t,
    s,
    'role',
    ltr: rc(150.56, 341, 28.42, 14),
    rtl: rc(221.75, 343.5, 21.63, 18),
    basis: Basis.text,
    app: () => _r(tester, inPost(find.text(l.post_card_persona_player))),
  );
  row(
    t,
    s,
    'type badge',
    ltr: rc(184.98, 339.5, 32.89, 17),
    rtl: rc(183.28, 344, 32.47, 17),
    app: () => _r(tester, inPost(find.byType(DabblerBadge))),
  );
  row(
    t,
    s,
    'badge label',
    ltr: rc(192.98, 341.5, 16.89, 13),
    rtl: rc(191.28, 346, 16.47, 13),
    basis: Basis.text,
    app: () => _r(tester, inPost(find.text(l.post_card_kind_dab))),
  );
  row(
    t,
    s,
    'meta globe',
    ltr: rc(66, 365.5, 13, 13),
    rtl: rc(314, 371.5, 13, 13),
    app: () => _r(tester, icons, 0),
  );
  row(
    t,
    s,
    'meta time',
    ltr: rc(84, 365, 11.45, 14),
    rtl: rc(285.67, 369, 23.33, 18),
    basis: Basis.text,
    app: () => _r(tester, inPost(find.text('2h'))),
  );
  row(
    t,
    s,
    'meta pin',
    ltr: rc(104.45, 365.5, 13, 13),
    rtl: rc(267.67, 371.5, 13, 13),
    app: () => _r(tester, icons, 1),
  );
  row(
    t,
    s,
    'meta place',
    ltr: rc(122.45, 365, 62.33, 14),
    rtl: rc(227.16, 369, 31.52, 18),
    basis: Basis.text,
    app: () => _r(tester, inPost(find.text(FrameData.of(rtl).place))),
  );
  row(
    t,
    s,
    'body',
    ltr: rc(66, 389, 309, 60),
    rtl: rc(18, 395, 309, 46),
    app: () => _r(
      tester,
      inPost(find.textContaining(FrameData.of(rtl).body.substring(0, 6))),
    ),
  );
  row(
    t,
    s,
    'heart glyph',
    ltr: rc(66, 502, 20, 20),
    rtl: rc(307, 497, 20, 20),
    app: () => glyphOf(0),
  );
  row(
    t,
    s,
    'like count',
    ltr: rc(92, 505, 9.84, 14),
    rtl: rc(290.64, 498, 10.36, 18),
    basis: Basis.text,
    app: () => _r(tester, inPost(find.text('12'))),
  );
  row(
    t,
    s,
    'vibe glyph',
    ltr: rc(119.84, 502, 20, 20),
    rtl: rc(252.64, 497, 20, 20),
    app: () => glyphOf(1),
  );
  row(
    t,
    s,
    'comment glyph',
    ltr: rc(157.84, 502, 20, 20),
    rtl: rc(214.64, 497, 20, 20),
    app: () => glyphOf(2),
  );
  row(
    t,
    s,
    'share glyph',
    ltr: rc(207.8, 502, 20, 20),
    rtl: rc(163.8, 497, 20, 20),
    app: () => glyphOf(3),
  );
  row(
    t,
    s,
    'more glyph',
    ltr: rc(355, 502, 20, 20),
    rtl: rc(125.8, 497, 20, 20),
    app: () => glyphOf(4),
  );
}
