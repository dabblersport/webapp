/// Single entrypoint for the app's (temporary) design-system layer.
///
/// Goal: keep all DS-related imports under `lib/design_system/*` so the
/// underlying implementations can be swapped/removed without touching the app.
library;

export 'theme/app_theme.dart';
export 'theme/material3_extensions.dart';
export 'theme/color_token_extensions.dart';
export 'theme/dynamic_color_scheme_loader.dart';
