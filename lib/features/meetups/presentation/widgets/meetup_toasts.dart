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

/// The RSVP became a join request (KAN-1012): say so, never "Going".
void showMeetupRequested(DabblerToastController? toasts, AppLocalizations l) {
  toasts?.show(DabblerToastSpec(message: l.listing_request_sent));
}
