// KAN-1005: the Live Activity bridge on iOS and Android, over the channels in
// CHANNEL_CONTRACT.md. Any other dart:io platform gets the stub.

import 'dart:io' show Platform;

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';

import 'live_activity_service.dart';
import 'live_activity_service_stub.dart';

LiveActivityService createLiveActivityService() =>
    (Platform.isIOS || Platform.isAndroid)
    ? ChannelLiveActivityService()
    : const StubLiveActivityService();

class ChannelLiveActivityService implements LiveActivityService {
  ChannelLiveActivityService({MethodChannel? methods, EventChannel? events})
    : _methods = methods ?? const MethodChannel(methodChannelName),
      _events = events ?? const EventChannel(eventChannelName);

  static const String methodChannelName = 'pro.dabbler/live_activity';
  static const String eventChannelName = 'pro.dabbler/live_activity/events';

  final MethodChannel _methods;
  final EventChannel _events;
  Stream<LiveActivityEvent>? _stream;

  /// The app's chosen language, the key the locale provider and the Android
  /// half read (CHANNEL_CONTRACT.md `lang`). Null when none is chosen: the
  /// native side then falls back to the device language.
  static Future<String?> appLang() async {
    try {
      final v = (await SharedPreferences.getInstance()).getString(
        'mock_language',
      );
      return (v == 'en' || v == 'ar') ? v : null;
    } catch (_) {
      return null;
    }
  }

  /// [map] with `lang` added when it has none and a language is chosen.
  static Map<String, Object?> withLang(
    Map<String, Object?> map,
    String? lang,
  ) => (lang == null || map.containsKey('lang')) ? map : {...map, 'lang': lang};

  Future<Result<T, Failure>> _call<T>(Future<T> Function() body) =>
      Result.guard(body, (e) {
        if (e is MissingPluginException) return liveActivityUnsupported;
        return liveActivityFailure(e);
      });

  @override
  Future<bool> isSupported() async => (await capabilities()).supported;

  @override
  Future<LiveActivityCapabilities> capabilities() async {
    final r = await _call(
      () => _methods.invokeMapMethod<Object?, Object?>('getCapabilities'),
    );
    return r.fold(
      (_) => LiveActivityCapabilities.unsupported,
      LiveActivityCapabilities.fromMap,
    );
  }

  @override
  Future<Result<LiveActivityStarted, Failure>> start({
    required String sessionId,
    required LiveActivityContent content,
  }) => _call(() async {
    final lang = await appLang();
    final m = await _methods.invokeMapMethod<Object?, Object?>('start', {
      'session_id': sessionId,
      'attributes': withLang(content.attributes, lang),
      'content': withLang(content.raw, lang),
    });
    final started = LiveActivityStarted.fromMap(m);
    if (started == null) {
      throw PlatformException(
        code: LiveActivityErrorCode.internal,
        message: 'start returned no activity_id',
      );
    }
    return started;
  });

  @override
  Future<Result<Unit, Failure>> update({
    required String sessionId,
    required String activityId,
    required LiveActivityContent content,
  }) => _call(() async {
    final lang = await appLang();
    await _methods.invokeMethod<void>('update', {
      'session_id': sessionId,
      'activity_id': activityId,
      'content': withLang(content.raw, lang),
    });
    return const Unit();
  });

  @override
  Future<Result<Unit, Failure>> end({
    required String sessionId,
    required String activityId,
    LiveActivityContent? content,
    DateTime? dismissalDate,
  }) => _call(() async {
    final lang = content == null ? null : await appLang();
    await _methods.invokeMethod<void>('end', {
      'session_id': sessionId,
      'activity_id': activityId,
      if (content != null) 'content': withLang(content.raw, lang),
      if (dismissalDate != null)
        'dismissal_date': dismissalDate.millisecondsSinceEpoch ~/ 1000,
    });
    return const Unit();
  });

  @override
  Future<Result<List<LiveActivityActive>, Failure>> listActive() =>
      _call(() async {
        final list = await _methods.invokeListMethod<Object?>('listActive');
        return (list ?? const [])
            .map(LiveActivityActive.fromMap)
            .whereType<LiveActivityActive>()
            .toList();
      });

  @override
  Stream<LiveActivityEvent> get events => _stream ??= _events
      .receiveBroadcastStream()
      .handleError((Object _) {})
      .map(LiveActivityEvent.fromMap)
      .where((e) => e != null)
      .cast<LiveActivityEvent>()
      .asBroadcastStream();
}
