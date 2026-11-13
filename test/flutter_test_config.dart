import 'dart:async';
import 'dart:io';

import 'package:dabbler/features/explore/presentation/widgets/listing_refresh.dart';

/// KAN-755: widget tests render the listings against a real client; keep the
/// Realtime feed off by default so no socket retry timer outlives a test.
///
/// CEO 2026-11-10: tests save no screenshots for now. Render tests still
/// capture their PNG bytes, but [_NoShotsIOOverrides] sends every such write
/// to `/dev/null` and keeps the shots folders from being created.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  listingRealtimeDisabled = true;
  // Global, not zoned: test bodies run in zones the runner forks, which do
  // not inherit a zoned override.
  IOOverrides.global = _NoShotsIOOverrides(Directory.current.path);
  await testMain();
}

final class _NoShotsIOOverrides extends IOOverrides {
  _NoShotsIOOverrides(this._root);

  final String _root;

  String _abs(String path) => path.startsWith('/') ? path : '$_root/$path';

  /// A render-test output path: under `build/test_shots/`, or a Desktop or
  /// temp folder outside the repo. Images read from the repo (including
  /// `build/unit_test_assets`), the pub cache or the SDK are left alone.
  bool _isShotPath(String path) {
    final String abs = _abs(path);
    if (abs.startsWith('$_root/')) {
      return abs.startsWith('$_root/build/test_shots/');
    }
    return abs.contains('/Desktop/') ||
        abs.startsWith(Directory.systemTemp.path);
  }

  @override
  File createFile(String path) =>
      path.toLowerCase().endsWith('.png') && _isShotPath(path)
      ? super.createFile('/dev/null')
      : super.createFile(path);

  @override
  Directory createDirectory(String path) {
    final String abs = _abs(path);
    final bool shotsDir =
        (!abs.startsWith('$_root/') && abs.contains('/Desktop/')) ||
        abs.startsWith('$_root/build/test_shots');
    return shotsDir
        ? super.createDirectory(Directory.systemTemp.path)
        : super.createDirectory(path);
  }
}
