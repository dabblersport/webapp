import 'package:dabbler/utils/transitions/app_sheet_route.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dabbler/core/constants/uae_locations.dart';
import 'package:dabbler/core/widgets/composer_drawer_kit.dart';
import 'package:dabbler/features/social/domain/posted_from.dart';
import 'package:dabbler/features/social/providers/post_composer_providers.dart';
import 'package:dabbler/l10n/app_localizations.dart';

/// The cities a post can be posted from, one row per city, in list order.
List<String> composerPostedFromCities(String query) {
  final needle = query.trim().toLowerCase();
  final seen = <String>{};
  return <String>[
    for (final entry in UAELocations.cities)
      if (seen.add(entry.city) &&
          (needle.isEmpty || entry.city.toLowerCase().contains(needle)))
        entry.city,
  ];
}

/// Opens "Posted from" (KAN-592): choose the city this post is posted from.
/// It sets only the composer's posting city. It never changes the device or
/// app location, the place tag, or the typed draft, so it is safe to open from
/// the Post button when no city is known.
Future<void> showComposerPostedFromSheet(
  BuildContext context,
  WidgetRef ref, {
  bool prompt = false,
}) {
  final l = AppLocalizations.of(context);
  return showAppSheet<void>(
    context: context,
    title: l.composer_posted_from_title,
    titleWidget: composerSheetTitle(l.composer_posted_from_title),
    detent: DabblerSheetDetent.content,
    contentMaxFraction: DabblerSheet.contentMaxFractionMedium,
    pageBackground: true,
    hairlineOutside: ComposerFrameScope.active(context),
    showCloseButton: false,
    builder: composerFrameBuilder(
      context,
      (_) => ComposerPostedFromSheet(prompt: prompt),
    ),
  );
}

/// The search field and city rows of [showComposerPostedFromSheet].
class ComposerPostedFromSheet extends ConsumerStatefulWidget {
  const ComposerPostedFromSheet({super.key, this.prompt = false});

  /// True when the sheet opened because Post was tapped with no city: it says
  /// the draft is kept.
  final bool prompt;

  @override
  ConsumerState<ComposerPostedFromSheet> createState() =>
      _ComposerPostedFromSheetState();
}

class _ComposerPostedFromSheetState
    extends ConsumerState<ComposerPostedFromSheet> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cities = composerPostedFromCities(_query);
    final current = ref.watch(composerPostedFromProvider)?.city;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.prompt)
          ComposerCenteredState.message(
            l.composer_posted_from_prompt,
            key: const Key('composer-posted-from-prompt'),
          ),
        ComposerSearchField(
          controller: _search,
          placeholder: l.composer_posted_from_search,
          onChanged: (v) => setState(() => _query = v),
        ),
        if (cities.isEmpty)
          ComposerCenteredState.message(l.composer_posted_from_none)
        else
          for (final city in cities)
            ComposerPickerRow(
              key: ValueKey('composer-posted-from-$city'),
              icon: 'location',
              title: city,
              selected: city == current,
              onTap: () {
                ref
                    .read(postComposerProvider.notifier)
                    .setPostedFrom(PostedFrom(city: city));
                Navigator.of(context).maybePop();
              },
            ),
      ],
    );
  }
}
