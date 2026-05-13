import 'package:flutter/widgets.dart';

import 'package:dabbler/l10n/app_localizations.dart';

/// Returns the locale-appropriate display label for a persona type.
///
/// Accepts the lowercase string forms used across the codebase
/// (`player`, `organiser`, `hoster`, `socialiser`) and falls back to a
/// capitalised version of the raw input when no specific key matches.
String personaLabel(BuildContext context, String? type) {
  final l10n = AppLocalizations.of(context);
  switch (type?.toLowerCase()) {
    case 'player':
      return l10n.post_card_persona_player;
    case 'organiser':
      return l10n.post_card_persona_organiser;
    case 'hoster':
      return l10n.persona_label_hoster;
    case 'socialiser':
      return l10n.persona_label_socialiser;
  }
  if (type == null || type.isEmpty) return '';
  return type[0].toUpperCase() + type.substring(1);
}
