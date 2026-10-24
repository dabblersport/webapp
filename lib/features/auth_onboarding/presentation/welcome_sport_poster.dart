import 'package:dabbler/core/config/supabase_config.dart';
import 'package:dabbler/core/services/auth_service.dart';
import 'package:dabbler/core/utils/sport_background_assets.dart';
import 'package:dabbler/features/auth_onboarding/presentation/widgets/onboarding_step_frame.dart';
import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The poster behind Welcome and Welcome Back (KAN-490): one supplied poster
/// per sport, matched by the stable design-system sport key (never a display
/// name). Eleven sports have one; every other key has none and the screen keeps
/// its normal background. The bundled files are WebP copies of the supplied
/// PNGs, which stay unchanged under `assets/images/` and are not bundled.
const Map<String, String> welcomeSportPosters = sportBackgroundAssets;

/// The poster asset for a design-system sport [key], or null (no key, unknown
/// key, or a sport without a poster).
String? welcomePosterAsset(String? key) => sportBackgroundAsset(key);

/// The full-bleed poster for [key], or null for the normal background. Uses
/// the design system's sport background (cover, no scrim) with the app's own
/// artwork, so no other screen's artwork registry changes.
Widget? welcomePosterBackground(String? key) {
  final asset = welcomePosterAsset(key);
  if (asset == null) return null;
  return sportBackgroundWidget(
    key,
    widgetKey: ValueKey<String>('welcome-poster-$asset'),
  );
}

/// Loads the signed-in user's saved primary sport as a design-system key, or
/// null. Read-only: the current user's active profile `primary_sport` (a
/// `sports.id`), then that `sports` row. Nothing is cached, so a different
/// account never sees this account's poster.
typedef WelcomeSavedSportLoader = Future<String?> Function();

Future<String?> loadSavedPrimarySportKey() async {
  try {
    final profile = await AuthService().getUserProfile(
      fields: const ['primary_sport'],
    );
    final sportId = profile?['primary_sport'] as String?;
    if (sportId == null || sportId.isEmpty) return null;
    final row = await Supabase.instance.client
        .from(SupabaseConfig.sportsTable)
        .select('sport_key, name_en')
        .eq('id', sportId)
        .maybeSingle();
    if (row == null) return null;
    return dsSportFromKeys(
      row['sport_key'] as String?,
      row['name_en'] as String?,
    )?.key;
  } catch (_) {
    // Decoration only: the screen works without it.
    return null;
  }
}
