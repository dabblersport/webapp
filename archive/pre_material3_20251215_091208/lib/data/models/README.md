Data models in this directory are defined with Freezed and JsonSerializable.
Each model should expose immutable value objects with generated `copyWith` helpers.
Run `dart run build_runner build -d` after editing a model to refresh generated code.
Keep constructors lightweight and rely on JSON helpers for parsing edge cases.
