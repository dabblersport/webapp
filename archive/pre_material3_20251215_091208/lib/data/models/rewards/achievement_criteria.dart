/// Enum for criteria comparison operators
enum CriteriaComparator {
  equal,
  greaterThan,
  greaterThanOrEqual,
  lessThan,
  lessThanOrEqual,
}

extension CriteriaComparatorExtension on CriteriaComparator {
  String get displayName {
    switch (this) {
      case CriteriaComparator.equal:
        return 'equals';
      case CriteriaComparator.greaterThan:
        return 'greater than';
      case CriteriaComparator.greaterThanOrEqual:
        return 'greater than or equal to';
      case CriteriaComparator.lessThan:
        return 'less than';
      case CriteriaComparator.lessThanOrEqual:
        return 'less than or equal to';
    }
  }

  String get symbol {
    switch (this) {
      case CriteriaComparator.equal:
        return '=';
      case CriteriaComparator.greaterThan:
        return '>';
      case CriteriaComparator.greaterThanOrEqual:
        return '>=';
      case CriteriaComparator.lessThan:
        return '<';
      case CriteriaComparator.lessThanOrEqual:
        return '<=';
    }
  }
}

/// Class representing individual achievement criteria
class AchievementCriteria {
  final String key;
  final dynamic value;
  final CriteriaComparator comparator;
  final String description;

  const AchievementCriteria({
    required this.key,
    required this.value,
    required this.comparator,
    required this.description,
  });

  /// Check if the given value meets this criteria
  bool evaluate(dynamic testValue) {
    if (testValue == null) return false;

    switch (comparator) {
      case CriteriaComparator.equal:
        return testValue == value;
      case CriteriaComparator.greaterThan:
        return testValue > value;
      case CriteriaComparator.greaterThanOrEqual:
        return testValue >= value;
      case CriteriaComparator.lessThan:
        return testValue < value;
      case CriteriaComparator.lessThanOrEqual:
        return testValue <= value;
    }
  }

  /// Convert to map for storage
  Map<String, dynamic> toMap() {
    return {
      'key': key,
      'value': value,
      'comparator': comparator.name,
      'description': description,
    };
  }

  /// Create from map
  factory AchievementCriteria.fromMap(Map<String, dynamic> map) {
    return AchievementCriteria(
      key: map['key'] as String,
      value: map['value'],
      comparator: CriteriaComparator.values.firstWhere(
        (e) => e.name == map['comparator'],
        orElse: () => CriteriaComparator.equal,
      ),
      description: map['description'] as String,
    );
  }

  /// Copy with changes
  AchievementCriteria copyWith({
    String? key,
    dynamic value,
    CriteriaComparator? comparator,
    String? description,
  }) {
    return AchievementCriteria(
      key: key ?? this.key,
      value: value ?? this.value,
      comparator: comparator ?? this.comparator,
      description: description ?? this.description,
    );
  }

  @override
  String toString() {
    return '$key ${comparator.symbol} $value';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AchievementCriteria &&
        other.key == key &&
        other.value == value &&
        other.comparator == comparator &&
        other.description == description;
  }

  @override
  int get hashCode {
    return key.hashCode ^
        value.hashCode ^
        comparator.hashCode ^
        description.hashCode;
  }
}
