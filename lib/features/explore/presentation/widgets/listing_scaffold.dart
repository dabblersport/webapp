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
    this.onFiltersTap,
    this.filtersTapSemanticLabel,
  });

  final Widget header;
  final List<DabblerTabItem> tabs;
  final List<Widget> pages;
  final List<DabblerFilterRailItem> filters;
  final String clearAllLabel;
  final VoidCallback onClearAll;
  final DabblerListingHead head;

  /// Opens the filter sheet from the applied-filter rail (null: not tappable).
  final VoidCallback? onFiltersTap;

  /// The rail's accessible name as a button, localised. Used with
  /// [onFiltersTap].
  final String? filtersTapSemanticLabel;

  @override
  ConsumerState<ListingScaffold> createState() => _ListingScaffoldState();
}

class _ListingScaffoldState extends ConsumerState<ListingScaffold> {
  Color? _band;
  Color? _published;

  /// A shell keeps every branch mounted (indexed stack); only the visible one
  /// — the one whose tickers run — may claim the status bar and the shell's
  /// top fill. Written after the frame, and only ever cleared by its owner.
  void _sync(bool visible) {
    final Color? want = visible ? _band : null;
    if (_published == want) return;
    final Color? previous = _published;
    _published = want;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        final StateController<Color?> c = ref.read(
          listingHeadTintProvider.notifier,
        );
        if (want != null) {
          c.state = want;
        } else if (c.state == previous) {
          c.state = null;
        }
      } on StateError {
        // The scope is already gone (the app or a test is being torn down).
      }
    });
  }

  void _onBand(Color? band) {
    if (!mounted || _band == band) return;
    setState(() => _band = band);
  }

  @override
  void deactivate() {
    _sync(false);
    super.deactivate();
  }

  @override
  Widget build(BuildContext context) {
    final bool visible = TickerMode.of(context);
    _sync(visible);
    return SystemChromeSurface(
      top: visible ? _band : null,
      child: DabblerListingPage(
        head: widget.head,
        onBandColor: _onBand,
        header: widget.header,
        tabs: widget.tabs,
        pages: widget.pages,
        filters: widget.filters,
        clearAllLabel: widget.clearAllLabel,
        onClearAll: widget.onClearAll,
        onFiltersTap: widget.onFiltersTap,
        filtersTapSemanticLabel: widget.filtersTapSemanticLabel,
      ),
    );
  }
}
