import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dabbler/features/messaging/presentation/providers/messaging_providers.dart';

/// KAN-554: the launch commit turned the messaging flags on, so the default
/// [messagingBackendConfigProvider] now selects the real Worker (or the
/// "unavailable" repository without a base URL). Tests that exercise the UI
/// and controllers against the in-memory fake pin the backend choice here, so
/// they do not depend on the committed flag values.
final Override fakeMessagingBackend = messagingBackendConfigProvider
    .overrideWithValue((messaging: false, gameChat: false, baseUrl: ''));
