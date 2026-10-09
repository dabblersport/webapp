# Working on the design system locally

`pubspec.yaml` depends on `dabbler_design_system` from git (branch `alpha-ds`,
pinned to a commit by `pubspec.lock`). To use a local checkout instead, create an
**uncommitted** `pubspec_overrides.yaml` next to `pubspec.yaml`:

```yaml
dependency_overrides:
  dabbler_design_system:
    path: ../dabbler-design-system
```

Then run `flutter pub get`. Delete the file to return to the pinned git version.
To adopt new DS work: push it to `alpha-ds`, remove the override, run
`flutter pub upgrade dabbler_design_system`, and commit the changed `pubspec.lock`.

## Render tests and fonts

Render and measure tests register the design-system fonts through the one shared
`loadRenderFonts()` (`test/support/render_mode.dart`). It finds the fonts folder from
`.dart_tool/package_config.json` (the resolved package), so no sibling
`../dabbler-design-system` checkout is needed, and falls back to that sibling only if
the package folder lacks them. If neither holds the fonts it throws a `StateError`
naming the paths tried, instead of letting the engine fall back to Ahem (which shows
up as dozens of unrelated overflow failures). Run `flutter pub get` first.
