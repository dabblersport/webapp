import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:dabbler/features/social/presentation/widgets/post_media_carousel.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../support/render_mode.dart';

void main() {
  testWidgets('media viewer: dragging down past the threshold dismisses it',
      (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: DabblerDesignSystemTheme.withTokens(renderThemeBase()),
        home: Builder(
          builder: (context) => GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => PostMediaCarousel.openViewer(
              context,
              const ['https://example.test/a.png', 'https://example.test/b.png'],
              0,
            ),
            child: const SizedBox.expand(key: Key('open')),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('open')));
    await tester.pumpAndSettle();
    expect(find.byType(MediaViewer), findsOneWidget);
    expect(find.text('1/2'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(MediaViewer),
        matching: find.byWidgetPredicate(
          (w) => w is DabblerImage && w.fit == BoxFit.contain,
        ),
      ),
      findsWidgets,
    );

    // A short drag snaps back.
    await tester.drag(find.byType(PageView), const Offset(0, 40));
    await tester.pumpAndSettle();
    expect(find.byType(MediaViewer), findsOneWidget);

    // A long drag dismisses.
    await tester.drag(find.byType(PageView), const Offset(0, 300));
    await tester.pumpAndSettle();
    expect(find.byType(MediaViewer), findsNothing);
  });
}
