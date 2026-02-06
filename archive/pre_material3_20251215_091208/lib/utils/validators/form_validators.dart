/// Base class for form field validators using the compose pattern.
abstract class FormValidator<T> {
  String? validate(T value);

  /// Compose multiple validators into one.
  static FormValidator<T> compose<T>(List<FormValidator<T>> validators) {
    return _CompositeValidator<T>(validators);
  }
}

class _CompositeValidator<T> extends FormValidator<T> {
  final List<FormValidator<T>> _validators;
  _CompositeValidator(this._validators);

  @override
  String? validate(T value) {
    for (final validator in _validators) {
      final result = validator.validate(value);
      if (result != null) return result;
    }
    return null;
  }
}
