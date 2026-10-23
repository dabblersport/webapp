import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'places_ui_kit_experiment.dart';

/// KAN-629: iOS host for the official Places UI Kit Place Details Compact
/// view, shown through a Flutter UiKitView in the venue-card cover slot.
///
/// The key is read from a `--dart-define=PLACES_IOS_KEY=...` value that the
/// developer injects locally from the Keychain; it is never in source.
const String kPlacesIosKey = String.fromEnvironment('PLACES_IOS_KEY');

const MethodChannel kPlacesChannel = MethodChannel('dabbler/places_experiment');

/// Intrinsic size the native view asked for, by Place ID.
final ValueNotifier<Map<String, Size>> placesIntrinsics =
    ValueNotifier<Map<String, Size>>(const <String, Size>{});

class IosPlacesUiKitHost implements PlacesUiKitHost {
  IosPlacesUiKitHost({this.horizontal = false, this.photoOnly = false});

  final bool horizontal;
  final bool photoOnly;

  /// Initialises the native SDK. Only called by the experiment harness (or an
  /// explicitly enabled development build); flag off never reaches it.
  static Future<Map<Object?, Object?>?> start() async {
    kPlacesChannel.setMethodCallHandler((call) async {
      if (call.method == 'intrinsic') {
        final a = Map<String, Object?>.from(call.arguments as Map);
        placesIntrinsics.value = {
          ...placesIntrinsics.value,
          a['placeId'] as String: Size(
            (a['width'] as num).toDouble(),
            (a['height'] as num).toDouble(),
          ),
        };
      }
      return null;
    });
    return kPlacesChannel.invokeMapMethod<Object?, Object?>('configure', {
      'apiKey': kPlacesIosKey,
    });
  }

  @override
  Widget? buildCover(
    String placeId, {
    required double height,
    required Widget fallback,
  }) {
    if (defaultTargetPlatform != TargetPlatform.iOS) return null;
    return _PlacesCover(
      placeId: placeId,
      horizontal: horizontal,
      photoOnly: photoOnly,
      fallback: fallback,
    );
  }
}

/// One card instance is one native creation and one billable load. The
/// reservation is made here, once per State, never per rebuild.
class _PlacesCover extends StatefulWidget {
  const _PlacesCover({
    required this.placeId,
    required this.horizontal,
    required this.photoOnly,
    required this.fallback,
  });

  final String placeId;
  final bool horizontal;
  final bool photoOnly;
  final Widget fallback;

  @override
  State<_PlacesCover> createState() => _PlacesCoverState();
}

class _PlacesCoverState extends State<_PlacesCover> {
  late final Future<bool?> _reserved = kPlacesChannel.invokeMethod<bool>(
    'reserveLoad',
  );

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool?>(
      future: _reserved,
      builder: (context, snap) {
        if (snap.data != true) return widget.fallback;
        return UiKitView(
          viewType: 'dabbler/places_ui_kit',
          creationParams: <String, Object?>{
            'placeId': widget.placeId,
            'horizontal': widget.horizontal,
            'photoOnly': widget.photoOnly,
          },
          creationParamsCodec: const StandardMessageCodec(),
        );
      },
    );
  }
}
