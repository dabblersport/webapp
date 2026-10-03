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
