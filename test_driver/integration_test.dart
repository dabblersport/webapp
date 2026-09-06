// Driver for running integration_test/ under `flutter drive` on the web.
//
// The iOS path (`flutter test integration_test/ -d <udid>`) does not use this
// file; only the browser path does, because web integration tests go through
// chromedriver. See scripts/qa.sh -d chrome.

import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver();
