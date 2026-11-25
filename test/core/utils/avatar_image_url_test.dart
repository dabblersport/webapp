import 'package:dabbler/core/utils/avatar_url_resolver.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// KAN-1043: a `ds:` avatar is a portrait seed, never a URL. It must never
// reach the network image loader (the browser fetched `ds:profile:...`,
// which failed with CORS and broke the enforced CSP).
void main() {
  const ds = 'ds:profile:p-1:user:u-1';

  test('avatarImageUrl drops ds: references and blanks', () {
    expect(avatarImageUrl(ds), isNull);
    expect(avatarImageUrl('  $ds '), isNull);
    expect(avatarImageUrl(''), isNull);
    expect(avatarImageUrl(null), isNull);
    expect(
      avatarImageUrl('https://example.com/a.png'),
      'https://example.com/a.png',
    );
  });

  Future<void> pump(WidgetTester tester, String? url) => tester.pumpWidget(
    MaterialApp(
      theme: DabblerDesignSystemTheme.withTokens(ThemeData.light()),
      home: Scaffold(
        body: DabblerAvatar(seed: 'x', imageUrl: url),
      ),
    ),
  );
  final networkImage = find.byWidgetPredicate(
    (w) => w is Image && w.image is NetworkImage,
  );

  testWidgets('a raw ds: value would reach Image.network (the bug)', (
    tester,
  ) async {
    await pump(tester, ds);
    expect(networkImage, findsOneWidget);
  });

  testWidgets('a ds: value through avatarImageUrl builds no Image.network', (
    tester,
  ) async {
    await pump(tester, avatarImageUrl(ds));
    expect(find.byType(DabblerAvatar), findsOneWidget);
    expect(networkImage, findsNothing);
  });
}
