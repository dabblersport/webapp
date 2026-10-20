// KAN-597: the app-association configuration must cover the same hosts and paths on both platforms, and the same
// paths the router resolves. Static checks of the committed files only: they do not prove a device opens the app.
import 'dart:convert';
import 'dart:io';

import 'package:dabbler/utils/helpers/deep_links.dart';
import 'package:flutter_test/flutter_test.dart';

const _hosts = ['app.dabbler.pro', 'alpha.dabbler.pro'];

void main() {
  final paths = DeepLinks.entrySegment.values.toList();

  test('the iOS associated-domains list both hosts (debug and release)', () {
    for (final f in [
      'ios/Runner/Runner.entitlements',
      'ios/Runner/Runner-Release.entitlements',
    ]) {
      final text = File(f).readAsStringSync();
      for (final h in _hosts) {
        expect(text, contains('applinks:$h'), reason: '$f lacks $h');
      }
    }
  });

  test('the Android app-link filter covers both hosts and every path', () {
    final text = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    final start = text.indexOf('android:autoVerify="true"');
    expect(start, greaterThan(0));
    final filter = text.substring(
      start,
      text.indexOf('</intent-filter>', start),
    );
    expect(filter, contains('android:scheme="https"'));
    for (final h in _hosts) {
      expect(filter, contains('android:host="$h"'), reason: h);
    }
    for (final p in paths) {
      expect(filter, contains('android:pathPrefix="/$p/"'), reason: p);
    }
  });

  test('the iOS association file claims every path the router resolves', () {
    final json =
        jsonDecode(
              File(
                'web/.well-known/apple-app-site-association',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    final details = (json['applinks'] as Map)['details'] as List;
    final components = [
      for (final d in details) ...(d as Map)['components'] as List,
    ];
    final claimed = [for (final c in components) (c as Map)['/'] as String];
    for (final p in paths) {
      expect(claimed, contains('/$p/*'), reason: p);
    }
  });

  test('the Android asset-links file names the app package', () {
    final json =
        jsonDecode(File('web/.well-known/assetlinks.json').readAsStringSync())
            as List;
    final packages = [
      for (final e in json) ((e as Map)['target'] as Map)['package_name'],
    ];
    expect(packages, contains('com.dabbler.dabblerapp'));
  });
}
