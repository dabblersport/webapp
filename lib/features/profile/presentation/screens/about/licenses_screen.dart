import 'package:dabbler/core/widgets/composer_drawer_kit.dart' show composerType;
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Screen displaying open source licenses and attributions, on a
/// design-system page: a search field over a section of license rows; a row
/// opens the license's details in a design-system sheet.
class LicensesScreen extends ConsumerStatefulWidget {
  const LicensesScreen({super.key});

  @override
  ConsumerState<LicensesScreen> createState() => _LicensesScreenState();
}

class _LicensesScreenState extends ConsumerState<LicensesScreen> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  // Sample license data - in a real app, this would be loaded from packages
  final List<LicenseInfo> _licenses = [
    LicenseInfo(
      name: 'Flutter',
      version: '3.24.0',
      description: 'UI toolkit for building natively compiled applications',
      license: 'BSD 3-Clause License',
      copyright: 'Copyright 2014 The Flutter Authors',
      url: 'https://flutter.dev',
    ),
    LicenseInfo(
      name: 'Riverpod',
      version: '2.6.1',
      description: 'A reactive caching and data-binding framework',
      license: 'MIT License',
      copyright: 'Copyright 2020 Remi Rousselet',
      url: 'https://riverpod.dev',
    ),
    LicenseInfo(
      name: 'go_router',
      version: '14.2.7',
      description: 'Declarative routing package for Flutter',
      license: 'BSD 3-Clause License',
      copyright: 'Copyright 2013 The Flutter Authors',
      url: 'https://pub.dev/packages/go_router',
    ),
    LicenseInfo(
      name: 'http',
      version: '1.2.0',
      description:
          'Composable, multi-platform, future-based API for HTTP requests',
      license: 'BSD 3-Clause License',
      copyright: 'Copyright 2014, the Dart project authors',
      url: 'https://pub.dev/packages/http',
    ),
    LicenseInfo(
      name: 'shared_preferences',
      version: '2.2.3',
      description:
          'Flutter plugin for reading and writing simple key-value pairs',
      license: 'BSD 3-Clause License',
      copyright: 'Copyright 2013 The Flutter Authors',
      url: 'https://pub.dev/packages/shared_preferences',
    ),
    LicenseInfo(
      name: 'image_picker',
      version: '1.1.2',
      description:
          'Flutter plugin for selecting images from the gallery or camera',
      license: 'BSD 3-Clause License',
      copyright: 'Copyright 2013 The Flutter Authors',
      url: 'https://pub.dev/packages/image_picker',
    ),
    LicenseInfo(
      name: 'supabase_flutter',
      version: '2.5.6',
      description: 'Flutter integration for Supabase',
      license: 'MIT License',
      copyright: 'Copyright 2020 Supabase',
      url: 'https://pub.dev/packages/supabase_flutter',
    ),
  ];

  List<LicenseInfo> get _filteredLicenses {
    if (_searchQuery.isEmpty) return _licenses;
    final q = _searchQuery.toLowerCase();
    return _licenses.where((license) {
      return license.name.toLowerCase().contains(q) ||
          license.description.toLowerCase().contains(q) ||
          license.license.toLowerCase().contains(q);
    }).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = DabblerColors.of(context);
    final filtered = _filteredLicenses;

    return DabblerPage(
      topBar: DabblerNavigationTopBar.titled(
        title: 'Open Source Licenses',
        onBack: () => context.pop(),
        actions: [
          DabblerNavigationAction(
            icon: 'info-circle',
            label: 'About Licenses',
            onPressed: _showLicenseInfo,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsetsDirectional.fromSTEB(
          DabblerSpacing.space6,
          DabblerSpacing.space4,
          DabblerSpacing.space6,
          DabblerSpacing.space8,
        ),
        children: [
          Text(
            'This app is built with amazing open source libraries. We thank all contributors for their work.',
            style: composerType(context, DabblerType.body, colors.textSecondary),
          ),
          const SizedBox(height: DabblerSpacing.space2),
          Text(
            '${_licenses.length} open source packages',
            style: composerType(
              context,
              DabblerType.footnote,
              colors.textTertiary,
            ),
          ),
          const SizedBox(height: DabblerSpacing.space5),
          DabblerSearchField(
            controller: _searchController,
            placeholder: 'Search licenses...',
            onChanged: (value) => setState(() => _searchQuery = value),
            onCleared: () => setState(() => _searchQuery = ''),
          ),
          const SizedBox(height: DabblerSpacing.space5),
          if (filtered.isEmpty)
            const DabblerEmptyState(
              icon: 'search-status',
              title: 'No licenses found',
              text: 'Try adjusting your search query',
            )
          else
            DabblerSection(
              children: [
                for (final license in filtered)
                  DabblerInputRow(
                    leading: DabblerIcon(
                      'code',
                      size: 20,
                      color: colors.textSecondary,
                    ),
                    title: license.name,
                    subtitle: '${license.license} · v${license.version}',
                    trailing: const DabblerChevron(),
                    onTap: () => _showLicenseDetails(license),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  void _showLicenseDetails(LicenseInfo license) {
    showDabblerSheet<void>(
      context: context,
      title: license.name,
      detent: DabblerSheetDetent.content,
      builder: (sheetContext) => _LicenseDetails(license: license),
    );
  }

  void _showLicenseInfo() {
    showDabblerDialog<void>(
      context: context,
      builder: (dialogContext) => DabblerDialog(
        title: 'About Open Source Licenses',
        description:
            'This app uses various open source libraries and packages. Each license defines the terms under which the code can be used, modified, and distributed.\n\n'
            'We are grateful to all the developers and contributors who make their work available under open source licenses.',
        onClose: () => Navigator.of(dialogContext).pop(),
        primaryAction: DabblerDialogAction(
          label: 'Got it',
          onPressed: () => Navigator.of(dialogContext).pop(),
        ),
      ),
    );
  }
}

/// The license detail sheet body: label/value rows, the description, and the
/// "View on Web" action (which, as before, only announces the URL).
class _LicenseDetails extends StatelessWidget {
  const _LicenseDetails({required this.license});

  final LicenseInfo license;

  @override
  Widget build(BuildContext context) {
    final colors = DabblerColors.of(context);
    Widget detail(String label, String value) => Padding(
      padding: const EdgeInsetsDirectional.only(bottom: DabblerSpacing.space4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: composerType(
                context,
                DabblerType.footnote,
                colors.textTertiary,
                weight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: composerType(context, DabblerType.body, colors.textPrimary),
            ),
          ),
        ],
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        detail('Version', license.version),
        detail('License', license.license),
        detail('Copyright', license.copyright),
        detail('URL', license.url),
        const SizedBox(height: DabblerSpacing.space3),
        Text(
          'Description',
          style: composerType(context, DabblerType.headline, colors.textPrimary),
        ),
        const SizedBox(height: DabblerSpacing.space2),
        Text(
          license.description,
          style: composerType(context, DabblerType.body, colors.textSecondary),
        ),
        const SizedBox(height: DabblerSpacing.space6),
        DabblerButton(
          label: 'View on Web',
          tone: DabblerButtonTone.outlined,
          size: DabblerButtonSize.full,
          fullWidth: true,
          onPressed: () => DabblerToastProvider.of(
            context,
          ).show(DabblerToastSpec(message: 'Opening ${license.url}')),
        ),
      ],
    );
  }
}

class LicenseInfo {
  final String name;
  final String version;
  final String description;
  final String license;
  final String copyright;
  final String url;

  LicenseInfo({
    required this.name,
    required this.version,
    required this.description,
    required this.license,
    required this.copyright,
    required this.url,
  });
}
