import 'dart:async';
import 'dart:convert';

import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;

import 'package:dabbler/core/config/environment.dart';
import 'package:dabbler/core/widgets/composer_drawer_kit.dart';

/// Opens the GIPHY picker as a design-system sheet. [onSelected] receives the
/// chosen GIF's URL; the sheet closes itself.
Future<void> showGifPickerSheet(
  BuildContext context, {
  required ValueChanged<String> onSelected,
}) => showDabblerSheet<void>(
  context: context,
  title: 'Search GIFs',
  detent: DabblerSheetDetent.content,
  builder: (ctx) => GifPickerSheet(
    onSelected: (url) {
      Navigator.pop(ctx);
      onSelected(url);
    },
  ),
);

// GIF PICKER SHEET (GIPHY)

class GifPickerSheet extends StatefulWidget {
  const GifPickerSheet({super.key, required this.onSelected});

  final ValueChanged<String> onSelected;

  @override
  State<GifPickerSheet> createState() => _GifPickerSheetState();
}

class _GifPickerSheetState extends State<GifPickerSheet> {
  static const _baseUrl = 'https://api.giphy.com/v1/gifs';

  final _searchController = TextEditingController();
  Timer? _debounce;
  List<Map<String, dynamic>> _results = [];
  bool _loading = false;
  String? _error;
  int _offset = 0;
  bool _hasMore = true;
  String _apiKey = '';

  @override
  void initState() {
    super.initState();
    _apiKey = Environment.giphyApiKey;
    if (_apiKey.isEmpty) {
      _error = 'GIPHY API key not configured';
      return;
    }
    _loadTrending();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTrending() async {
    setState(() {
      _loading = true;
      _error = null;
      _offset = 0;
      _hasMore = true;
    });
    try {
      final uri = Uri.parse('$_baseUrl/trending').replace(
        queryParameters: {
          'api_key': _apiKey,
          'limit': '30',
          'offset': '0',
          'rating': 'pg-13',
          'bundle': 'messaging_non_clips',
        },
      );
      final response = await http.get(uri);
      if (!mounted) return;
      if (response.statusCode != 200) {
        setState(() {
          _loading = false;
          _error = 'Failed to load GIFs';
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
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Failed to load GIFs';
      });
    }
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      _loadTrending();
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _offset = 0;
      _hasMore = true;
    });
    try {
      final uri = Uri.parse('$_baseUrl/search').replace(
        queryParameters: {
          'api_key': _apiKey,
          'q': query,
          'limit': '30',
          'offset': '0',
          'rating': 'pg-13',
          'bundle': 'messaging_non_clips',
        },
      );
      final response = await http.get(uri);
      if (!mounted) return;
      if (response.statusCode != 200) {
        setState(() {
          _loading = false;
          _error = 'Search failed';
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
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Search failed';
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore) return;
    final query = _searchController.text.trim();
    setState(() => _loading = true);
    try {
      final endpoint = query.isEmpty ? 'trending' : 'search';
      final params = <String, String>{
        'api_key': _apiKey,
        'limit': '30',
        'offset': '$_offset',
        'rating': 'pg-13',
        'bundle': 'messaging_non_clips',
      };
      if (query.isNotEmpty) params['q'] = query;
      final uri = Uri.parse(
        '$_baseUrl/$endpoint',
      ).replace(queryParameters: params);
      final response = await http.get(uri);
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
    _debounce = Timer(DabblerMotion.debounceSearch, () {
      _search(value);
    });
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
    final Widget results;
    if (_error != null) {
      results = ComposerCenteredState.message(_error!, icon: 'danger');
    } else if (_loading && _results.isEmpty) {
      results = const ComposerCenteredState.loading();
    } else if (_results.isEmpty) {
      results = const ComposerCenteredState.message('No GIFs found');
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
          placeholder: 'Search GIPHY...',
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
              'Powered by GIPHY',
              style: DabblerType.caption2,
              tone: DabblerTextTone.secondary,
            ),
          ),
        ),
      ],
    );
  }
}
