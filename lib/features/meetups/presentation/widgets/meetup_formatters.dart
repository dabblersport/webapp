import 'package:dabbler/features/meetups/domain/models/meetup_models.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

/// The day word of a start time — Today, Tomorrow, or the date.
String meetupDayLabel(
  AppLocalizations l,
  DateTime at,
  DateTime now,
  String locale,
) {
  final diff = DateTime(
    at.year,
    at.month,
    at.day,
  ).difference(DateTime(now.year, now.month, now.day)).inDays;
  if (diff == 0) return l.listing_today;
  if (diff == 1) return l.listing_tomorrow;
  return DateFormat.MMMd(locale).format(at);
}

/// A sport's name in the viewer's language, English when there is none.
String meetupSportName(BuildContext context, MeetupSport s) {
  final ar = s.nameAr?.trim();
  if (Localizations.localeOf(context).languageCode == 'ar' &&
      ar != null &&
      ar.isNotEmpty) {
    return ar;
  }
  return s.nameEn;
}

/// The countdown number and unit to [at], within the design's three-day window.
({String value, String unit, double fraction}) meetupCountdown(
  AppLocalizations l,
  DateTime at,
  DateTime now,
) {
  const windowMinutes = 3 * 24 * 60;
  final left = at.difference(now);
  final r = left.isNegative ? Duration.zero : left;
  final fraction = 1 - (r.inMinutes / windowMinutes).clamp(0.0, 1.0);
  if (r.inDays > 0) {
    return (
      value: '${r.inDays}',
      unit: r.inDays == 1 ? l.listing_unit_day : l.listing_unit_days,
      fraction: fraction,
    );
  }
  if (r.inHours > 0) {
    return (
      value: '${r.inHours}',
      unit: r.inHours == 1 ? l.listing_unit_hour : l.listing_unit_hours,
      fraction: fraction,
    );
  }
  return (
    value: '${r.inMinutes}',
    unit: l.listing_unit_min,
    fraction: fraction,
  );
}
