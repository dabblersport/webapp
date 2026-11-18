// KAN-1003 (W2-F6): one row of the KAN-985 sign-in ledger
// (`rpc_security_sign_ins`). No IP is stored; the city is null until the
// server has a place source.

import 'package:dabbler/core/utils/instant.dart';
import 'package:flutter/foundation.dart';

/// The ledger's `state`.
enum SignInState {
  /// No notice was sent.
  known,

  /// A notice was sent and is not answered.
  newDevice,

  /// "This was me".
  confirmed,

  /// "Not me": that device was signed out.
  secured;

  static SignInState parse(Object? raw) => switch ('$raw') {
    'new' => SignInState.newDevice,
    'confirmed' => SignInState.confirmed,
    'secured' => SignInState.secured,
    _ => SignInState.known,
  };
}

/// Which security notice a review screen is about.
enum SecurityNoticeKind {
  newSignIn('security.new_signin'),
  passwordChanged('security.password_changed'),
  emailChanged('security.email_changed');

  const SecurityNoticeKind(this.key);

  /// The notification kind key.
  final String key;

  /// The short wire name used in the route (`new_signin`, ...).
  String get wire => key.substring('security.'.length);

  static SecurityNoticeKind? parse(String? raw) {
    if (raw == null) return null;
    for (final k in values) {
      if (k.key == raw || k.wire == raw) return k;
    }
    return null;
  }
}

@immutable
class SecuritySignIn {
  const SecuritySignIn({
    required this.id,
    required this.deviceLabel,
    required this.signedInAt,
    required this.state,
    this.installationId,
    this.platform,
    this.city,
    this.country,
    this.isNewDevice = false,
    this.isCurrent = false,
    this.isActive = false,
  });

  factory SecuritySignIn.fromJson(Map<String, dynamic> j) {
    String? s(String k) {
      final v = j[k];
      if (v == null) return null;
      final t = '$v'.trim();
      return t.isEmpty ? null : t;
    }

    return SecuritySignIn(
      id: '${j['id']}',
      deviceLabel: s('device_label') ?? '',
      signedInAt: parseInstantLocal(j['signed_in_at']) ?? DateTime.now(),
      state: SignInState.parse(j['state']),
      installationId: s('installation_id'),
      platform: s('platform'),
      city: s('place_city'),
      country: s('place_country'),
      isNewDevice: j['is_new_device'] == true,
      isCurrent: j['is_current'] == true,
      isActive: j['is_active'] == true,
    );
  }

  final String id;
  final String deviceLabel;
  final DateTime signedInAt;
  final SignInState state;
  final String? installationId;
  final String? platform;
  final String? city;
  final String? country;
  final bool isNewDevice;

  /// The session this app is signed in with.
  final bool isCurrent;

  /// The session still exists (the device is signed in).
  final bool isActive;

  /// "City, Country", or whichever is known; null when neither is.
  String? get place {
    final parts = <String>[
      if (city != null) city!,
      if (country != null) country!,
    ];
    return parts.isEmpty ? null : parts.join(', ');
  }

  SecuritySignIn copyWith({SignInState? state, bool? isActive}) =>
      SecuritySignIn(
        id: id,
        deviceLabel: deviceLabel,
        signedInAt: signedInAt,
        state: state ?? this.state,
        installationId: installationId,
        platform: platform,
        city: city,
        country: country,
        isNewDevice: isNewDevice,
        isCurrent: isCurrent,
        isActive: isActive ?? this.isActive,
      );
}
