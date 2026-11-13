import 'package:dabbler/data/models/profile_location.dart';
import 'package:dabbler/l10n/app_localizations.dart';

/// The localized name of a saved-place label chip (Home, Work, ...). The
/// model's English `displayName` stays for non-UI uses.
String savedPlaceLabelName(AppLocalizations l, ProfileLocationLabel label) {
  switch (label) {
    case ProfileLocationLabel.home:
      return l.home_location_saved_home;
    case ProfileLocationLabel.work:
      return l.home_location_saved_work;
    case ProfileLocationLabel.school:
      return l.saved_places_label_school;
    case ProfileLocationLabel.current:
      return l.saved_places_label_current;
    case ProfileLocationLabel.custom:
      return l.priv_preset_custom;
  }
}
