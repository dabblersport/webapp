import 'package:dabbler/core/config/supabase_config.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'push_installation_id.dart';
import 'push_token_registrar.dart';

/// Binds this installation to the current session on the server
/// (KAN-1003, backend KAN-985 `rpc_security_register_sign_in`).
///
/// Runs on every sign-in and on start, whether or not push is allowed. The
/// server call is idempotent. A failure is logged and never thrown, so it
/// can never block sign-in.
class SecuritySignInRegistrar {
  SecuritySignInRegistrar({
    PushRpcCall? rpc,
    PushInstallationId? installationId,
    String Function()? platform,
  }) : _rpc = rpc ?? _supabaseRpc,
       _installationId = installationId ?? PushInstallationId(),
       _platform = platform ?? _currentPlatform;

  static Future<dynamic> _supabaseRpc(String fn, Map<String, dynamic> params) =>
      Supabase.instance.client.rpc(fn, params: params);

  static String _currentPlatform() =>
      pushPlatformName(isWeb: kIsWeb, platform: defaultTargetPlatform);

  final PushRpcCall _rpc;
  final PushInstallationId _installationId;
  final String Function() _platform;

  /// Whether [state] is a sign-in the server must hear about.
  static bool isSignIn(AuthState state) =>
      state.event == AuthChangeEvent.signedIn ||
      (state.event == AuthChangeEvent.initialSession && state.session != null);

  /// Registers on a sign-in [state]; does nothing otherwise.
  Future<void> onAuthState(AuthState state) async {
    if (isSignIn(state)) await register();
  }

  /// Calls the RPC. Never throws.
  Future<void> register() async {
    try {
      await _rpc(SupabaseConfig.rpcSecurityRegisterSignInFn, {
        'p_installation_id': await _installationId.read(),
        'p_platform': _platform(),
        'p_device_label': null,
      });
    } catch (e) {
      debugPrint('Security sign-in registration failed: $e');
    }
  }
}
