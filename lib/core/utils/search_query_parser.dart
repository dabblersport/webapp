/// Parses a raw search query string into a structured [ParsedSearchQuery].
///
/// Parsing rules (evaluated in order, first match wins):
/// - `@username`   → profiles
/// - `#hashtag`    → hashtags
/// - `/g query`    → games
/// - `/v query`    → venues
/// - `/p query`    → posts
/// - `/c query`    → comments
/// - `/m query`    → meetups
/// - default       → all
///
/// The returned [ParsedSearchQuery.cleanQuery] has the prefix stripped so
/// callers receive only the meaningful search term.
class SearchQueryParser {
  const SearchQueryParser._();

  static ParsedSearchQuery parse(String rawQuery) {
    final trimmed = rawQuery.trim();

    if (trimmed.isEmpty) {
      return const ParsedSearchQuery(cleanQuery: '', mode: SearchMode.all);
    }

    // --- @username → profiles -------------------------------------------------
    if (trimmed.startsWith('@')) {
      return ParsedSearchQuery(
        cleanQuery: trimmed.substring(1).trim(),
        mode: SearchMode.profiles,
      );
    }

    // --- #hashtag → hashtags --------------------------------------------------
    if (trimmed.startsWith('#')) {
      return ParsedSearchQuery(
        cleanQuery: trimmed.substring(1).trim(),
        mode: SearchMode.hashtags,
      );
    }

    // --- slash commands -------------------------------------------------------
    if (trimmed.startsWith('/')) {
      final spaceIdx = trimmed.indexOf(' ');
      final command = spaceIdx == -1
          ? trimmed.toLowerCase()
          : trimmed.substring(0, spaceIdx).toLowerCase();
      final rest = spaceIdx == -1 ? '' : trimmed.substring(spaceIdx + 1).trim();

      switch (command) {
        case '/g':
          return ParsedSearchQuery(cleanQuery: rest, mode: SearchMode.games);
        case '/v':
          return ParsedSearchQuery(cleanQuery: rest, mode: SearchMode.venues);
        case '/p':
          return ParsedSearchQuery(cleanQuery: rest, mode: SearchMode.posts);
        case '/c':
          return ParsedSearchQuery(cleanQuery: rest, mode: SearchMode.comments);
        case '/m':
          return ParsedSearchQuery(cleanQuery: rest, mode: SearchMode.meetups);
        default:
          // Unknown slash command — treat full string as free-form all search.
          break;
      }
    }

    // --- fallback: all --------------------------------------------------------
    return ParsedSearchQuery(cleanQuery: trimmed, mode: SearchMode.all);
  }
}

// ---------------------------------------------------------------------------
// Value types
// ---------------------------------------------------------------------------

enum SearchMode {
  all,
  profiles,
  games,
  venues,
  posts,
  comments,
  hashtags,
  meetups,
}

class ParsedSearchQuery {
  final String cleanQuery;
  final SearchMode mode;

  const ParsedSearchQuery({required this.cleanQuery, required this.mode});

  @override
  String toString() =>
      'ParsedSearchQuery(mode: $mode, cleanQuery: "$cleanQuery")';
}
