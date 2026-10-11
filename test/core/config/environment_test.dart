import 'dart:io';

import 'package:dabbler/core/config/environment.dart';
import 'package:flutter_test/flutter_test.dart';

/// KAN-491: configuration resolution for plain `flutter run`. Compile-time
/// `--dart-define` values win; otherwise the gitignored local file is read in
/// non-release builds; otherwise a clear, actionable diagnostic. Test values
/// here are fake placeholders.
void main() {
  const String url = 'https://example.invalid';
  const String all =
      'SUPABASE_URL=$url\nSUPABASE_ANON_KEY=fake-anon\nAPP_NAME=fake-app\n'
      'ENVIRONMENT=development\n';

  group('precedence', () {
    test('a compile-time value wins over the local value', () {
      expect(Environment.resolve('from-define', 'from-local'), 'from-define');
    });
    test('the local value is used when no compile-time value is given', () {
      expect(Environment.resolve('', 'from-local'), 'from-local');
    });
    test('empty when neither is given', () {
      expect(Environment.resolve('', null), '');
    });
  });

  group('load', () {
    test('reads the local config asset when no defines are supplied', () async {
      String? asked;
      await Environment.load(
        assetLoader: (String path) async {
          asked = path;
          return all;
        },
      );
      expect(asked, Environment.localConfigAsset);
      expect(asked, 'assets/config/local.env');
      expect(Environment.supabaseUrl, url);
      expect(Environment.supabaseAnonKey, 'fake-anon');
      expect(Environment.appName, 'fake-app');
    });

    test('missing local setup gives an actionable diagnostic', () async {
      await expectLater(
        Environment.load(
          assetLoader: (String path) async => throw StateError('no such asset'),
        ),
        throwsA(
          isA<EnvironmentConfigException>()
              .having(
                (e) => e.missing,
                'missing',
                containsAll(<String>[
                  'SUPABASE_URL',
                  'SUPABASE_ANON_KEY',
                  'APP_NAME',
                ]),
              )
              .having(
                (e) => e.toString(),
                'message',
                allOf(
                  contains('scripts/setup_local_env.sh'),
                  contains('docs/LOCAL_RUN.md'),
                  contains('flutter run -d <device-id>'),
                ),
              ),
        ),
      );
    });

    test('a partial local file names exactly what is missing', () async {
      await expectLater(
        Environment.load(
          assetLoader: (String path) async => 'SUPABASE_URL=$url\n',
        ),
        throwsA(
          isA<EnvironmentConfigException>().having(
            (e) => e.missing,
            'missing',
            <String>['SUPABASE_ANON_KEY', 'APP_NAME'],
          ),
        ),
      );
    });

    test('the diagnostic never contains configuration values', () async {
      try {
        await Environment.load(
          assetLoader: (String p) async => 'SUPABASE_URL=$url\n',
        );
        fail('expected a diagnostic');
      } on EnvironmentConfigException catch (e) {
        expect(e.toString().contains(url), isFalse);
      }
    });
  });

  group('scripts/setup_local_env.sh', () {
    final File target = File('assets/config/local.env');
    File? aside;
    late Directory tmp;

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('setup_env_');
      if (target.existsSync()) {
        aside = File('${tmp.path}/aside')
          ..writeAsBytesSync(target.readAsBytesSync());
        target.deleteSync();
      }
    });
    tearDown(() {
      if (target.existsSync()) target.deleteSync();
      if (aside != null) target.writeAsBytesSync(aside!.readAsBytesSync());
      aside = null;
      tmp.deleteSync(recursive: true);
    });

    ProcessResult run(List<String> args) => Process.runSync('bash', <String>[
      'scripts/setup_local_env.sh',
      ...args,
    ]);

    test('writes the local selection from a file and prints names only', () {
      final File src = File('${tmp.path}/sel.env')..writeAsStringSync(all);
      final ProcessResult r = run(<String>['--from', src.path]);
      expect(r.exitCode, 0, reason: '${r.stdout}${r.stderr}');
      expect(target.readAsStringSync(), all);
      expect('${r.stdout}${r.stderr}'.contains('fake-anon'), isFalse);
      expect(r.stdout, contains('ok       SUPABASE_URL'));
      expect(run(<String>['--check']).exitCode, 0);
    });

    test('refuses a source with required keys missing', () {
      final File src = File('${tmp.path}/bad.env')
        ..writeAsStringSync('SUPABASE_URL=$url\n');
      final ProcessResult r = run(<String>['--from', src.path]);
      expect(r.exitCode, isNot(0));
      expect(r.stdout, contains('MISSING  SUPABASE_ANON_KEY'));
      expect(target.existsSync(), isFalse);
    });

    test('only client-safe keys are copied; any other key is dropped', () {
      final File src = File('${tmp.path}/mixed.env')
        ..writeAsStringSync(
          '$all'
          'GOOGLE_WEB_CLIENT_ID=fake-google\n'
          'SECRET_KEY=fake-secret-value\n'
          'SUPABASE_SERVICE_ROLE_KEY=fake-service-role\n'
          'export DB_PASSWORD=fake-password\n',
        );
      final ProcessResult r = run(<String>['--from', src.path]);
      expect(r.exitCode, 0, reason: '${r.stdout}${r.stderr}');
      final String copied = target.readAsStringSync();
      expect(copied, contains('SUPABASE_URL='));
      expect(copied, contains('GOOGLE_WEB_CLIENT_ID=fake-google'));
      for (final String leaked in <String>[
        'SECRET_KEY',
        'fake-secret-value',
        'SUPABASE_SERVICE_ROLE_KEY',
        'fake-service-role',
        'DB_PASSWORD',
        'fake-password',
      ]) {
        expect(copied.contains(leaked), isFalse, reason: leaked);
      }
      final String out = '${r.stdout}';
      expect(out, contains('Dropped (not copied):'));
      expect(out, contains('SECRET_KEY'));
      expect(out, contains('DB_PASSWORD'));
      // Names only: never a value.
      expect(out.contains('fake-'), isFalse);
    });

    test('--clear removes the selection', () {
      File('${tmp.path}/sel.env').writeAsStringSync(all);
      run(<String>['--from', '${tmp.path}/sel.env']);
      expect(run(<String>['--clear']).exitCode, 0);
      expect(target.existsSync(), isFalse);
      expect(run(<String>['--check']).exitCode, isNot(0));
    });
  });

  group('scripts/check_no_local_env.sh (release/CI guard)', () {
    final File target = File('assets/config/local.env');
    late Directory tmp;
    File? aside;
    setUp(() {
      tmp = Directory.systemTemp.createTempSync('guard_env_');
      if (target.existsSync()) {
        aside = File('${tmp.path}/aside')
          ..writeAsBytesSync(target.readAsBytesSync());
        target.deleteSync();
      }
    });
    tearDown(() {
      if (target.existsSync()) target.deleteSync();
      if (aside != null) target.writeAsBytesSync(aside!.readAsBytesSync());
      aside = null;
      tmp.deleteSync(recursive: true);
    });

    test('passes on a clean tree and fails when local.env exists', () {
      ProcessResult guard() =>
          Process.runSync('bash', <String>['scripts/check_no_local_env.sh']);
      expect(guard().exitCode, 0);
      target.writeAsStringSync('SUPABASE_URL=https://example.invalid\n');
      final ProcessResult r = guard();
      expect(r.exitCode, isNot(0));
      expect('${r.stderr}', contains('assets/config/local.env'));
      expect('${r.stderr}', contains('--dart-define'));
      expect('${r.stderr}'.contains('example.invalid'), isFalse);
    });

    test('the Cloudflare build runs the guard first', () {
      final String build = File(
        'scripts/cloudflare-build.sh',
      ).readAsStringSync();
      expect(build, contains('scripts/check_no_local_env.sh'));
      expect(
        build.indexOf('check_no_local_env'),
        lessThan(build.indexOf('flutter build web')),
      );
    });
  });
}
