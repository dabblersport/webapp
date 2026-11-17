import 'package:dabbler/core/config/supabase_config.dart';
import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart'
    show DabblerMotion;
import 'package:firebase_messaging/firebase_messaging.dart'
    show AuthorizationStatus;
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'push_installation_id.dart';

/// Calls one Supabase RPC; replaceable in tests.
typedef PushRpcCall =
    Future<dynamic> Function(String fn, Map<String, dynamic> params);

/// The `p_platform` value: `'web'` on the web, else the target platform's
/// name (`android`, `iOS`, `macOS`...).
String pushPlatformName({
  required bool isWeb,
  required TargetPlatform platform,
}) => isWeb ? 'web' : platform.name;

/// The `p_os_permission` value for an OS permission status.
String? osPermissionWire(AuthorizationStatus? status) => switch (status) {
  AuthorizationStatus.authorized => 'granted',
  AuthorizationStatus.denied => 'denied',
  AuthorizationStatus.provisional => 'provisional',
  AuthorizationStatus.notDetermined || null => null,
};

const int _maxAppVersion = 64;
const int _maxLocale = 35;

String? _clip(String? value, int max) {
  if (value == null || value.isEmpty) return null;
  return value.length <= max ? value : value.substring(0, max);
}

/// The params of `rpc_register_push_token` (contract: KAN-977 comment 16406).
Map<String, dynamic> pushRegisterParams({
  required String installationId,
  required String token,
  required String platform,
  String? appVersion,
  Locale? locale,
  AuthorizationStatus? permission,
}) => {
  'p_installation_id': installationId,
  'p_token': token,
  'p_platform': platform,
  'p_app_version': _clip(appVersion, _maxAppVersion),
  'p_locale': _clip(locale?.toLanguageTag(), _maxLocale),
  'p_os_permission': osPermissionWire(permission),
};

Future<String?> _packageVersion() async {
  try {
    final info = await PackageInfo.fromPlatform().timeout(
      DabblerMotion.timeoutShort,
    );
    final version = info.version.trim();
    final build = info.buildNumber.trim();
    if (version.isEmpty) return null;
    return build.isEmpty ? version : '$version+$build';
  } catch (_) {
    return null;
  }
}

/// Registers this installation's FCM token through the notifications v2 RPCs
/// (KAN-977). Shared by the mobile and web push services.
///
/// The server call is idempotent; the registrar still skips a call whose
/// params match the last one sent for the same user, so the resume and
/// locale triggers cost nothing when nothing changed.
class PushTokenRegistrar {
  PushTokenRegistrar({
    PushRpcCall? rpc,
    String? Function()? currentUserId,
    Future<String?> Function()? appVersion,
    PushInstallationId? installationId,
  }) : _rpc = rpc ?? _supabaseRpc,
       _currentUserId = currentUserId ?? _supabaseUserId,
       _appVersion = appVersion ?? _packageVersion,
       installationId = installationId ?? PushInstallationId();

  static Future<dynamic> _supabaseRpc(String fn, Map<String, dynamic> params) =>
      Supabase.instance.client.rpc(fn, params: params);

  static String? _supabaseUserId() =>
      Supabase.instance.client.auth.currentUser?.id;

  final PushRpcCall _rpc;
  final String? Function() _currentUserId;
  final Future<String?> Function() _appVersion;
  final PushInstallationId installationId;

  Future<String?>? _appVersionRead;
  Locale? _locale;
  String? _token;
  String? _lastSent;

  /// The last FCM token handed to [register]; null after [unregister].
  String? get token => _token;

  /// The app locale sent as `p_locale`.
  Locale? get locale => _locale;

  /// Sets the app locale; true when it changed.
  bool setLocale(Locale locale) {
    if (_locale == locale) return false;
    _locale = locale;
    return true;
  }

  /// Registers [token] for this installation. Ok(null) when no user is signed
  /// in or nothing changed since the last call; otherwise the row id.
  Future<Result<String?, Failure>> register({
    required String token,
    required String platform,
    AuthorizationStatus? permission,
  }) async {
    _token = token;
    final userId = _currentUserId();
    if (userId == null) return const Ok(null);

    final Map<String, dynamic> params;
    try {
      params = pushRegisterParams(
        installationId: await installationId.read(),
        token: token,
        platform: platform,
        appVersion: await (_appVersionRead ??= _appVersion()),
        locale: _locale,
        permission: permission,
      );
    } catch (e) {
      return Err(Failure.from(e));
    }

    final key = '$userId|$params';
    if (key == _lastSent) return const Ok(null);
    return Result.guard(() async {
      final id = await _rpc(SupabaseConfig.rpcRegisterPushToken, params);
      _lastSent = key;
      return id?.toString();
    }, Failure.from);
  }

  /// Registers the last token again (permission or locale changed). Ok(null)
  /// when no token has been registered yet.
  Future<Result<String?, Failure>> resync({
    required String platform,
    AuthorizationStatus? permission,
  }) async {
    final token = _token;
    if (token == null) return const Ok(null);
    return register(token: token, platform: platform, permission: permission);
  }

  /// Removes this installation's row. Must run before `auth.signOut()`: the
  /// RPC needs `auth.uid()`. The installation id is kept.
  Future<Result<bool, Failure>> unregister() async {
    _lastSent = null;
    _token = null;
    if (_currentUserId() == null) return const Ok(false);
    return Result.guard(() async {
      final id = await installationId.read();
      final removed = await _rpc(SupabaseConfig.rpcUnregisterPushToken, {
        'p_installation_id': id,
      });
      return removed == true;
    }, Failure.from);
  }
}
