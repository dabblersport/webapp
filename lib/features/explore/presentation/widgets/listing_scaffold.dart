import 'package:dabbler/core/system_ui/system_chrome_sync.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The colour a listing header band currently paints, published so the shell
/// can carry it under the status bar (the band bleeds up to the screen top, as
/// the frame's 50px status row does). Null when no tinted listing is showing.
final StateProvider<Color?> listingHeadTintProvider = StateProvider<Color?>(
  (Ref ref) => null,
);

/// A listing: the design system's collapsing header over its pages
/// (`Listings.dc.html` 2026-10-08), wired to the app — the band's colour goes
/// to the shell ([listingHeadTintProvider]) and to the status bar
/// ([SystemChromeSurface]).
class ListingScaffold extends ConsumerStatefulWidget {
  const ListingScaffold({
    super.key,
    required this.header,
    required this.tabs,
    required this.pages,
    required this.filters,
    required this.clearAllLabel,
    required this.onClearAll,
    this.head = DabblerListingHead.tint,
  });

  final Widget header;
  final List<DabblerTabItem> tabs;
  final List<Widget> pages;
  final List<DabblerFilterRailItem> filters;
  final String clearAllLabel;
  final VoidCallback onClearAll;
  final DabblerListingHead head;

  @override
  ConsumerState<ListingScaffold> createState() => _ListingScaffoldState();
}

class _ListingScaffoldState extends ConsumerState<ListingScaffold> {
  Color? _band;

  void _onBand(Color? band) {
    if (!mounted && band != null) return;
    if (mounted && _band != band) setState(() => _band = band);
    try {
      ref.read(listingHeadTintProvider.notifier).state = band;
    } on StateError {
      // The scope is already gone (the app or a test is being torn down).
    }
  }

  @override
  Widget build(BuildContext context) => SystemChromeSurface(
    top: _band,
    child: DabblerListingPage(
      head: widget.head,
      onBandColor: _onBand,
      header: widget.header,
      tabs: widget.tabs,
      pages: widget.pages,
      filters: widget.filters,
      clearAllLabel: widget.clearAllLabel,
      onClearAll: widget.onClearAll,
    ),
  );
}
