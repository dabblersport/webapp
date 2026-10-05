import '../../domain/models/meetup_models.dart';

/// Row/jsonb -> model. Counts from views arrive as bigint (int in JSON).
class MeetupMappers {
  const MeetupMappers._();

  static MeetupListItem listItem(Map<String, dynamic> row) =>
      MeetupListItem.fromJson(row);

  static NearbyMeetup nearby(Map<String, dynamic> row) =>
      NearbyMeetup.fromJson(row);

  static MeetupCard card(Map<String, dynamic> json) =>
      MeetupCard.fromJson(json);

  static MeetupAttendee attendee(Map<String, dynamic> row) =>
      MeetupAttendee.fromJson(row);

  static RsvpEligibility eligibility(Map<String, dynamic> json) =>
      RsvpEligibility.fromJson(json);

  static MeetupSport sport(Map<String, dynamic> row) =>
      MeetupSport.fromJson(row);

  static MeetupSportVariant variant(Map<String, dynamic> row) =>
      MeetupSportVariant.fromJson(row);
}
