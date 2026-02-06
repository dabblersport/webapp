import 'package:meta/meta.dart';

@immutable
class SportProfile {
  const SportProfile({
    required this.profileId,
    required this.sportKey,
    this.attributes = const <String, dynamic>{},
    this.overallLevel = 0.0,
    this.xpTotal = 0.0,
    this.xpLevel = 0.0,
    this.xpNextLevel = 0.0,
    this.matchesPlayed = 0,
    this.primaryPosition = '',
    this.secondaryPositions = const <dynamic>[],
    this.playstyle = '',
    this.formScore = 0.0,
    this.formTrend = '',
    this.last5Matches = const <dynamic>[],
    this.attendanceRate = 0.0,
    this.cancellationRate = 0.0,
    this.punctualityScore = 0.0,
    this.teamworkScore = 0.0,
    this.ratingCount = 0,
    this.ratingTotal = 0.0,
    this.reliabilityScore = 0.0,
    this.verificationStatus = '',
    this.verifiedBy,
    this.verificationMedia = const <dynamic>[],
    this.verificationNote = '',
    this.verificationDate,
    this.performanceHighlights = const <dynamic>[],
    this.mlLastVector = const <dynamic>[],
    this.mlAvgVector = const <dynamic>[],
    this.mlVectorCount = 0,
    this.heatmapJson = const <String, dynamic>{},
    this.movementIntensity = 0.0,
    this.staminaScore = 0.0,
    this.preferredVenues = const <dynamic>[],
    this.performanceByVenue = const <String, dynamic>{},
    this.tierId,
  });

  factory SportProfile.fromJson(Map<String, dynamic> json) {
    return SportProfile(
      profileId:
          json['profile_id'] as String? ?? json['profileId'] as String? ?? '',
      sportKey:
          json['sport'] as String? ??
          json['sport_key'] as String? ??
          json['sportKey'] as String? ??
          '',
      attributes: _readMap(json['attributes'] ?? json['profile_attributes']),
      overallLevel: _readDouble(json['overall_level'] ?? json['overallLevel']),
      xpTotal: _readDouble(json['xp_total'] ?? json['xpTotal']),
      xpLevel: _readDouble(json['xp_level'] ?? json['xpLevel']),
      xpNextLevel: _readDouble(json['xp_next_level'] ?? json['xpNextLevel']),
      matchesPlayed: _readInt(json['matches_played'] ?? json['matchesPlayed']),
      primaryPosition: _readString(
        json['primary_position'] ?? json['primaryPosition'],
      ),
      secondaryPositions: _readList(
        json['secondary_positions'] ?? json['secondaryPositions'],
      ),
      playstyle: _readString(json['playstyle']),
      formScore: _readDouble(json['form_score'] ?? json['formScore']),
      formTrend: _readString(json['form_trend'] ?? json['formTrend']),
      last5Matches: _readList(json['last5_matches'] ?? json['last_5_matches']),
      attendanceRate: _readDouble(
        json['attendance_rate'] ?? json['attendanceRate'],
      ),
      cancellationRate: _readDouble(
        json['cancellation_rate'] ?? json['cancellationRate'],
      ),
      punctualityScore: _readDouble(
        json['punctuality_score'] ?? json['punctualityScore'],
      ),
      teamworkScore: _readDouble(
        json['teamwork_score'] ?? json['teamworkScore'],
      ),
      ratingCount: _readInt(json['rating_count'] ?? json['ratingCount']),
      ratingTotal: _readDouble(json['rating_total'] ?? json['ratingTotal']),
      reliabilityScore: _readDouble(
        json['reliability_score'] ?? json['reliabilityScore'],
      ),
      verificationStatus: _readString(
        json['verification_status'] ?? json['verificationStatus'],
      ),
      verifiedBy: _readOptionalString(
        json['verified_by'] ?? json['verifiedBy'],
      ),
      verificationMedia: _readList(
        json['verification_media'] ?? json['verificationMedia'],
      ),
      verificationNote: _readString(
        json['verification_note'] ?? json['verificationNote'],
      ),
      verificationDate: _readDate(
        json['verification_date'] ?? json['verificationDate'],
      ),
      performanceHighlights: _readList(
        json['performance_highlights'] ?? json['performanceHighlights'],
      ),
      mlLastVector: _readList(json['ml_last_vector'] ?? json['mlLastVector']),
      mlAvgVector: _readList(json['ml_avg_vector'] ?? json['mlAvgVector']),
      mlVectorCount: _readInt(json['ml_vector_count'] ?? json['mlVectorCount']),
      heatmapJson: _readMap(json['heatmap_json'] ?? json['heatmapJson']),
      movementIntensity: _readDouble(
        json['movement_intensity'] ?? json['movementIntensity'],
      ),
      staminaScore: _readDouble(json['stamina_score'] ?? json['staminaScore']),
      preferredVenues: _readList(
        json['preferred_venues'] ?? json['preferredVenues'],
      ),
      performanceByVenue: _readMap(
        json['performance_by_venue'] ?? json['performanceByVenue'],
      ),
      tierId: _readOptionalString(json['tier_id'] ?? json['tierId']),
    );
  }

  final String profileId;
  final String sportKey;
  final Map<String, dynamic> attributes;
  final double overallLevel;
  final double xpTotal;
  final double xpLevel;
  final double xpNextLevel;
  final int matchesPlayed;
  final String primaryPosition;
  final List<dynamic> secondaryPositions;
  final String playstyle;
  final double formScore;
  final String formTrend;
  final List<dynamic> last5Matches;
  final double attendanceRate;
  final double cancellationRate;
  final double punctualityScore;
  final double teamworkScore;
  final int ratingCount;
  final double ratingTotal;
  final double reliabilityScore;
  final String verificationStatus;
  final String? verifiedBy;
  final List<dynamic> verificationMedia;
  final String verificationNote;
  final DateTime? verificationDate;
  final List<dynamic> performanceHighlights;
  final List<dynamic> mlLastVector;
  final List<dynamic> mlAvgVector;
  final int mlVectorCount;
  final Map<String, dynamic> heatmapJson;
  final double movementIntensity;
  final double staminaScore;
  final List<dynamic> preferredVenues;
  final Map<String, dynamic> performanceByVenue;
  final String? tierId;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'profile_id': profileId,
      'sport': sportKey,
      'attributes': attributes,
      'overall_level': overallLevel,
      'xp_total': xpTotal,
      'xp_level': xpLevel,
      'xp_next_level': xpNextLevel,
      'matches_played': matchesPlayed,
      'primary_position': primaryPosition,
      'secondary_positions': secondaryPositions,
      'playstyle': playstyle,
      'form_score': formScore,
      'form_trend': formTrend,
      'last5_matches': last5Matches,
      'attendance_rate': attendanceRate,
      'cancellation_rate': cancellationRate,
      'punctuality_score': punctualityScore,
      'teamwork_score': teamworkScore,
      'rating_count': ratingCount,
      'rating_total': ratingTotal,
      'reliability_score': reliabilityScore,
      'verification_status': verificationStatus,
      'verified_by': verifiedBy,
      'verification_media': verificationMedia,
      'verification_note': verificationNote,
      'verification_date': verificationDate?.toIso8601String(),
      'performance_highlights': performanceHighlights,
      'ml_last_vector': mlLastVector,
      'ml_avg_vector': mlAvgVector,
      'ml_vector_count': mlVectorCount,
      'heatmap_json': heatmapJson,
      'movement_intensity': movementIntensity,
      'stamina_score': staminaScore,
      'preferred_venues': preferredVenues,
      'performance_by_venue': performanceByVenue,
      'tier_id': tierId,
    };
  }
}

double _readDouble(dynamic value) {
  if (value == null) {
    return 0.0;
  }
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value) ?? 0.0;
  }
  return 0.0;
}

int _readInt(dynamic value) {
  if (value == null) {
    return 0;
  }
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value) ?? 0;
  }
  return 0;
}

String _readString(dynamic value) {
  if (value == null) {
    return '';
  }
  return value.toString();
}

String? _readOptionalString(dynamic value) {
  if (value == null) {
    return null;
  }
  final stringValue = value.toString();
  return stringValue.isEmpty ? null : stringValue;
}

DateTime? _readDate(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is DateTime) {
    return value;
  }
  if (value is String) {
    return DateTime.tryParse(value);
  }
  return null;
}

Map<String, dynamic> _readMap(dynamic value) {
  if (value == null) {
    return <String, dynamic>{};
  }
  if (value is Map<String, dynamic>) {
    return Map<String, dynamic>.from(value);
  }
  if (value is Map) {
    return value.map(
      (dynamic key, dynamic value) => MapEntry(key.toString(), value),
    );
  }
  return <String, dynamic>{};
}

List<dynamic> _readList(dynamic value) {
  if (value == null) {
    return const <dynamic>[];
  }
  if (value is List<dynamic>) {
    return List<dynamic>.from(value);
  }
  if (value is List) {
    return value.map((dynamic e) => e).toList();
  }
  return const <dynamic>[];
}
