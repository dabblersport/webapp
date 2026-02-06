# Dart Token Files (Generated)

This folder contains **Material 3 color role tokens** exported as Dart constants.

These Dart files are the **source of truth for app colors** at runtime.

## Files

One file per **context** × **mode**:

- `main_light.dart`, `main_dark.dart`
- `social_light.dart`, `social_dark.dart`
- `sports_light.dart`, `sports_dark.dart`
- `activity_light.dart`, `activity_dark.dart`
- `profile_light.dart`, `profile_dark.dart`

## Token Shape (Mandatory)

Each file exports exactly one immutable token object:

- `const theme = (...);`

Tokens are accessed via:

- `theme.<context>.<role>`

Where:

- `context ∈ { main, social, sports, activity, profile }`
- `role` is the Material 3 role name **unchanged** (e.g. `primary`, `onPrimary`, `surfaceContainerHigh`, `inverseSurface`, ...)

## Mapping Rules

- **No role renames**: Dart keys match JSON keys 1:1.
- **No value changes**: JSON hex values are preserved exactly.
- **No collapsing/inference**: even identical colors remain duplicated across contexts.
- **No shared light/dark files**: each file represents a single mode.

## Color Encoding

JSON colors are `#RRGGBB` and are encoded in Dart as:

- `Color(0xFFRRGGBB)`

This is a direct conversion with an opaque alpha channel (`FF`).

## What’s Not Here (By Design)

- No widget code
- No theme builders
- No helpers
- No usage examples

This phase is pure data definition.
