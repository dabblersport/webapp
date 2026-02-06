/// Model for user search filters (placeholder, expand as needed)
library;

class SearchFilterModel {
  final List<String> sportsCategories;
  final String? location;
  final double? radius;
  final List<String> skillLevels;
  final int? minAge;
  final int? maxAge;
  final String? gender;

  const SearchFilterModel({
    this.sportsCategories = const [],
    this.location,
    this.radius,
    this.skillLevels = const [],
    this.minAge,
    this.maxAge,
    this.gender,
  });

  SearchFilterModel copyWith({
    List<String>? sportsCategories,
    String? location,
    double? radius,
    List<String>? skillLevels,
    int? minAge,
    int? maxAge,
    String? gender,
  }) {
    return SearchFilterModel(
      sportsCategories: sportsCategories ?? this.sportsCategories,
      location: location ?? this.location,
      radius: radius ?? this.radius,
      skillLevels: skillLevels ?? this.skillLevels,
      minAge: minAge ?? this.minAge,
      maxAge: maxAge ?? this.maxAge,
      gender: gender ?? this.gender,
    );
  }
}
