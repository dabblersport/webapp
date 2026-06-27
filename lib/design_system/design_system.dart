/// Single entrypoint for the app's (temporary) design-system layer.
///
/// Goal: keep all DS-related imports under `lib/design_system/*` so the
/// underlying implementations can be swapped/removed without touching the app.
library;

export '../themes/app_theme.dart';
export '../themes/material3_extensions.dart';
export '../core/theme/color_token_extensions.dart';
export '../core/theme/dynamic_color_scheme_loader.dart';
