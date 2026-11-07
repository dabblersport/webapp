# Rating summary goldens

Run these commands from the repository root on both Linux and macOS with the
same Flutter version (verified with Flutter 3.47.5):

```sh
flutter pub get
flutter test --no-pub test/features/ratings/rating_summary_test.dart --update-goldens
flutter test --no-pub test/features/ratings/rating_summary_test.dart
```

Inspect both English and Arabic images for each platform after regeneration,
including the rating star. The final command compares against the platform's
baseline exactly. Other hosts fail the golden tests until a baseline is added;
the remaining tests can still run.
