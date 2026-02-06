import 'constants.dart';

class AppValidators {
  // Phone Number Validation
  static String? validatePhoneNumber(String? value) {
    if (value == null || value.isEmpty) {
      return 'Phone number is required';
    }

    final digits = value.replaceAll(RegExp(r'[^\d]'), '');

    if (digits.length < AppConstants.minPhoneLength) {
      return 'Phone number is too short';
    }

    if (digits.length > AppConstants.maxPhoneLength) {
      return 'Phone number is too long';
    }

    // UAE phone number validation
    if (digits.startsWith('971') && digits.length == 12) {
      return null;
    }

    // Egypt phone number validation
    if (digits.startsWith('20') && digits.length == 12) {
      return null;
    }

    // US phone number validation
    if (digits.startsWith('1') && digits.length == 11) {
      return null;
    }

    // 10-digit phone number validation
    if (digits.length == 10) {
      return null;
    }

    return 'Please enter a valid phone number';
  }

  // Email Validation
  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email is required';
    }

    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) {
      return 'Please enter a valid email address';
    }

    return null;
  }

  // Name Validation
  static String? validateName(String? value) {
    if (value == null || value.isEmpty) {
      return 'Name is required';
    }

    // Trim whitespace for length validation
    final trimmedValue = value.trim();

    if (trimmedValue.length < AppConstants.minNameLength) {
      return 'Name must be at least ${AppConstants.minNameLength} characters long';
    }

    if (trimmedValue.length > AppConstants.maxNameLength) {
      return 'Name must be less than ${AppConstants.maxNameLength} characters';
    }

    // Check for valid characters (letters, spaces, hyphens, apostrophes)
    final nameRegex = RegExp(r"^[a-zA-Z\s\-']+$");
    if (!nameRegex.hasMatch(trimmedValue)) {
      return 'Name can only contain letters, spaces, hyphens, and apostrophes';
    }

    return null;
  }

  // Age Validation
  static String? validateAge(String? value) {
    if (value == null || value.isEmpty) {
      return 'Age is required';
    }

    final age = int.tryParse(value);
    if (age == null) {
      return 'Please enter a valid age (numbers only)';
    }

    if (age < AppConstants.minAge) {
      return 'You must be at least ${AppConstants.minAge} years old';
    }

    if (age > AppConstants.maxAge) {
      return 'Please enter a valid age between ${AppConstants.minAge} and ${AppConstants.maxAge}';
    }

    return null;
  }

  // Password Validation
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }

    if (value.length < 8) {
      return 'Password must be at least 8 characters long';
    }

    if (!RegExp(r'[A-Z]').hasMatch(value)) {
      return 'Password must contain at least one uppercase letter';
    }

    if (!RegExp(r'[a-z]').hasMatch(value)) {
      return 'Password must contain at least one lowercase letter';
    }

    if (!RegExp(r'[0-9]').hasMatch(value)) {
      return 'Password must contain at least one number';
    }

    if (!RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(value)) {
      return 'Password must contain at least one special character';
    }

    return null;
  }

  // Confirm Password Validation
  static String? validateConfirmPassword(String? value, String password) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password';
    }

    if (value != password) {
      return 'Passwords do not match';
    }

    return null;
  }

  // OTP Validation
  static String? validateOTP(String? value) {
    if (value == null || value.isEmpty) {
      return 'OTP is required';
    }

    if (value.length != 6) {
      return 'OTP must be 6 digits';
    }

    if (!RegExp(r'^[0-9]+$').hasMatch(value)) {
      return 'OTP must contain only numbers';
    }

    return null;
  }

  // Required Field Validation
  static String? validateRequired(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  // Minimum Length Validation
  static String? validateMinLength(
    String? value,
    int minLength,
    String fieldName,
  ) {
    if (value == null || value.length < minLength) {
      return '$fieldName must be at least $minLength characters';
    }
    return null;
  }

  // Maximum Length Validation
  static String? validateMaxLength(
    String? value,
    int maxLength,
    String fieldName,
  ) {
    if (value != null && value.length > maxLength) {
      return '$fieldName must be less than $maxLength characters';
    }
    return null;
  }

  // URL Validation
  static String? validateURL(String? value) {
    if (value == null || value.isEmpty) {
      return null; // URL is optional
    }

    final urlRegex = RegExp(
      r'^https?:\/\/(www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b([-a-zA-Z0-9()@:%_\+.~#?&//=]*)$',
    );

    if (!urlRegex.hasMatch(value)) {
      return 'Please enter a valid URL';
    }

    return null;
  }

  // Price Validation
  static String? validatePrice(String? value) {
    if (value == null || value.isEmpty) {
      return 'Price is required';
    }

    final price = double.tryParse(value);
    if (price == null) {
      return 'Please enter a valid price';
    }

    if (price < 0) {
      return 'Price cannot be negative';
    }

    if (price > 999999.99) {
      return 'Price is too high';
    }

    return null;
  }

  // Date Validation
  static String? validateDate(String? value) {
    if (value == null || value.isEmpty) {
      return 'Date is required';
    }

    try {
      DateTime.parse(value);
    } catch (e) {
      return 'Please enter a valid date';
    }

    return null;
  }

  // Gender Validation
  static String? validateGender(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please select your gender';
    }

    final validGenders = ['male', 'female', 'other'];
    if (!validGenders.contains(value.toLowerCase())) {
      return 'Please select a valid gender option';
    }

    return null;
  }

  // Future Date Validation
  static String? validateFutureDate(String? value) {
    final dateError = validateDate(value);
    if (dateError != null) {
      return dateError;
    }

    final date = DateTime.parse(value!);
    final now = DateTime.now();

    if (date.isBefore(now)) {
      return 'Date must be in the future';
    }

    return null;
  }

  // Time Validation
  static String? validateTime(String? value) {
    if (value == null || value.isEmpty) {
      return 'Time is required';
    }

    final timeRegex = RegExp(r'^([0-1]?[0-9]|2[0-3]):[0-5][0-9]$');
    if (!timeRegex.hasMatch(value)) {
      return 'Please enter a valid time (HH:MM)';
    }

    return null;
  }

  // Number Validation
  static String? validateNumber(String? value) {
    if (value == null || value.isEmpty) {
      return 'Number is required';
    }

    final number = double.tryParse(value);
    if (number == null) {
      return 'Please enter a valid number';
    }

    return null;
  }

  // Positive Number Validation
  static String? validatePositiveNumber(String? value) {
    final numberError = validateNumber(value);
    if (numberError != null) {
      return numberError;
    }

    final number = double.parse(value!);
    if (number <= 0) {
      return 'Number must be positive';
    }

    return null;
  }

  // Integer Validation
  static String? validateInteger(String? value) {
    if (value == null || value.isEmpty) {
      return 'Integer is required';
    }

    final integer = int.tryParse(value);
    if (integer == null) {
      return 'Please enter a valid integer';
    }

    return null;
  }

  // Positive Integer Validation
  static String? validatePositiveInteger(String? value) {
    final integerError = validateInteger(value);
    if (integerError != null) {
      return integerError;
    }

    final integer = int.parse(value!);
    if (integer <= 0) {
      return 'Integer must be positive';
    }

    return null;
  }

  // Range Validation
  static String? validateRange(String? value, double min, double max) {
    final numberError = validateNumber(value);
    if (numberError != null) {
      return numberError;
    }

    final number = double.parse(value!);
    if (number < min || number > max) {
      return 'Value must be between $min and $max';
    }

    return null;
  }

  // List Validation
  static String? validateList(
    List<dynamic>? value,
    int minItems,
    String fieldName,
  ) {
    if (value == null || value.isEmpty) {
      return '$fieldName is required';
    }

    if (value.length < minItems) {
      return '$fieldName must have at least $minItems items';
    }

    return null;
  }

  // File Size Validation (in MB)
  static String? validateFileSize(int fileSizeBytes, int maxSizeMB) {
    final fileSizeMB = fileSizeBytes / (1024 * 1024);

    if (fileSizeMB > maxSizeMB) {
      return 'File size must be less than ${maxSizeMB}MB';
    }

    return null;
  }

  // File Type Validation
  static String? validateFileType(
    String fileName,
    List<String> allowedExtensions,
  ) {
    final extension = fileName.split('.').last.toLowerCase();

    if (!allowedExtensions.contains(extension)) {
      return 'File type not supported. Allowed types: ${allowedExtensions.join(', ')}';
    }

    return null;
  }
}
