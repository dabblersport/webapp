import 'package:dabbler/utils/transitions/app_sheet_route.dart';
import 'dart:async';
import 'dart:convert';

import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;

import 'package:dabbler/core/config/environment.dart';
import 'package:dabbler/core/widgets/composer_drawer_kit.dart';
import 'package:dabbler/l10n/app_localizations.dart';

/// Opens the GIPHY picker as a design-system sheet. [onSelected] receives the
/// chosen GIF's URL; the sheet closes itself.
///
/// This is THE app's GIF integration (GIPHY, `Environment.giphyApiKey`): the
/// post and comment composers and the chat composer (KAN-582) all open it.
Future<void> showGifPickerSheet(
  BuildContext context, {
  required ValueChanged<String> onSelected,
}) => showAppSheet<void>(
  context: context,
  title: AppLocalizations.of(context).composer_search_gifs,
  detent: DabblerSheetDetent.content,
  builder: (ctx) => GifPickerSheet(
    onSelected: (url) {
      Navigator.pop(ctx);
      onSelected(url);
    },
  ),
);

// GIF PICKER SHEET (GIPHY)

/// What the picker is showing instead of results (KAN-582).
enum GifPickerFailure {
  /// The request could not be made: no connection, a timeout.
  offline,

  /// The provider answered with an error, nonsense, or no key is configured.
  unavailable,
}

class GifPickerSheet extends StatefulWidget {
  /// [client] and [apiKey] default to a plain `package:http` client and
  /// `Environment.giphyApiKey`; they exist so tests need no network.
  const GifPickerSheet({
    super.key,
    required this.onSelected,
    this.client,
    this.apiKey,
  });

  final ValueChanged<String> onSelected;
  final http.Client? client;
  final String? apiKey;

  @override
  State<GifPickerSheet> createState() => _GifPickerSheetState();
}

class _GifPickerSheetState extends State<GifPickerSheet> {
  static const _baseUrl = 'https://api.giphy.com/v1/gifs';

  final _searchController = TextEditingController();
  Timer? _debounce;
  List<Map<String, dynamic>> _results = [];
  bool _loading = false;
  GifPickerFailure? _failure;
  int _offset = 0;
  bool _hasMore = true;
  String _apiKey = '';

  @override
  void initState() {
    super.initState();
    _apiKey = widget.apiKey ?? Environment.giphyApiKey;
    if (_apiKey.isEmpty) {
      _failure = GifPickerFailure.unavailable;
      return;
    }
    _loadFirstPage();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<http.Response> _get(Uri uri) =>
      widget.client != null ? widget.client!.get(uri) : http.get(uri);

  Uri _uri(String query, int offset) {
    final params = <String, String>{
      'api_key': _apiKey,
      'limit': '30',
      'offset': '$offset',
      'rating': 'pg-13',
      'bundle': 'messaging_non_clips',
    };
    if (query.isNotEmpty) params['q'] = query;
    return Uri.parse(
      '$_baseUrl/${query.isEmpty ? 'trending' : 'search'}',
    ).replace(queryParameters: params);
  }

  /// The first page of trending (blank query) or search results, replacing
  /// what is shown.
  Future<void> _loadFirstPage() async {
    final query = _searchController.text.trim();
    setState(() {
      _loading = true;
      _failure = null;
      _offset = 0;
      _hasMore = true;
    });
    try {
      final response = await _get(_uri(query, 0));
      if (!mounted) return;
      if (response.statusCode != 200) {
        setState(() {
          _loading = false;
          _failure = GifPickerFailure.unavailable;
        });
        return;
      }
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final data = (body['data'] as List).cast<Map<String, dynamic>>();
      final pagination = body['pagination'] as Map<String, dynamic>?;
      setState(() {
        _results = data;
        _offset = 30;
        _hasMore = (pagination?['total_count'] as int? ?? 0) > _offset;
        _loading = false;
      });
    } on FormatException {
      _fail(GifPickerFailure.unavailable);
    } on TypeError {
      _fail(GifPickerFailure.unavailable);
    } catch (_) {
      // The request itself failed: no connection, a timeout, a refused host.
      _fail(GifPickerFailure.offline);
    }
  }

  void _fail(GifPickerFailure failure) {
    if (!mounted) return;
    setState(() {
      _loading = false;
      _failure = failure;
    });
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore) return;
    final query = _searchController.text.trim();
    setState(() => _loading = true);
    try {
      final response = await _get(_uri(query, _offset));
      if (!mounted) return;
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final data = (body['data'] as List).cast<Map<String, dynamic>>();
        final pagination = body['pagination'] as Map<String, dynamic>?;
        setState(() {
          _results.addAll(data);
          _offset += 30;
          _hasMore = (pagination?['total_count'] as int? ?? 0) > _offset;
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(DabblerMotion.debounceSearch, _loadFirstPage);
  }

  /// Extract the full-size GIF URL to store in the post media list.
  String? _getGifUrl(Map<String, dynamic> gif) {
    final images = gif['images'] as Map<String, dynamic>?;
    if (images == null) return null;
    final original = images['original'] as Map<String, dynamic>?;
    final downsized = images['downsized'] as Map<String, dynamic>?;
    return (original?['url'] as String?) ?? (downsized?['url'] as String?);
  }

  /// Extract a small preview URL for the grid (fast loading).
  String? _getPreviewUrl(Map<String, dynamic> gif) {
    final images = gif['images'] as Map<String, dynamic>?;
    if (images == null) return null;
    final fixedWidth = images['fixed_width'] as Map<String, dynamic>?;
    final preview = images['preview_gif'] as Map<String, dynamic>?;
    final downsizedSmall = images['fixed_width_small'] as Map<String, dynamic>?;
    return (fixedWidth?['url'] as String?) ??
        (preview?['url'] as String?) ??
        (downsizedSmall?['url'] as String?);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final Widget results;
    if (_failure != null) {
      final offline = _failure == GifPickerFailure.offline;
      results = Padding(
        padding: const EdgeInsets.all(DabblerSpacing.space2),
        child: Align(
          alignment: AlignmentDirectional.topStart,
          child: DabblerBanner(
            key: offline ? GifPickerKeys.offline : GifPickerKeys.unavailable,
            tone: offline ? DabblerBannerTone.warning : DabblerBannerTone.error,
            title: offline
                ? l10n.composer_gif_offline_title
                : l10n.composer_gif_unavailable_title,
            message: offline
                ? l10n.composer_gif_offline_text
                : l10n.composer_gif_unavailable_text,
            action: DabblerBannerAction(
              label: l10n.composer_gif_retry,
              onPressed: _apiKey.isEmpty ? null : _loadFirstPage,
            ),
          ),
        ),
      );
    } else if (_loading && _results.isEmpty) {
      results = const ComposerCenteredState.loading();
    } else if (_results.isEmpty) {
      results = ComposerCenteredState.message(l10n.composer_gif_empty);
    } else {
      results = NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification is ScrollEndNotification &&
              notification.metrics.extentAfter < 200) {
            _loadMore();
          }
          return false;
        },
        child: GridView.builder(
          padding: const EdgeInsets.all(DabblerSpacing.space2),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: DabblerSpacing.space2,
            mainAxisSpacing: DabblerSpacing.space2,
          ),
          itemCount: _results.length + (_loading ? 1 : 0),
          itemBuilder: (ctx, index) {
            if (index >= _results.length) {
              return const Center(
                child: DabblerSpinner(size: DabblerSpinnerSize.sm),
              );
            }

            final gif = _results[index];
            final previewUrl = _getPreviewUrl(gif);
            if (previewUrl == null) return const SizedBox.shrink();

            return DabblerImage(
              url: previewUrl,
              radius: DabblerRadius.mdAll,
              semanticLabel: 'GIF',
              onTap: () {
                final gifUrl = _getGifUrl(gif);
                if (gifUrl != null) {
                  widget.onSelected(gifUrl);
                }
              },
            );
          },
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ComposerSearchField(
          controller: _searchController,
          placeholder: l10n.composer_gif_search_placeholder,
          onChanged: _onSearchChanged,
        ),
        ComposerScrollArea(fraction: 0.55, child: results),
        // GIPHY attribution (required by GIPHY ToS)
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            DabblerSpacing.space4,
            DabblerSpacing.space1,
            DabblerSpacing.space4,
            DabblerSpacing.space2,
          ),
          child: Center(
            child: DabblerText(
              l10n.composer_gif_attribution,
              style: DabblerType.caption2,
              tone: DabblerTextTone.secondary,
            ),
          ),
        ),
      ],
    );
  }
}

abstract final class GifPickerKeys {
  static const offline = ValueKey<String>('gif-picker-offline');
  static const unavailable = ValueKey<String>('gif-picker-unavailable');
}
