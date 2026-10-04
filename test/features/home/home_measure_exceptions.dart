/// Documented, pinned exceptions to the Home measurement: every delta that is
/// not zero is one of the named reasons below, with its measured value pinned
/// (so an exception that drifts fails). Keys are `direction|section|element`.
library;

import 'home_measure_support.dart';

/// arrule
const String kExArabicRuleReason =
    'DS Arabic type rule: Arabic text is set at the Latin size minus 0.9 px (cxo ruling); the frame sets the same size, so the advance is narrower';

/// arstring
const String kExArabicStringReason =
    'copy: the Arabic frame draws the untranslated Latin label Done on the city sheet while the app shows its l10n home_location_done; no frame Arabic exists to adopt (see arabic-diffs.md)';

/// chipglyph
const String kExChipGlyphReason =
    'sub-chip glyph: the frame\'s chip leads with a 14 bold glyph and a 6 gap; the app\'s filter chips (region / sport) draw none, so the chip is 20 narrower';

/// chipglyph_rtl
const String kExChipGlyphRtlReason =
    'sub-chip: the frame\'s chip leads with a 14 bold glyph (20 with its gap) in the Arabic label\'s face; the app\'s filter chip draws none, and the DS Arabic rule sets the label 0.9 smaller';

/// cityhead
const String kExCityDoneReason =
    'city sheet: the Done pill is \'تم\' in the app (l10n) against the frame\'s Latin \'Done\' in its Arabic frame';

/// citylist
const String kExCityListReason =
    'DS gap DabblerListRow(flat): a flat row is 60 + a 1px divider = 61 with a 600 weight title and 21 glyph; the frame\'s row is 62 with a 400 title and 20 glyph; rows below the search field also differ in y (frame draws saved-place chips: no chip feature, see the difference list)';

/// citysearch
const String kExCitySearchReason =
    'DS gap DabblerTextField(search): the search field is 45 high with a 24 glyph and a 16 label; the frame\'s is 42 with a 16 glyph and 15/20 (radius 24, padding 15, gap 9)';

/// emoji
const String kExEmojiReason =
    'sport pill: the frame\'s pill is as tall as its emoji line (15/23 in Arabic = 35); the app draws a 12 glyph in a 32 pill (emoji are banned, ruling in force)';

/// hairline
const String kExSheetHairlineReason =
    'DS sheet paints its 1px hairline inside the padding box; the frame\'s content-box sheet puts every row 1 right/lower (D-sheet, DS gap sheet-hairline)';

/// more
const String kExMoreRtlReason =
    'frame quirk: the frame\'s `margin-left:auto` collapses in RTL, so More sits 18 after Share; the app keeps More at the far end of the row in both directions';

/// sheetcontent
const String kExSheetContentReason =
    'content-sized sheet: the frame lists Hide post and Report user (65 high each); the app lists Report post (65) and Block user (48, no note), so the panel is 17 shorter (no Hide-post feature; Block is App Review 1.2: a git grep for Hide post or hide_post on origin/Canary lib/features finds nothing)';

/// sort
const String kExSortReason =
    'Sort button: the frame draws a 36 high Sort control beside the sub-chips and a 60 high rail (Nearby, News); the app has no sort feature, so its rail is 58 high and the first card sits 2 higher (Canary: no sort UI on Home, see the difference list)';

const Map<String, MeasureException>
kMeasureExceptions = <String, MeasureException>{
  'LTR|Post options sheet|panel (x, width, bottom-anchored)': MeasureException(
    kExSheetContentReason,
    dx: 0.0,
    dy: 17.0,
    dw: 0.0,
    dh: -17.0,
    tol: 0.06,
  ),
  'LTR|News tab|news card': MeasureException(
    kExSortReason,
    dx: 0.0,
    dy: -2.0,
    dw: 0.0,
    dh: 0.0,
    tol: 0.06,
  ),
  'RTL|Upcoming strip (folded)|count label (11/13)': MeasureException(
    kExArabicRuleReason,
    dx: 0.0,
    dy: 0.0,
    dw: -2.77,
    dh: 0.0,
    tol: 0.06,
  ),
  'RTL|Post options sheet|panel (x, width, bottom-anchored)': MeasureException(
    kExSheetContentReason,
    dx: 0.0,
    dy: 17.0,
    dw: 0.0,
    dh: -17.0,
    tol: 0.06,
  ),
  'RTL|News tab|news card': MeasureException(
    kExSortReason,
    dx: 0.0,
    dy: -2.0,
    dw: 0.0,
    dh: 0.0,
    tol: 0.06,
  ),
  'RTL|News tab|sport pill': MeasureException(
    kExArabicRuleReason,
    dx: 0.0,
    dy: 0.0,
    dw: -3.37,
    dh: 0.0,
    tol: 0.06,
  ),
  'RTL|News tab|pill label': MeasureException(
    kExArabicRuleReason,
    dx: -3.37,
    dy: 0.0,
    dw: -3.37,
    dh: 0.0,
    tol: 0.06,
  ),
  'RTL|News tab|comment glyph': MeasureException(
    kExArabicRuleReason,
    dx: 1.28,
    dy: 0.0,
    dw: 0.0,
    dh: 0.0,
    tol: 0.06,
  ),
  'RTL|News tab|views glyph': MeasureException(
    kExArabicRuleReason,
    dx: 2.32,
    dy: 0.0,
    dw: 0.0,
    dh: 0.0,
    tol: 0.06,
  ),
  'RTL|Header (y 50-113)|location text': MeasureException(
    kExArabicRuleReason,
    dx: 0.0,
    dy: 0.0,
    dw: -10.11,
    dh: 0.0,
    tol: 0.06,
  ),
  'RTL|Header (y 50-113)|location chevron': MeasureException(
    kExArabicRuleReason,
    dx: 10.11,
    dy: 0.0,
    dw: 0.0,
    dh: 0.0,
    tol: 0.06,
  ),
  'RTL|Upcoming reminder (stack)|title': MeasureException(
    kExArabicRuleReason,
    dx: 0.0,
    dy: 0.0,
    dw: -4.04,
    dh: 0.0,
    tol: 0.06,
  ),
  'RTL|Upcoming reminder (stack)|month': MeasureException(
    kExArabicRuleReason,
    dx: -0.88,
    dy: 0.0,
    dw: -1.75,
    dh: 0.0,
    tol: 0.06,
  ),
  'RTL|Upcoming reminder (stack)|card title': MeasureException(
    kExArabicRuleReason,
    dx: 0.0,
    dy: 0.0,
    dw: -4.93,
    dh: 0.0,
    tol: 0.06,
  ),
  'RTL|Upcoming reminder (stack)|more chevron': MeasureException(
    kExArabicRuleReason,
    dx: 3.36,
    dy: 0.0,
    dw: 0.0,
    dh: 0.0,
    tol: 0.06,
  ),
  'RTL|Tabs (y 290)|tab For you': MeasureException(
    kExArabicRuleReason,
    dx: 1.0,
    dy: 0.0,
    dw: -1.0,
    dh: 0.0,
    tol: 0.06,
  ),
  'RTL|Tabs (y 290)|tab Following': MeasureException(
    kExArabicRuleReason,
    dx: 3.42,
    dy: 0.0,
    dw: -2.42,
    dh: 0.0,
    tol: 0.06,
  ),
  'RTL|Tabs (y 290)|tab Nearby': MeasureException(
    kExArabicRuleReason,
    dx: 5.42,
    dy: 0.0,
    dw: -2.0,
    dh: 0.0,
    tol: 0.06,
  ),
  'RTL|Tabs (y 290)|tab Active': MeasureException(
    kExArabicRuleReason,
    dx: 7.07,
    dy: 0.0,
    dw: -1.64,
    dh: 0.0,
    tol: 0.06,
  ),
  'RTL|Tabs (y 290)|tab News': MeasureException(
    kExArabicRuleReason,
    dx: 8.47,
    dy: 0.0,
    dw: -1.4,
    dh: 0.0,
    tol: 0.06,
  ),
  'RTL|Tabs (y 290)|active underline (3px, brand)': MeasureException(
    kExArabicRuleReason,
    dx: 1.0,
    dy: 0.0,
    dw: -1.0,
    dh: 0.0,
    tol: 0.06,
  ),
  'RTL|Post row|post row': MeasureException(
    kExEmojiReason,
    dx: 0.0,
    dy: 0.0,
    dw: 0.0,
    dh: -3.0,
    tol: 0.06,
  ),
  'RTL|Post row|author name': MeasureException(
    kExArabicRuleReason,
    dx: -0.01,
    dy: 0.0,
    dw: -4.14,
    dh: 0.0,
    tol: 0.06,
  ),
  'RTL|Post row|role': MeasureException(
    kExArabicRuleReason,
    dx: 4.13,
    dy: 0.0,
    dw: -1.63,
    dh: 0.0,
    tol: 0.06,
  ),
  'RTL|Post row|type badge': MeasureException(
    kExArabicRuleReason,
    dx: 4.3,
    dy: 0.0,
    dw: 1.46,
    dh: 0.0,
    tol: 0.06,
  ),
  'RTL|Post row|badge label': MeasureException(
    kExArabicRuleReason,
    dx: 5.75,
    dy: 0.0,
    dw: 1.46,
    dh: 0.0,
    tol: 0.06,
  ),
  'RTL|Post row|meta time': MeasureException(
    kExArabicRuleReason,
    dx: 0.0,
    dy: 0.0,
    dw: -10.93,
    dh: 0.0,
    tol: 0.06,
  ),
  'RTL|Post row|meta pin': MeasureException(
    kExArabicRuleReason,
    dx: 6.93,
    dy: 0.0,
    dw: 0.0,
    dh: 0.0,
    tol: 0.06,
  ),
  'RTL|Post row|meta place': MeasureException(
    kExArabicRuleReason,
    dx: 10.92,
    dy: 0.0,
    dw: -2.37,
    dh: 0.0,
    tol: 0.06,
  ),
  'RTL|Post row|heart glyph': MeasureException(
    kExEmojiReason,
    dx: 0.0,
    dy: -3.0,
    dw: 0.0,
    dh: 0.0,
    tol: 0.06,
  ),
  'RTL|Post row|like count': MeasureException(
    kExEmojiReason,
    dx: 0.0,
    dy: -3.0,
    dw: -0.79,
    dh: 0.0,
    tol: 0.06,
  ),
  'RTL|Post row|vibe glyph': MeasureException(
    kExEmojiReason,
    dx: 0.79,
    dy: -3.0,
    dw: 0.0,
    dh: 0.0,
    tol: 0.06,
  ),
  'RTL|Post row|comment glyph': MeasureException(
    kExEmojiReason,
    dx: 0.79,
    dy: -3.0,
    dw: 0.0,
    dh: 0.0,
    tol: 0.06,
  ),
  'RTL|Post row|share glyph': MeasureException(
    kExEmojiReason,
    dx: 1.3,
    dy: -3.0,
    dw: 0.0,
    dh: 0.0,
    tol: 0.06,
  ),
  'RTL|Post row|more glyph': MeasureException(
    kExMoreRtlReason,
    dx: -107.8,
    dy: -3.0,
    dw: -0.0,
    dh: 0.0,
    tol: 0.06,
  ),
  'RTL|City sheet (Change location)|Done button (45 box)': MeasureException(
    kExArabicStringReason,
    dx: 0.0,
    dy: -0.01,
    dw: -15.95,
    dh: 0.0,
    tol: 0.06,
  ),
  'LTR|News tab|sub-chip (first), height and padding': MeasureException(
    kExSortReason,
    dx: 0.0,
    dy: -1.0,
    dw: 0.0,
    dh: 0.0,
    tol: 0.06,
  ),
  'RTL|News tab|sub-chip (first), height and padding': MeasureException(
    '$kExSortReason; and $kExArabicRuleReason',
    dx: 1.36,
    dy: -1.0,
    dw: -1.36,
    dh: 0.0,
    tol: 0.06,
  ),
};
