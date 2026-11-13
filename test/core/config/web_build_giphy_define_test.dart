import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// KAN-582: the GIF picker reads `GIPHY_API_KEY` from `--dart-define`
/// (`Environment.giphyApiKey`). The web build writes an empty `.env`, so a
/// build script that does not pass the define ships a picker that opens
/// "GIFs aren't available right now" without sending a request. The key is
/// optional (an unset variable passes an empty value; the picker then shows
/// its unavailable state), and its value never appears in the repository.
void main() {
  test('the Cloudflare web build passes GIPHY_API_KEY as a dart-define', () {
    final script = File('scripts/cloudflare-build.sh').readAsStringSync();
    expect(
      script,
      contains('--dart-define=GIPHY_API_KEY="\${GIPHY_API_KEY:-}"'),
    );
    // Optional: the build must not fail when the variable is not set.
    expect(script, isNot(contains('test -n "\${GIPHY_API_KEY')));
  });
}
