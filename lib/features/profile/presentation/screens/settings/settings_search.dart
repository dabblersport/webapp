import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';

/// One searchable destination (`Settings.dc.html` `searchIndex`).
class SettingsSearchEntry {
  const SettingsSearchEntry({
    required this.icon,
    required this.label,
    required this.path,
    required this.onTap,
    this.terms = const [],
  });

  /// Kebab-case icon name drawn through [DabblerIcon].
  final String icon;
  final String label;

  /// Where the destination lives, e.g. `Privacy › Safety`.
  final String path;
  final VoidCallback onTap;
  final List<String> terms;

  bool matches(String query) =>
      label.toLowerCase().contains(query) ||
      path.toLowerCase().contains(query) ||
      terms.any((t) => t.contains(query));
}

/// The results list shown in place of the tiles while a query is typed
/// (`Settings.dc.html:118-139`): a count line over one card of rows, each
/// with its icon, label, path and a chevron.
class SettingsSearchResults extends StatelessWidget {
  const SettingsSearchResults({super.key, required this.results});

  final List<SettingsSearchEntry> results;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (results.isEmpty) {
      return Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: DabblerSpacing.space2,
        ),
        child: DabblerText(
          l10n.settings_search_no_match,
          style: DabblerType.footnote,
          tone: DabblerTextTone.secondary,
        ),
      );
    }
    return DabblerRowGroup(
      header: DabblerType.toWesternDigits(
        l10n.settings_search_results(results.length),
      ),
      children: [
        for (final r in results)
          DabblerInputRow(
            flat: true,
            showDivider: false,
            onTap: r.onTap,
            leading: DabblerIcon(r.icon, size: DabblerSizing.iconMd),
            title: r.label,
            subtitle: r.path,
            trailing: const DabblerChevron(circled: true),
          ),
      ],
    );
  }
}
