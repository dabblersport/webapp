/// Tabs, News and Active rows of the Home measurement (see
/// `home_measure_cases.dart` for the conventions).
library;

import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dabbler/features/home/presentation/widgets/active_event_card.dart';

import 'home_measure_cases.dart';
import 'home_measure_data.dart';
import 'home_measure_support.dart';

Rect _r(WidgetTester tester, Finder f, [int i = 0]) => tester.getRect(f.at(i));

/// The five tabs and the active underline (section 5), in tab-rail order.
void addTabItemRows(MeasureTable t, WidgetTester tester, {required bool rtl}) {
  const String s = 'Tabs (y 290)';
  final Finder tabs = find.descendant(
    of: find.byType(DabblerTabs),
    matching: find.byType(DabblerExpandedHitArea),
  );
  // KAN-959 (`homefeed2`, line 262): For you and Active carry the filter
  // pill after the label — a 4 gap and a 22 pill (12 glyph + 5/5 padding) —
  // so both are 26 wider and every tab after them moves 26.
  final List<Rect> ltr = <Rect>[
    rc(18, 290, 68.53, 33),
    rc(107.53, 290, 53.63, 33),
    rc(182.16, 290, 41.94, 33),
    rc(245.09, 290, 61.09, 33),
    rc(327.19, 290, 31.83, 33),
  ];
  final List<Rect> rtlR = <Rect>[
    rc(332.39, 290, 42.61, 36),
    rc(271.28, 290, 40.11, 36),
    rc(217.06, 290, 33.22, 36),
    rc(142.84, 290, 53.22, 36),
    rc(98.67, 290, 23.17, 36),
  ];
  const List<String> names = <String>[
    'For you',
    'Following',
    'Nearby',
    'Active',
    'News',
  ];
  for (var i = 0; i < 5; i++) {
    row(
      t,
      s,
      'tab ${names[i]}',
      ltr: ltr[i],
      rtl: rtlR[i],
      app: () => _r(tester, tabs, i),
    );
  }
  row(
    t,
    s,
    'active underline (3px, brand)',
    ltr: rc(18, 320, 68.53, 3),
    rtl: rc(332.39, 323, 42.61, 3),
    app: () => _r(
      tester,
      find.descendant(
        of: find.byType(DabblerTabs),
        matching: find.byType(AnimatedPositionedDirectional),
      ),
    ),
  );
}

/// Sub-chip rail on the News tab (section 6) and the first news card
/// (section 7c). Card rows are measured from the card's own top-left so the
/// rail above it (the design's 60 with a Sort button, the app's 58 without)
/// does not shift them; the card's own y is its own row.
void addNewsRows(MeasureTable t, WidgetTester tester, {required bool rtl}) {
  const String s = 'News tab';
  final Finder chip = find.byType(DabblerChip).first;
  final Finder news = find.byType(DabblerNewsCard).first;
  final Finder card = find
      .descendant(of: news, matching: find.byType(DabblerFeedTappable))
      .first;
  Finder inCard(Finder f) => find.descendant(of: news, matching: f);
  final Finder icons = inCard(find.byType(DabblerIcon));
  final Offset origin = tester.getTopLeft(card);
  Rect rel(Rect r) => r.shift(-origin);
  const Offset oL = Offset(18, 383);
  const Offset oR = Offset(18, 386);
  Rect dl(double x, double y, double w, double h) => rc(x, y, w, h).shift(-oL);
  Rect dr(double x, double y, double w, double h) => rc(x, y, w, h).shift(-oR);

  row(
    t,
    s,
    'sub-chip (first), height and padding',
    ltr: rc(18, 336, 78.91, 34),
    rtl: rc(305.39, 339, 69.61, 34),
    app: () => _r(tester, chip),
  );
  row(
    t,
    s,
    'news card',
    ltr: rc(18, 383, 357, 357),
    rtl: rc(18, 386, 357, 369),
    app: () => _r(tester, card),
  );
  row(
    t,
    s,
    'hero (210, radius 18)',
    ltr: dl(18, 383, 357, 210),
    rtl: dr(18, 386, 357, 210),
    app: () => rel(_r(tester, inCard(find.byType(ClipRRect)))),
  );
  row(
    t,
    s,
    'sport pill',
    ltr: dl(30, 395, 53.66, 21),
    rtl: dr(30, 398, 61.05, 21),
    app: () => rel(_r(tester, inCard(find.byType(DabblerBadge)))),
  );
  row(
    t,
    s,
    'pill label',
    ltr: dl(40, 399, 33.66, 13),
    rtl: dr(40, 402, 41.05, 13),
    basis: Basis.text,
    app: () => rel(_r(tester, inCard(find.text(FrameData.of(rtl).football)))),
  );
  row(
    t,
    s,
    'heart glyph',
    ltr: dl(18, 602, 18, 18),
    rtl: dr(357, 605, 18, 18),
    app: () => rel(_r(tester, icons, 0)),
  );
  row(
    t,
    s,
    'comment glyph',
    ltr: dl(72.77, 602, 18, 18),
    rtl: dr(300.88, 605, 18, 18),
    app: () => rel(_r(tester, icons, 1)),
  );
  row(
    t,
    s,
    'views glyph',
    ltr: dl(123.61, 602, 18, 18),
    rtl: dr(248.15, 605, 18, 18),
    app: () => rel(_r(tester, icons, 2)),
  );
  row(
    t,
    s,
    'headline',
    ltr: dl(18, 630, 349, 41),
    rtl: dr(75.5, 631, 299.5, 51),
    basis: Basis.line,
    app: () => rel(
      _r(tester, inCard(find.textContaining(FrameData.of(rtl).newsTitleKey))),
    ),
  );
  row(
    t,
    s,
    'text block (headline + 5 + excerpt)',
    ltr: dl(18, 629, 357, 89),
    rtl: dr(18, 632, 357, 101),
    app: () {
      final Rect h = _r(
        tester,
        inCard(find.textContaining(FrameData.of(rtl).newsTitleKey)),
      );
      final Rect e = _r(
        tester,
        inCard(find.textContaining(FrameData.of(rtl).newsExcerptKey)),
      );
      return rel(h.expandToInclude(e));
    },
  );
}

/// KAN-957: the Active activity card (`Home Feed.dc.html:370-432`),
/// measured from the card's own top-left: the card, the 16 bold type glyph
/// (12 padding inside a 1px outline) and the 45 date tile (x and size; its y
/// follows the actor row, whose line heights differ per script).
void addActiveRows(MeasureTable t, WidgetTester tester, {required bool rtl}) {
  const String s = 'Active tab (activity card)';
  final Finder card0 = find.byType(ActiveEventCard).first;
  final Rect cardApp = tester.getRect(card0);
  Finder inCard(Finder f) => find.descendant(of: card0, matching: f);
  Rect rel(Rect r) => r.shift(-cardApp.topLeft);
  row(
    t,
    s,
    'card (x and width; radius 18)',
    ltr: rc(18, 0, 357, 0),
    rtl: rc(18, 0, 357, 0),
    app: () => Rect.fromLTWH(cardApp.left, 0, cardApp.width, 0),
  );
  row(
    t,
    s,
    'type glyph 16x16',
    ltr: rc(13, 14, 16, 16),
    rtl: rc(328, 14, 16, 16),
    app: () => rel(_r(tester, inCard(find.byType(DabblerIcon)))),
  );
  row(
    t,
    s,
    'date tile 45x45 (9 inside the listing row)',
    ltr: rc(22, 0, 45, 45),
    rtl: rc(290, 0, 45, 45),
    basis: Basis.inset,
    app: () => rel(
      _r(
        tester,
        inCard(find.byKey(const ValueKey<String>('active-date-tile'))),
      ),
    ),
  );
}
