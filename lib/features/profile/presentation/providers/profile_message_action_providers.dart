import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dabbler/core/config/feature_flags.dart';

/// The two flags the profile Message action reads (KAN-557). Defaults to the
/// real compile-time flags (both false); a test overrides the provider instead
/// of flipping a const.
typedef ProfileMessageFlags = ({bool messaging, bool direct});

final profileMessageFlagsProvider = Provider<ProfileMessageFlags>(
  (ref) => (
    messaging: FeatureFlags.messaging,
    direct: FeatureFlags.enableMessagingDirect,
  ),
);

/// Whether the Message action may exist at all: `messaging` is the master
/// switch and `enableMessagingDirect` the sub-flag.
bool profileMessageActionEnabled(ProfileMessageFlags flags) =>
    flags.messaging && flags.direct;
