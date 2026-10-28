import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// KAN-640 R7: the user's IP goes only to our own `detect-country` edge
/// function (web and native alike), and that function answers browsers.
void main() {
  test('no third-party IP service is called from lib/', () {
    final hits = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final src = f.readAsStringSync();
      for (final host in [
        'ipwho.is',
        'ipapi.co',
        'api.country.is',
        'ipinfo.io',
        'ip-api.com',
        'ipify.org',
      ]) {
        if (src.contains(host)) hits.add('${f.path}: $host');
      }
    }
    expect(hits, isEmpty);
  });

  test('web and native share the one detect-country call', () {
    final src = File(
      'lib/features/auth_onboarding/data/services/'
      'ip_country_detection_service.dart',
    ).readAsStringSync();
    expect(src, contains('/functions/v1/detect-country'));
    expect(src.contains('kIsWeb'), isFalse);
  });

  test('the edge function sends the CORS headers on every response and '
      'answers OPTIONS', () {
    final src = File(
      'supabase/functions/detect-country/index.ts',
    ).readAsStringSync();
    expect(src, contains('corsHeaders(req)'));
    expect(src, contains('req.method === "OPTIONS"'));
    // Every Response carries the headers (preflight, 429, success, error).
    final responses = RegExp(r'new Response\(').allMatches(src).length;
    final withCors = RegExp(r'\.\.\.cors|headers: cors').allMatches(src).length;
    expect(responses, 4);
    expect(withCors, responses);

    final cors = File(
      'supabase/functions/detect-country/cors.ts',
    ).readAsStringSync();
    for (final h in [
      'authorization',
      'apikey',
      'content-type',
      'x-client-info',
    ]) {
      expect(cors, contains(h));
    }
    for (final o in [
      'https://app.dabbler.pro',
      'https://canary.dabbler.pro',
      'https://alpha.dabbler.pro',
      'webapp',
      'localhost',
    ]) {
      expect(cors, contains(o));
    }
  });
}
