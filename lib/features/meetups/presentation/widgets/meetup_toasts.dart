import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';

/// Shows [failure] as an error toast, with copy from its code.
void showMeetupFailure(
  DabblerToastController? toasts,
  AppLocalizations l,
  Failure failure,
) {
  toasts?.show(
    DabblerToastSpec(
      message: failure.code == 'meetup_cancelled'
          ? l.meetups_error_cancelled
          : l.meetups_error_generic,
      tone: DabblerToastTone.error,
    ),
  );
}
