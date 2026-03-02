// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'onboarding_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$OnboardingData {
  // Basic info
  int? get age => throw _privateConstructorUsedError;
  String? get gender => throw _privateConstructorUsedError; // 'male' | 'female'
  // Persona
  String? get personaType =>
      throw _privateConstructorUsedError; // 'player' | 'organiser' | 'host'
  // Profile info
  String? get displayName => throw _privateConstructorUsedError;
  String? get username => throw _privateConstructorUsedError;
  String? get city => throw _privateConstructorUsedError;
  String? get country => throw _privateConstructorUsedError;
  String? get language =>
      throw _privateConstructorUsedError; // Sports (all UUIDs from sports.id)
  String? get preferredSport =>
      throw _privateConstructorUsedError; // UUID from sports.id (= primary_sport)
  List<String>? get interestIds =>
      throw _privateConstructorUsedError; // List of sport UUIDs
  String? get primarySportId =>
      throw _privateConstructorUsedError; // UUID from sports.id
  // DB state
  String? get profileId =>
      throw _privateConstructorUsedError; // Set after profile creation
  bool? get personaExtensionCreated => throw _privateConstructorUsedError;
  bool? get sportProfileCreated => throw _privateConstructorUsedError;

  /// Create a copy of OnboardingData
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $OnboardingDataCopyWith<OnboardingData> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $OnboardingDataCopyWith<$Res> {
  factory $OnboardingDataCopyWith(
    OnboardingData value,
    $Res Function(OnboardingData) then,
  ) = _$OnboardingDataCopyWithImpl<$Res, OnboardingData>;
  @useResult
  $Res call({
    int? age,
    String? gender,
    String? personaType,
    String? displayName,
    String? username,
    String? city,
    String? country,
    String? language,
    String? preferredSport,
    List<String>? interestIds,
    String? primarySportId,
    String? profileId,
    bool? personaExtensionCreated,
    bool? sportProfileCreated,
  });
}

/// @nodoc
class _$OnboardingDataCopyWithImpl<$Res, $Val extends OnboardingData>
    implements $OnboardingDataCopyWith<$Res> {
  _$OnboardingDataCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of OnboardingData
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? age = freezed,
    Object? gender = freezed,
    Object? personaType = freezed,
    Object? displayName = freezed,
    Object? username = freezed,
    Object? city = freezed,
    Object? country = freezed,
    Object? language = freezed,
    Object? preferredSport = freezed,
    Object? interestIds = freezed,
    Object? primarySportId = freezed,
    Object? profileId = freezed,
    Object? personaExtensionCreated = freezed,
    Object? sportProfileCreated = freezed,
  }) {
    return _then(
      _value.copyWith(
            age: freezed == age
                ? _value.age
                : age // ignore: cast_nullable_to_non_nullable
                      as int?,
            gender: freezed == gender
                ? _value.gender
                : gender // ignore: cast_nullable_to_non_nullable
                      as String?,
            personaType: freezed == personaType
                ? _value.personaType
                : personaType // ignore: cast_nullable_to_non_nullable
                      as String?,
            displayName: freezed == displayName
                ? _value.displayName
                : displayName // ignore: cast_nullable_to_non_nullable
                      as String?,
            username: freezed == username
                ? _value.username
                : username // ignore: cast_nullable_to_non_nullable
                      as String?,
            city: freezed == city
                ? _value.city
                : city // ignore: cast_nullable_to_non_nullable
                      as String?,
            country: freezed == country
                ? _value.country
                : country // ignore: cast_nullable_to_non_nullable
                      as String?,
            language: freezed == language
                ? _value.language
                : language // ignore: cast_nullable_to_non_nullable
                      as String?,
            preferredSport: freezed == preferredSport
                ? _value.preferredSport
                : preferredSport // ignore: cast_nullable_to_non_nullable
                      as String?,
            interestIds: freezed == interestIds
                ? _value.interestIds
                : interestIds // ignore: cast_nullable_to_non_nullable
                      as List<String>?,
            primarySportId: freezed == primarySportId
                ? _value.primarySportId
                : primarySportId // ignore: cast_nullable_to_non_nullable
                      as String?,
            profileId: freezed == profileId
                ? _value.profileId
                : profileId // ignore: cast_nullable_to_non_nullable
                      as String?,
            personaExtensionCreated: freezed == personaExtensionCreated
                ? _value.personaExtensionCreated
                : personaExtensionCreated // ignore: cast_nullable_to_non_nullable
                      as bool?,
            sportProfileCreated: freezed == sportProfileCreated
                ? _value.sportProfileCreated
                : sportProfileCreated // ignore: cast_nullable_to_non_nullable
                      as bool?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$OnboardingDataImplCopyWith<$Res>
    implements $OnboardingDataCopyWith<$Res> {
  factory _$$OnboardingDataImplCopyWith(
    _$OnboardingDataImpl value,
    $Res Function(_$OnboardingDataImpl) then,
  ) = __$$OnboardingDataImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    int? age,
    String? gender,
    String? personaType,
    String? displayName,
    String? username,
    String? city,
    String? country,
    String? language,
    String? preferredSport,
    List<String>? interestIds,
    String? primarySportId,
    String? profileId,
    bool? personaExtensionCreated,
    bool? sportProfileCreated,
  });
}

/// @nodoc
class __$$OnboardingDataImplCopyWithImpl<$Res>
    extends _$OnboardingDataCopyWithImpl<$Res, _$OnboardingDataImpl>
    implements _$$OnboardingDataImplCopyWith<$Res> {
  __$$OnboardingDataImplCopyWithImpl(
    _$OnboardingDataImpl _value,
    $Res Function(_$OnboardingDataImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of OnboardingData
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? age = freezed,
    Object? gender = freezed,
    Object? personaType = freezed,
    Object? displayName = freezed,
    Object? username = freezed,
    Object? city = freezed,
    Object? country = freezed,
    Object? language = freezed,
    Object? preferredSport = freezed,
    Object? interestIds = freezed,
    Object? primarySportId = freezed,
    Object? profileId = freezed,
    Object? personaExtensionCreated = freezed,
    Object? sportProfileCreated = freezed,
  }) {
    return _then(
      _$OnboardingDataImpl(
        age: freezed == age
            ? _value.age
            : age // ignore: cast_nullable_to_non_nullable
                  as int?,
        gender: freezed == gender
            ? _value.gender
            : gender // ignore: cast_nullable_to_non_nullable
                  as String?,
        personaType: freezed == personaType
            ? _value.personaType
            : personaType // ignore: cast_nullable_to_non_nullable
                  as String?,
        displayName: freezed == displayName
            ? _value.displayName
            : displayName // ignore: cast_nullable_to_non_nullable
                  as String?,
        username: freezed == username
            ? _value.username
            : username // ignore: cast_nullable_to_non_nullable
                  as String?,
        city: freezed == city
            ? _value.city
            : city // ignore: cast_nullable_to_non_nullable
                  as String?,
        country: freezed == country
            ? _value.country
            : country // ignore: cast_nullable_to_non_nullable
                  as String?,
        language: freezed == language
            ? _value.language
            : language // ignore: cast_nullable_to_non_nullable
                  as String?,
        preferredSport: freezed == preferredSport
            ? _value.preferredSport
            : preferredSport // ignore: cast_nullable_to_non_nullable
                  as String?,
        interestIds: freezed == interestIds
            ? _value._interestIds
            : interestIds // ignore: cast_nullable_to_non_nullable
                  as List<String>?,
        primarySportId: freezed == primarySportId
            ? _value.primarySportId
            : primarySportId // ignore: cast_nullable_to_non_nullable
                  as String?,
        profileId: freezed == profileId
            ? _value.profileId
            : profileId // ignore: cast_nullable_to_non_nullable
                  as String?,
        personaExtensionCreated: freezed == personaExtensionCreated
            ? _value.personaExtensionCreated
            : personaExtensionCreated // ignore: cast_nullable_to_non_nullable
                  as bool?,
        sportProfileCreated: freezed == sportProfileCreated
            ? _value.sportProfileCreated
            : sportProfileCreated // ignore: cast_nullable_to_non_nullable
                  as bool?,
      ),
    );
  }
}

/// @nodoc

class _$OnboardingDataImpl extends _OnboardingData {
  const _$OnboardingDataImpl({
    this.age,
    this.gender,
    this.personaType,
    this.displayName,
    this.username,
    this.city,
    this.country,
    this.language,
    this.preferredSport,
    final List<String>? interestIds,
    this.primarySportId,
    this.profileId,
    this.personaExtensionCreated,
    this.sportProfileCreated,
  }) : _interestIds = interestIds,
       super._();

  // Basic info
  @override
  final int? age;
  @override
  final String? gender;
  // 'male' | 'female'
  // Persona
  @override
  final String? personaType;
  // 'player' | 'organiser' | 'host'
  // Profile info
  @override
  final String? displayName;
  @override
  final String? username;
  @override
  final String? city;
  @override
  final String? country;
  @override
  final String? language;
  // Sports (all UUIDs from sports.id)
  @override
  final String? preferredSport;
  // UUID from sports.id (= primary_sport)
  final List<String>? _interestIds;
  // UUID from sports.id (= primary_sport)
  @override
  List<String>? get interestIds {
    final value = _interestIds;
    if (value == null) return null;
    if (_interestIds is EqualUnmodifiableListView) return _interestIds;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  // List of sport UUIDs
  @override
  final String? primarySportId;
  // UUID from sports.id
  // DB state
  @override
  final String? profileId;
  // Set after profile creation
  @override
  final bool? personaExtensionCreated;
  @override
  final bool? sportProfileCreated;

  @override
  String toString() {
    return 'OnboardingData(age: $age, gender: $gender, personaType: $personaType, displayName: $displayName, username: $username, city: $city, country: $country, language: $language, preferredSport: $preferredSport, interestIds: $interestIds, primarySportId: $primarySportId, profileId: $profileId, personaExtensionCreated: $personaExtensionCreated, sportProfileCreated: $sportProfileCreated)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$OnboardingDataImpl &&
            (identical(other.age, age) || other.age == age) &&
            (identical(other.gender, gender) || other.gender == gender) &&
            (identical(other.personaType, personaType) ||
                other.personaType == personaType) &&
            (identical(other.displayName, displayName) ||
                other.displayName == displayName) &&
            (identical(other.username, username) ||
                other.username == username) &&
            (identical(other.city, city) || other.city == city) &&
            (identical(other.country, country) || other.country == country) &&
            (identical(other.language, language) ||
                other.language == language) &&
            (identical(other.preferredSport, preferredSport) ||
                other.preferredSport == preferredSport) &&
            const DeepCollectionEquality().equals(
              other._interestIds,
              _interestIds,
            ) &&
            (identical(other.primarySportId, primarySportId) ||
                other.primarySportId == primarySportId) &&
            (identical(other.profileId, profileId) ||
                other.profileId == profileId) &&
            (identical(
                  other.personaExtensionCreated,
                  personaExtensionCreated,
                ) ||
                other.personaExtensionCreated == personaExtensionCreated) &&
            (identical(other.sportProfileCreated, sportProfileCreated) ||
                other.sportProfileCreated == sportProfileCreated));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    age,
    gender,
    personaType,
    displayName,
    username,
    city,
    country,
    language,
    preferredSport,
    const DeepCollectionEquality().hash(_interestIds),
    primarySportId,
    profileId,
    personaExtensionCreated,
    sportProfileCreated,
  );

  /// Create a copy of OnboardingData
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$OnboardingDataImplCopyWith<_$OnboardingDataImpl> get copyWith =>
      __$$OnboardingDataImplCopyWithImpl<_$OnboardingDataImpl>(
        this,
        _$identity,
      );
}

abstract class _OnboardingData extends OnboardingData {
  const factory _OnboardingData({
    final int? age,
    final String? gender,
    final String? personaType,
    final String? displayName,
    final String? username,
    final String? city,
    final String? country,
    final String? language,
    final String? preferredSport,
    final List<String>? interestIds,
    final String? primarySportId,
    final String? profileId,
    final bool? personaExtensionCreated,
    final bool? sportProfileCreated,
  }) = _$OnboardingDataImpl;
  const _OnboardingData._() : super._();

  // Basic info
  @override
  int? get age;
  @override
  String? get gender; // 'male' | 'female'
  // Persona
  @override
  String? get personaType; // 'player' | 'organiser' | 'host'
  // Profile info
  @override
  String? get displayName;
  @override
  String? get username;
  @override
  String? get city;
  @override
  String? get country;
  @override
  String? get language; // Sports (all UUIDs from sports.id)
  @override
  String? get preferredSport; // UUID from sports.id (= primary_sport)
  @override
  List<String>? get interestIds; // List of sport UUIDs
  @override
  String? get primarySportId; // UUID from sports.id
  // DB state
  @override
  String? get profileId; // Set after profile creation
  @override
  bool? get personaExtensionCreated;
  @override
  bool? get sportProfileCreated;

  /// Create a copy of OnboardingData
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$OnboardingDataImplCopyWith<_$OnboardingDataImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$OnboardingState {
  OnboardingStep get step => throw _privateConstructorUsedError;
  OnboardingData get data => throw _privateConstructorUsedError;
  bool get isLoading => throw _privateConstructorUsedError;
  String? get error => throw _privateConstructorUsedError; // Resume info
  int? get existingProfileCount => throw _privateConstructorUsedError;
  bool? get hasIncompleteOnboarding => throw _privateConstructorUsedError;

  /// Create a copy of OnboardingState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $OnboardingStateCopyWith<OnboardingState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $OnboardingStateCopyWith<$Res> {
  factory $OnboardingStateCopyWith(
    OnboardingState value,
    $Res Function(OnboardingState) then,
  ) = _$OnboardingStateCopyWithImpl<$Res, OnboardingState>;
  @useResult
  $Res call({
    OnboardingStep step,
    OnboardingData data,
    bool isLoading,
    String? error,
    int? existingProfileCount,
    bool? hasIncompleteOnboarding,
  });

  $OnboardingDataCopyWith<$Res> get data;
}

/// @nodoc
class _$OnboardingStateCopyWithImpl<$Res, $Val extends OnboardingState>
    implements $OnboardingStateCopyWith<$Res> {
  _$OnboardingStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of OnboardingState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? step = null,
    Object? data = null,
    Object? isLoading = null,
    Object? error = freezed,
    Object? existingProfileCount = freezed,
    Object? hasIncompleteOnboarding = freezed,
  }) {
    return _then(
      _value.copyWith(
            step: null == step
                ? _value.step
                : step // ignore: cast_nullable_to_non_nullable
                      as OnboardingStep,
            data: null == data
                ? _value.data
                : data // ignore: cast_nullable_to_non_nullable
                      as OnboardingData,
            isLoading: null == isLoading
                ? _value.isLoading
                : isLoading // ignore: cast_nullable_to_non_nullable
                      as bool,
            error: freezed == error
                ? _value.error
                : error // ignore: cast_nullable_to_non_nullable
                      as String?,
            existingProfileCount: freezed == existingProfileCount
                ? _value.existingProfileCount
                : existingProfileCount // ignore: cast_nullable_to_non_nullable
                      as int?,
            hasIncompleteOnboarding: freezed == hasIncompleteOnboarding
                ? _value.hasIncompleteOnboarding
                : hasIncompleteOnboarding // ignore: cast_nullable_to_non_nullable
                      as bool?,
          )
          as $Val,
    );
  }

  /// Create a copy of OnboardingState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $OnboardingDataCopyWith<$Res> get data {
    return $OnboardingDataCopyWith<$Res>(_value.data, (value) {
      return _then(_value.copyWith(data: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$OnboardingStateImplCopyWith<$Res>
    implements $OnboardingStateCopyWith<$Res> {
  factory _$$OnboardingStateImplCopyWith(
    _$OnboardingStateImpl value,
    $Res Function(_$OnboardingStateImpl) then,
  ) = __$$OnboardingStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    OnboardingStep step,
    OnboardingData data,
    bool isLoading,
    String? error,
    int? existingProfileCount,
    bool? hasIncompleteOnboarding,
  });

  @override
  $OnboardingDataCopyWith<$Res> get data;
}

/// @nodoc
class __$$OnboardingStateImplCopyWithImpl<$Res>
    extends _$OnboardingStateCopyWithImpl<$Res, _$OnboardingStateImpl>
    implements _$$OnboardingStateImplCopyWith<$Res> {
  __$$OnboardingStateImplCopyWithImpl(
    _$OnboardingStateImpl _value,
    $Res Function(_$OnboardingStateImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of OnboardingState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? step = null,
    Object? data = null,
    Object? isLoading = null,
    Object? error = freezed,
    Object? existingProfileCount = freezed,
    Object? hasIncompleteOnboarding = freezed,
  }) {
    return _then(
      _$OnboardingStateImpl(
        step: null == step
            ? _value.step
            : step // ignore: cast_nullable_to_non_nullable
                  as OnboardingStep,
        data: null == data
            ? _value.data
            : data // ignore: cast_nullable_to_non_nullable
                  as OnboardingData,
        isLoading: null == isLoading
            ? _value.isLoading
            : isLoading // ignore: cast_nullable_to_non_nullable
                  as bool,
        error: freezed == error
            ? _value.error
            : error // ignore: cast_nullable_to_non_nullable
                  as String?,
        existingProfileCount: freezed == existingProfileCount
            ? _value.existingProfileCount
            : existingProfileCount // ignore: cast_nullable_to_non_nullable
                  as int?,
        hasIncompleteOnboarding: freezed == hasIncompleteOnboarding
            ? _value.hasIncompleteOnboarding
            : hasIncompleteOnboarding // ignore: cast_nullable_to_non_nullable
                  as bool?,
      ),
    );
  }
}

/// @nodoc

class _$OnboardingStateImpl extends _OnboardingState {
  const _$OnboardingStateImpl({
    this.step = OnboardingStep.checking,
    this.data = const OnboardingData(),
    this.isLoading = false,
    this.error,
    this.existingProfileCount,
    this.hasIncompleteOnboarding,
  }) : super._();

  @override
  @JsonKey()
  final OnboardingStep step;
  @override
  @JsonKey()
  final OnboardingData data;
  @override
  @JsonKey()
  final bool isLoading;
  @override
  final String? error;
  // Resume info
  @override
  final int? existingProfileCount;
  @override
  final bool? hasIncompleteOnboarding;

  @override
  String toString() {
    return 'OnboardingState(step: $step, data: $data, isLoading: $isLoading, error: $error, existingProfileCount: $existingProfileCount, hasIncompleteOnboarding: $hasIncompleteOnboarding)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$OnboardingStateImpl &&
            (identical(other.step, step) || other.step == step) &&
            (identical(other.data, data) || other.data == data) &&
            (identical(other.isLoading, isLoading) ||
                other.isLoading == isLoading) &&
            (identical(other.error, error) || other.error == error) &&
            (identical(other.existingProfileCount, existingProfileCount) ||
                other.existingProfileCount == existingProfileCount) &&
            (identical(
                  other.hasIncompleteOnboarding,
                  hasIncompleteOnboarding,
                ) ||
                other.hasIncompleteOnboarding == hasIncompleteOnboarding));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    step,
    data,
    isLoading,
    error,
    existingProfileCount,
    hasIncompleteOnboarding,
  );

  /// Create a copy of OnboardingState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$OnboardingStateImplCopyWith<_$OnboardingStateImpl> get copyWith =>
      __$$OnboardingStateImplCopyWithImpl<_$OnboardingStateImpl>(
        this,
        _$identity,
      );
}

abstract class _OnboardingState extends OnboardingState {
  const factory _OnboardingState({
    final OnboardingStep step,
    final OnboardingData data,
    final bool isLoading,
    final String? error,
    final int? existingProfileCount,
    final bool? hasIncompleteOnboarding,
  }) = _$OnboardingStateImpl;
  const _OnboardingState._() : super._();

  @override
  OnboardingStep get step;
  @override
  OnboardingData get data;
  @override
  bool get isLoading;
  @override
  String? get error; // Resume info
  @override
  int? get existingProfileCount;
  @override
  bool? get hasIncompleteOnboarding;

  /// Create a copy of OnboardingState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$OnboardingStateImplCopyWith<_$OnboardingStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
