import 'package:dabbler/core/utils/json.dart';

enum VenueSubmissionStatus { draft, pending, approved, returned, rejected }

extension VenueSubmissionStatusX on VenueSubmissionStatus {
  String get dbValue => name;

  static VenueSubmissionStatus fromDb(Object? value) {
    final raw = asString(value).trim().toLowerCase();
    switch (raw) {
      case 'draft':
        return VenueSubmissionStatus.draft;
      case 'pending':
        return VenueSubmissionStatus.pending;
      case 'approved':
        return VenueSubmissionStatus.approved;
      case 'returned':
        return VenueSubmissionStatus.returned;
      case 'rejected':
        return VenueSubmissionStatus.rejected;
      default:
        return VenueSubmissionStatus.draft;
    }
  }

  bool get isEditable =>
      this == VenueSubmissionStatus.draft || this == VenueSubmissionStatus.returned;

  bool get canSubmitForReview => isEditable;

  bool get shouldShowAdminNote =>
      this == VenueSubmissionStatus.returned || this == VenueSubmissionStatus.rejected;
}

/// User-editable fields for creating or updating a submission draft.
///
/// Note: Admin fields (status/admin_note) are intentionally excluded.
class VenueSubmissionDraft {
  final String? id;
  final String? nameEn;
  final String? nameAr;
  final String? descriptionEn;
  final String? descriptionAr;
  final String? city;
  final String? district;
  final String? area;
  final String? addressLine1;
  final double? lat;
  final double? lng;
  final String? phone;
  final String? website;
  final String? instagram;
  final bool? isIndoor;
  final String? surfaceType;
  final List<String> amenities;

  const VenueSubmissionDraft({
    this.id,
    this.nameEn,
    this.nameAr,
    this.descriptionEn,
    this.descriptionAr,
    this.city,
    this.district,
    this.area,
    this.addressLine1,
    this.lat,
    this.lng,
    this.phone,
    this.website,
    this.instagram,
    this.isIndoor,
    this.surfaceType,
    this.amenities = const <String>[],
  });

  VenueSubmissionDraft copyWith({
    String? id,
    String? nameEn,
    String? nameAr,
    String? descriptionEn,
    String? descriptionAr,
    String? city,
    String? district,
    String? area,
    String? addressLine1,
    double? lat,
    double? lng,
    String? phone,
    String? website,
    String? instagram,
    bool? isIndoor,
    String? surfaceType,
    List<String>? amenities,
  }) {
    return VenueSubmissionDraft(
      id: id ?? this.id,
      nameEn: nameEn ?? this.nameEn,
      nameAr: nameAr ?? this.nameAr,
      descriptionEn: descriptionEn ?? this.descriptionEn,
      descriptionAr: descriptionAr ?? this.descriptionAr,
      city: city ?? this.city,
      district: district ?? this.district,
      area: area ?? this.area,
      addressLine1: addressLine1 ?? this.addressLine1,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      phone: phone ?? this.phone,
      website: website ?? this.website,
      instagram: instagram ?? this.instagram,
      isIndoor: isIndoor ?? this.isIndoor,
      surfaceType: surfaceType ?? this.surfaceType,
      amenities: amenities ?? this.amenities,
    );
  }

  Map<String, dynamic> toColumnsMap({bool includeNulls = false}) {
    String? normalizeText(String? v) {
      final s = (v ?? '').trim();
      return s.isEmpty ? null : s;
    }

    final map = <String, dynamic>{
      'name_en': normalizeText(nameEn),
      'name_ar': normalizeText(nameAr),
      'description_en': normalizeText(descriptionEn),
      'description_ar': normalizeText(descriptionAr),
      'city': normalizeText(city),
      'district': normalizeText(district),
      'area': normalizeText(area),
      'address_line1': normalizeText(addressLine1),
      'lat': lat,
      'lng': lng,
      'phone': normalizeText(phone),
      'website': normalizeText(website),
      'instagram': normalizeText(instagram),
      'is_indoor': isIndoor,
      'surface_type': normalizeText(surfaceType),
      'amenities': amenities,
    };

    if (includeNulls) {
      return map;
    }

    map.removeWhere((_, value) => value == null);
    return map;
  }
}

class VenueSubmissionModel {
  final String id;
  final String organiserProfileId;
  final String submittedByUserId;

  final String? nameEn;
  final String? nameAr;
  final String? descriptionEn;
  final String? descriptionAr;
  final String? city;
  final String? district;
  final String? area;
  final String? addressLine1;
  final double? lat;
  final double? lng;
  final String? phone;
  final String? website;
  final String? instagram;
  final bool? isIndoor;
  final String? surfaceType;
  final List<String> amenities;

  final VenueSubmissionStatus status;
  final String? adminNote;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  const VenueSubmissionModel({
    required this.id,
    required this.organiserProfileId,
    required this.submittedByUserId,
    required this.status,
    this.nameEn,
    this.nameAr,
    this.descriptionEn,
    this.descriptionAr,
    this.city,
    this.district,
    this.area,
    this.addressLine1,
    this.lat,
    this.lng,
    this.phone,
    this.website,
    this.instagram,
    this.isIndoor,
    this.surfaceType,
    this.amenities = const <String>[],
    this.adminNote,
    this.createdAt,
    this.updatedAt,
  });

  bool get isEditable => status.isEditable;
  bool get canSubmitForReview => status.canSubmitForReview;
  bool get shouldShowAdminNote => status.shouldShowAdminNote;

  VenueSubmissionDraft toDraft() {
    return VenueSubmissionDraft(
      id: id,
      nameEn: nameEn,
      nameAr: nameAr,
      descriptionEn: descriptionEn,
      descriptionAr: descriptionAr,
      city: city,
      district: district,
      area: area,
      addressLine1: addressLine1,
      lat: lat,
      lng: lng,
      phone: phone,
      website: website,
      instagram: instagram,
      isIndoor: isIndoor,
      surfaceType: surfaceType,
      amenities: amenities,
    );
  }

  factory VenueSubmissionModel.fromMap(Map<String, dynamic> row) {
    final m = asMap(row);

    final amenitiesValue = m['amenities'];
    final amenities = <String>[];
    if (amenitiesValue is Iterable) {
      for (final item in amenitiesValue) {
        final s = asString(item).trim();
        if (s.isNotEmpty) amenities.add(s);
      }
    }

    String? nullableTrimmed(Object? v) {
      final s = asString(v).trim();
      return s.isEmpty ? null : s;
    }

    return VenueSubmissionModel(
      id: asString(m['id']),
      organiserProfileId: asString(m['organiser_profile_id']),
      submittedByUserId: asString(m['submitted_by_user_id']),
      nameEn: nullableTrimmed(m['name_en']),
      nameAr: nullableTrimmed(m['name_ar']),
      descriptionEn: nullableTrimmed(m['description_en']),
      descriptionAr: nullableTrimmed(m['description_ar']),
      city: nullableTrimmed(m['city']),
      district: nullableTrimmed(m['district']),
      area: nullableTrimmed(m['area']),
      addressLine1: nullableTrimmed(m['address_line1']),
      lat: asDouble(m['lat']),
      lng: asDouble(m['lng']),
      phone: nullableTrimmed(m['phone']),
      website: nullableTrimmed(m['website']),
      instagram: nullableTrimmed(m['instagram']),
      isIndoor: asBool(m['is_indoor']),
      surfaceType: nullableTrimmed(m['surface_type']),
      amenities: amenities,
      status: VenueSubmissionStatusX.fromDb(m['status']),
      adminNote: nullableTrimmed(m['admin_note']),
      createdAt: asDateTime(m['created_at']),
      updatedAt: asDateTime(m['updated_at']),
    );
  }
}
