import 'package:dabbler/features/explore/presentation/widgets/listing_scaffold.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart' show Theme, ThemeData, ThemeExtension;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Re-tints the shell for the section being shown (`data-theme` on the
/// Listings frames: Games `sport`, Meetups `active`): the brand colour of
/// everything under it — the screen, the bottom bar and the Action Area —
/// follows [theme]. The paper never changes (the brand re-tints only the
/// brand). A null [theme] leaves the app's own theme as it is.
///
/// A tinted listing header also paints under the status bar: the listing
/// publishes its band colour ([listingHeadTintProvider]) and the design
/// system's top fill paints it across the top inset.
class SectionThemed extends ConsumerWidget {
  const SectionThemed({super.key, this.theme, required this.child});

  final DabblerTheme? theme;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final DabblerTheme? section = theme;
    final Widget body = DabblerTopFill(
      color: ref.watch(listingHeadTintProvider),
      child: child,
    );
    if (section == null) return body;
    final ThemeData base = Theme.of(context);
    final DabblerColors colors = DabblerColors.resolve(
      theme: section,
      brightness: base.brightness,
    );
    final Map<Object, ThemeExtension<dynamic>> extensions =
        Map<Object, ThemeExtension<dynamic>>.of(base.extensions)
          ..[DabblerColors] = colors;
    return Theme(
      data: base.copyWith(extensions: extensions.values),
      child: body,
    );
  }
}
