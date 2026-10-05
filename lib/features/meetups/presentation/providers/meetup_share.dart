import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

/// Shares [link] with [headline] as its title, through the same mechanism the
/// game detail uses (`share_plus`, the link as a first-class URL so messengers
/// show a preview). Overridable for tests.
typedef MeetupShare = Future<void> Function(String link, String headline);

final meetupShareProvider = Provider<MeetupShare>((ref) {
  return (String link, String headline) async {
    await SharePlus.instance.share(
      ShareParams(uri: Uri.parse(link), title: headline, subject: headline),
    );
  };
});
