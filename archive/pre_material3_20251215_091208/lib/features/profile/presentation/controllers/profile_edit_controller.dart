import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dabbler/data/models/profile/user_profile.dart';
import '../../domain/usecases/update_profile_usecase.dart';
import '../../domain/usecases/upload_avatar_usecase.dart';
import 'package:dabbler/core/fp/failure.dart';

/// State for profile editing form
class ProfileEditState {
  final bool isLoading;
  final bool isSaving;
  final bool hasChanges;
  final String? errorMessage;
  final Map<String, String?> fieldErrors;
  final Map<String, dynamic> formData;
  final double avatarUploadProgress;
  final bool isUploadingAvatar;
  final String? avatarUploadError;

  const ProfileEditState({
    this.isLoading = false,
    this.isSaving = false,
    this.hasChanges = false,
    this.errorMessage,
    this.fieldErrors = const {},
    this.formData = const {},
    this.avatarUploadProgress = 0.0,
    this.isUploadingAvatar = false,
    this.avatarUploadError,
  });

  ProfileEditState copyWith({
    bool? isLoading,
    bool? isSaving,
    bool? hasChanges,
    String? errorMessage,
    Map<String, String?>? fieldErrors,
    Map<String, dynamic>? formData,
    double? avatarUploadProgress,
    bool? isUploadingAvatar,
    String? avatarUploadError,
  }) {
    return ProfileEditState(
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      hasChanges: hasChanges ?? this.hasChanges,
      errorMessage: errorMessage,
      fieldErrors: fieldErrors ?? this.fieldErrors,
      formData: formData ?? this.formData,
      avatarUploadProgress: avatarUploadProgress ?? this.avatarUploadProgress,
      isUploadingAvatar: isUploadingAvatar ?? this.isUploadingAvatar,
      avatarUploadError: avatarUploadError,
    );
  }
}

/// Controller for profile editing form with real-time validation
class ProfileEditController extends StateNotifier<ProfileEditState> {
  final UpdateProfileUseCase? _updateProfileUseCase;
  final UploadAvatarUseCase? _uploadAvatarUseCase;

  UserProfile? _originalProfile;
  final Map<String, TextEditingController> _textControllers = {};
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  ProfileEditController({
    UpdateProfileUseCase? updateProfileUseCase,
    UploadAvatarUseCase? uploadAvatarUseCase,
  }) : _updateProfileUseCase = updateProfileUseCase,
       _uploadAvatarUseCase = uploadAvatarUseCase,
       super(const ProfileEditState());

  /// Form key for validation
  GlobalKey<FormState> get formKey => _formKey;

  /// Initialize the form with existing profile data
  void initialize(UserProfile? profile) {
    _originalProfile = profile;

    if (profile != null) {
      final formData = {
        'username': profile.username ?? '',
        'display_name': profile.displayName,
        'bio': profile.bio ?? '',
        'email': profile.email,
        'phone_number': profile.phoneNumber ?? '',
        'city': profile.city ?? '',
        'country': profile.country ?? '',
        'gender': profile.gender ?? '',
        'age': profile.age,
      };

      state = state.copyWith(
        formData: formData,
        hasChanges: false,
        errorMessage: null,
        fieldErrors: {},
      );

      _initializeTextControllers(formData);
    }
  }

  /// Initialize text controllers with current values
  void _initializeTextControllers(Map<String, dynamic> formData) {
    _disposeControllers();

    final fields = [
      'display_name',
      'username',
      'display_name',
      'bio',
      'email',
      'phone_number',
      'location',
      'gender',
    ];

    for (final field in fields) {
      final value = formData[field]?.toString() ?? '';
      _textControllers[field] = TextEditingController(text: value);

      // Add listeners for real-time validation
      _textControllers[field]?.addListener(
        () => _onFieldChanged(field, _textControllers[field]!.text),
      );
    }
  }

  /// Get text controller for a specific field
  TextEditingController? getController(String field) => _textControllers[field];

  /// Handle field value changes with real-time validation
  void _onFieldChanged(String field, String value) {
    final updatedFormData = Map<String, dynamic>.from(state.formData);
    updatedFormData[field] = value;

    // Clear field error when user starts typing
    final updatedFieldErrors = Map<String, String?>.from(state.fieldErrors);
    if (updatedFieldErrors.containsKey(field)) {
      updatedFieldErrors.remove(field);
    }

    // Validate field in real-time
    final fieldError = _validateField(field, value);
    if (fieldError != null) {
      updatedFieldErrors[field] = fieldError;
    }

    final hasChanges = _hasFormChanges(updatedFormData);

    state = state.copyWith(
      formData: updatedFormData,
      fieldErrors: updatedFieldErrors,
      hasChanges: hasChanges,
      errorMessage: null,
    );
  }

  /// Update a specific field programmatically
  void updateField(String field, dynamic value) {
    final updatedFormData = Map<String, dynamic>.from(state.formData);
    updatedFormData[field] = value;

    // Update text controller if it exists
    if (_textControllers.containsKey(field) && value is String) {
      _textControllers[field]?.text = value;
    }

    final hasChanges = _hasFormChanges(updatedFormData);

    state = state.copyWith(formData: updatedFormData, hasChanges: hasChanges);
  }

  /// Update date of birth
  void updateDateOfBirth(DateTime? date) {
    updateField('age', date);
  }

  /// Upload avatar image
  Future<bool> uploadAvatar(File imageFile) async {
    if (_originalProfile == null) return false;

    state = state.copyWith(
      isUploadingAvatar: true,
      avatarUploadProgress: 0.0,
      avatarUploadError: null,
    );

    try {
      final params = UploadAvatarParams(
        userId: _originalProfile!.id,
        imageFile: imageFile,
        deleteCurrentAvatar: true,
      );

      if (_uploadAvatarUseCase == null) {
        state = state.copyWith(
          isUploadingAvatar: false,
          avatarUploadProgress: 0.0,
        );
        updateField('avatarUrl', 'mock_avatar_url');
        return true;
      }

      final result = await _uploadAvatarUseCase.call(params);

      return result.fold(
        (failure) {
          state = state.copyWith(
            isUploadingAvatar: false,
            avatarUploadError: _getFailureMessage(failure),
            avatarUploadProgress: 0.0,
          );
          return false;
        },
        (uploadResult) {
          // Update form data with new avatar URL
          updateField('avatar_url', uploadResult.avatarUrl);

          state = state.copyWith(
            isUploadingAvatar: false,
            avatarUploadProgress: 100.0,
            avatarUploadError: null,
          );

          // Show warnings if any
          if (uploadResult.warnings.isNotEmpty) {}

          return true;
        },
      );
    } catch (error) {
      state = state.copyWith(
        isUploadingAvatar: false,
        avatarUploadError: _getErrorMessage(error),
        avatarUploadProgress: 0.0,
      );
      return false;
    }
  }

  /// Save form changes
  Future<bool> saveChanges() async {
    if (_originalProfile == null || !state.hasChanges) return false;

    // Validate all fields
    final validationErrors = _validateAllFields();
    if (validationErrors.isNotEmpty) {
      state = state.copyWith(fieldErrors: validationErrors);
      return false;
    }

    state = state.copyWith(isSaving: true, errorMessage: null);

    try {
      final params = UpdateProfileParams(
        userId: _originalProfile!.id,
        displayName: state.formData['display_name']?.toString().trim(),
        username: state.formData['username']?.toString().trim(),
        bio: state.formData['bio']?.toString().trim(),
        email: state.formData['email']?.toString().trim(),
        phoneNumber: state.formData['phone_number']?.toString().trim(),
        city: state.formData['location']?.toString().trim(),
        gender: state.formData['gender']?.toString().trim(),
        age: state.formData['age'] as int?,
      );

      if (_updateProfileUseCase == null) {
        state = state.copyWith(isSaving: false);
        return true;
      }

      final result = await _updateProfileUseCase.call(params);

      return result.fold(
        (failure) {
          state = state.copyWith(
            isSaving: false,
            errorMessage: _getFailureMessage(failure),
          );
          return false;
        },
        (updateResult) {
          _originalProfile = updateResult.updatedProfile;

          state = state.copyWith(
            isSaving: false,
            hasChanges: false,
            errorMessage: null,
          );

          // Show warnings if any
          if (updateResult.warnings.isNotEmpty) {}

          return true;
        },
      );
    } catch (error) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: _getErrorMessage(error),
      );
      return false;
    }
  }

  /// Discard changes and reset to original values
  void discardChanges() {
    if (_originalProfile != null) {
      initialize(_originalProfile);
    }
  }

  /// Validate a specific field
  String? _validateField(String field, dynamic value) {
    switch (field) {
      case 'display_name':
        if (value == null || value.toString().trim().isEmpty) {
          return 'Display name is required';
        }
        if (value.toString().trim().length < 2) {
          return 'Display name must be at least 2 characters';
        }
        if (value.toString().length > 50) {
          return 'Display name cannot exceed 50 characters';
        }
        break;

      case 'email':
        if (value == null || value.toString().trim().isEmpty) {
          return 'Email is required';
        }
        final emailRegex = RegExp(r'^[\w\-.]+@([\w-]+\.)+[\w-]{2,4}$');
        if (!emailRegex.hasMatch(value.toString().trim())) {
          return 'Please enter a valid email address';
        }
        break;

      case 'phone_number':
        if (value != null && value.toString().trim().isNotEmpty) {
          final phoneRegex = RegExp(r'^\+?[1-9]\d{1,14}$');
          final cleanPhone = value.toString().replaceAll(
            RegExp(r'[\s\-()]'),
            '',
          );
          if (!phoneRegex.hasMatch(cleanPhone)) {
            return 'Please enter a valid phone number';
          }
        }
        break;

      case 'bio':
        if (value != null && value.toString().length > 500) {
          return 'Bio cannot exceed 500 characters';
        }
        break;

      case 'username':
      case 'display_name':
        if (value != null && value.toString().length > 50) {
          return '${field.replaceAll('_', ' ').titleCase} cannot exceed 50 characters';
        }
        break;

      case 'location':
        if (value != null && value.toString().length > 100) {
          return 'Location cannot exceed 100 characters';
        }
        break;

      case 'gender':
        if (value != null && value.toString().isNotEmpty) {
          const validGenders = [
            'male',
            'female',
            'non-binary',
            'prefer_not_to_say',
            'other',
          ];
          if (!validGenders.contains(value.toString().toLowerCase())) {
            return 'Please select a valid gender option';
          }
        }
        break;
    }
    return null;
  }

  /// Validate all form fields
  Map<String, String?> _validateAllFields() {
    final errors = <String, String?>{};

    for (final entry in state.formData.entries) {
      final error = _validateField(entry.key, entry.value);
      if (error != null) {
        errors[entry.key] = error;
      }
    }

    return errors;
  }

  /// Check if form has changes compared to original profile
  bool _hasFormChanges(Map<String, dynamic> formData) {
    if (_originalProfile == null) return false;

    return formData['display_name'] != _originalProfile!.displayName ||
        formData['username'] != (_originalProfile!.username ?? '') ||
        formData['bio'] != (_originalProfile!.bio ?? '') ||
        formData['email'] != _originalProfile!.email ||
        formData['phone_number'] != (_originalProfile!.phoneNumber ?? '') ||
        formData['city'] != (_originalProfile!.city ?? '') ||
        formData['country'] != (_originalProfile!.country ?? '') ||
        formData['gender'] != (_originalProfile!.gender ?? '') ||
        formData['age'] != _originalProfile!.age;
  }

  /// Get field validation status
  bool isFieldValid(String field) {
    return !state.fieldErrors.containsKey(field);
  }

  /// Get field error message
  String? getFieldError(String field) {
    return state.fieldErrors[field];
  }

  /// Check if form can be saved
  bool get canSave =>
      state.hasChanges && !state.isSaving && state.fieldErrors.isEmpty;

  /// Get form completion percentage
  double get completionPercentage {
    final totalFields = 8; // Major fields
    var completedFields = 0;

    if (state.formData['display_name']?.toString().trim().isNotEmpty == true) {
      completedFields++;
    }
    if (state.formData['email']?.toString().trim().isNotEmpty == true) {
      completedFields++;
    }
    if (state.formData['bio']?.toString().trim().isNotEmpty == true) {
      completedFields++;
    }
    if (state.formData['location']?.toString().trim().isNotEmpty == true) {
      completedFields++;
    }
    if (state.formData['username']?.toString().trim().isNotEmpty == true) {
      completedFields++;
    }
    if (state.formData['display_name']?.toString().trim().isNotEmpty == true) {
      completedFields++;
    }
    if (state.formData['phone_number']?.toString().trim().isNotEmpty == true) {
      completedFields++;
    }
    if (state.formData['age'] != null) completedFields++;

    return (completedFields / totalFields * 100).clamp(0.0, 100.0);
  }

  /// Convert error to user-friendly message
  String _getErrorMessage(dynamic error) {
    if (error is Exception) {
      return error.toString().replaceAll('Exception: ', '');
    }
    return 'An unexpected error occurred';
  }

  /// Convert failure to user-friendly message
  String _getFailureMessage(Failure failure) {
    switch (failure.runtimeType) {
      case ValidationFailure:
        return failure.message;
      case NetworkFailure:
        return 'Network error. Please check your connection.';
      case ServerFailure:
        return 'Server error. Please try again later.';
      default:
        return failure.message;
    }
  }

  /// Clean up resources
  void _disposeControllers() {
    for (final controller in _textControllers.values) {
      controller.dispose();
    }
    _textControllers.clear();
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }
}

/// Extension to add title case functionality
extension StringExtension on String {
  String get titleCase => split(' ')
      .map(
        (word) => word.isEmpty
            ? word
            : '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}',
      )
      .join(' ');
}
