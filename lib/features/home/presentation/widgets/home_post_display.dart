import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import 'package:dabbler/data/models/social/post.dart';
import 'package:dabbler/features/social/presentation/composer_emoji.dart';
import 'package:dabbler/l10n/app_localizations.dart';

/// KAN-961: how the Home Feed design (`Home Feed.dc.html`) derives a post
/// card's display fields, kept out of the row widget.

/// The design's `#hashtag` token (`#[A-Za-z0-9_]+`), widened to letters and
/// digits of any script so an Arabic tag is a link too.
final RegExp _hashtag = RegExp(r'#[\p{L}\p{N}\p{M}_]+', unicode: true);

/// The body as runs, as the design's `segments(p.body)`: plain text, with each
/// `#hashtag` inside the body drawn as a link where it stands. Tags the post
/// carries that the body does not already show follow as link runs.
List<DabblerPostSegment> homePostSegments(Post post) {
  final String body = (post.body ?? '').trim();
  final List<DabblerPostSegment> runs = <DabblerPostSegment>[];
  final Set<String> shown = <String>{};
  var cursor = 0;
  for (final RegExpMatch m in _hashtag.allMatches(body)) {
    if (m.start > cursor) {
      runs.add(DabblerPostSegment(body.substring(cursor, m.start)));
    }
    final String token = m.group(0)!;
    runs.add(DabblerPostSegment(token, link: true));
    shown.add(token.substring(1).toLowerCase());
    cursor = m.end;
  }
  if (cursor < body.length) {
    runs.add(DabblerPostSegment(body.substring(cursor)));
  }
  for (final String raw in post.tags) {
    final String tag = raw.trim().replaceFirst(RegExp('^#'), '');
    if (tag.isEmpty || !shown.add(tag.toLowerCase())) continue;
    runs.add(DabblerPostSegment(runs.isEmpty ? '#$tag' : ' #$tag', link: true));
  }
  return runs;
}

/// The design's fallback when a sport has no emoji (`SPORT_EMOJI[p.sport] ??
/// '🏅'`).
const String homeSportEmojiFallback = '🏅';

/// The sport pill's emoji (`p.sportEmoji`), drawn by the pill at 15/20.
String homeSportEmoji(String? keyOrName) =>
    composerSportEmoji(keyOrName) ?? homeSportEmojiFallback;

/// The post's age in the design's short form: `2h` in English, `2 س` in
/// Arabic. Older than a week is the localised month and day.
String homePostAge(BuildContext context, DateTime createdAt) {
  final AppLocalizations l10n = AppLocalizations.of(context);
  final Duration diff = DateTime.now().difference(createdAt);
  if (diff.inMinutes < 1) {
    return l10n.home_post_age_seconds(diff.isNegative ? 0 : diff.inSeconds);
  }
  if (diff.inHours < 1) return l10n.home_post_age_minutes(diff.inMinutes);
  if (diff.inDays < 1) return l10n.home_post_age_hours(diff.inHours);
  if (diff.inDays < 7) return l10n.home_post_age_days(diff.inDays);
  return DateFormat.MMMd(l10n.localeName).format(createdAt);
}
