import 'dart:io';
import 'dart:ui' as ui;

import 'package:dabbler/features/home/presentation/widgets/notification_permission_drawer.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/render_mode.dart';

/// Renders the notification-permission sheet exactly as `home_screen.dart`
/// opens it, LTR and RTL, and asserts it draws ONE sheet surface (KAN-434).
///
/// The one-surface assertion: inside the [DabblerSheet] there is exactly one
/// [DecoratedBox] whose decoration paints a fill with a rounded border (the
/// panel itself); the sheet's content adds no [Card], [Material],
/// [PhysicalModel], [Ink] or second filled+rounded [DecoratedBox].
const String _shotsDir = String.fromEnvironment(
  'SHEETS_SHOTS_DIR',
  defaultValue: '$kShotsRoot/sheets',
);

class _Host extends StatefulWidget {
  const _Host();

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showDabblerSheet<bool>(
        context: context,
        detent: DabblerSheetDetent.content,
        builder: (BuildContext context) => NotificationPermissionDrawer(
          onEnableNotifications: () {},
          onRemindLater: () {},
          onNoThanks: () {},
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) => const DabblerPage(body: SizedBox());
}

Future<void> _shoot(WidgetTester tester, Key key, String name) async {
  await tester.runAsync(() async {
    final RenderRepaintBoundary boundary =
        tester.renderObject(find.byKey(key)) as RenderRepaintBoundary;
    final ui.Image image = await boundary.toImage(pixelRatio: 2);
    final ByteData? png = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    Directory(_shotsDir).createSync(recursive: true);
    File('$_shotsDir/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
  });
}

/// Surfaces inside [root]: boxes that paint a fill AND a rounded corner and
/// are panel-sized (over 100 logical px each way). Handles, chips, tiles and
/// buttons are filled and rounded too but are never that large.
List<Widget> _panels(WidgetTester tester, Finder root) {
  final List<Widget> out = <Widget>[];
  for (final Element e
      in find
          .descendant(of: root, matching: find.byType(DecoratedBox))
          .evaluate()) {
    final Decoration d = (e.widget as DecoratedBox).decoration;
    if (d is BoxDecoration && d.color != null && d.borderRadius != null) {
      final Size size = tester.getSize(find.byWidget(e.widget));
      if (size.width > 100 && size.height > 100) out.add(e.widget);
    }
  }
  return out;
}

void main() {
  setUpAll(() async {
    await loadRenderFonts();
  });

  final TargetPlatformVariant desktop = TargetPlatformVariant.only(
    TargetPlatform.macOS,
  );

  for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
    final String dir = locale.languageCode == 'ar' ? 'rtl' : 'ltr';
    testWidgets('notification sheet renders one surface - $dir', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      const Key key = Key('shot');
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          builder: (BuildContext context, Widget? child) =>
              RepaintBoundary(key: key, child: child),
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: DabblerDesignSystemTheme.withFonts(
            DabblerDesignSystemTheme.withTokens(renderThemeBase()),
            locale: locale,
          ),
          home: const _Host(),
        ),
      );
      for (int i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await settleImages(tester);
      expect(tester.takeException(), isNull);

      await _shoot(tester, key, 'sheets-notification-drawer-$dir');

      final Finder sheet = find.byType(DabblerSheet);
      expect(sheet, findsOneWidget);
      // One panel: the sheet's own surface and nothing in its content.
      expect(_panels(tester, sheet), hasLength(1), reason: 'one surface');
      final Finder content = find.byType(NotificationPermissionDrawer);
      expect(_panels(tester, content), isEmpty, reason: 'no nested panel');
      for (final Type t in <Type>[Card, Material, PhysicalModel, Ink]) {
        expect(
          find.descendant(of: content, matching: find.byType(t)),
          findsNothing,
          reason: '$t inside the sheet content',
        );
      }
      // The content hosts no padding of its own: the first child sits at the
      // sheet body's inset, not that inset plus the content's own.
      final Rect panel = tester.getRect(find.byType(ClipRRect).first);
      final Rect tile = tester.getRect(find.byType(DabblerIconTile));
      final double inset = locale.languageCode == 'ar'
          ? panel.right - tile.right
          : tile.left - panel.left;
      expect(inset, DabblerSpacing.space6);
    }, variant: desktop);
  }
}
