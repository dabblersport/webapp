import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'render_mode.dart';

void main() {
  test('render output root is writable and honors SHOTS_ROOT', () async {
    const configuredRoot = String.fromEnvironment('SHOTS_ROOT');
    expect(
      kShotsRoot,
      const bool.hasEnvironment('SHOTS_ROOT')
          ? configuredRoot
          : 'build/render-shots',
    );
    final directory = await Directory(kShotsRoot).create(recursive: true);
    final probe = await File('${directory.path}/.write-probe').create();
    await probe.delete();
  });
}
