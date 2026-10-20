import 'package:dabbler/l10n/app_localizations.dart';

/// First-strong isolate (U+2068 .. U+2069) around a person's name, so a Latin
/// name inside an Arabic sentence (or the reverse) keeps its own direction and
/// the sentence keeps its word order.
String isolateName(String name) => '\u2068$name\u2069';

/// The typing label of a group (design section 10): one name, two names, or
/// the first name and a count of the others. [names] holds the typers' names
/// in the order they started (only the first two are read; an empty entry
/// reads as "Someone"); [total] is how many are typing.
String groupTypingLabel(
  AppLocalizations l10n, {
  required List<String> names,
  required int total,
}) {
  String at(int i) => i < names.length && names[i].trim().isNotEmpty
      ? isolateName(names[i].trim())
      : l10n.messaging_typing_someone;
  if (total <= 1) return l10n.messaging_typing_one(at(0));
  if (total == 2) return l10n.messaging_typing_two(at(0), at(1));
  return l10n.messaging_typing_many(at(0), total - 1);
}
