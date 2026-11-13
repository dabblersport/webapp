import 'package:dabbler/features/messaging/data/receipts_transport.dart';
import 'package:dabbler/features/messaging/domain/receipt_summary.dart';
import 'package:dabbler/features/messaging/presentation/providers/receipts_providers.dart';
import 'package:dabbler/features/messaging/presentation/widgets/message_info_sheet.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/render_mode.dart';

/// KAN-620: the receipts drawer (design frames 28-30, section 11 and 15),
/// English/light and Arabic/dark, with long names, times, the recipients of
/// that message only, closing, and reduced motion.
class _Transport implements ReceiptsTransport {
  @override
  Future<bool> ack(String c, ReceiptState s, int seq) async => true;

  @override
  Future<Map<int, ReceiptCounts>> summaries(String c, List<int> seqs) async =>
      const {};

  @override
  Future<List<RecipientReceipt>?> recipients(String c, int seq) async => [
    RecipientReceipt(
      userId: 'u1',
      level: ReceiptLevel.seen,
      updatedAt: DateTime(2026, 3, 3, 9, 5),
    ),
    RecipientReceipt(
      userId: 'u2',
      level: ReceiptLevel.delivered,
      updatedAt: DateTime(2026, 3, 3, 9, 2),
    ),
    const RecipientReceipt(userId: 'u3', level: ReceiptLevel.sent),
  ];
}

typedef _Variant = ({String name, Locale locale, Brightness brightness});

const List<_Variant> _variants = [
  (name: 'en-light', locale: Locale('en'), brightness: Brightness.light),
  (name: 'ar-dark', locale: Locale('ar'), brightness: Brightness.dark),
];

const String _longName =
    'Abdulrahman bin Mohammed bin Salman Al Rashid Al Maktoum II';

Widget _app(_Variant v) => ProviderScope(
  overrides: [
    receiptsTransportProvider.overrideWithValue(_Transport()),
    receiptPersonNameProvider.overrideWithValue(
      (id) async => {'u1': _longName, 'u2': 'Omar', 'u3': 'Lina'}[id] ?? '',
    ),
  ],
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    locale: v.locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: DabblerDesignSystemTheme.withFonts(
      DabblerDesignSystemTheme.withTokens(
        v.brightness == Brightness.dark ? ThemeData.dark() : ThemeData.light(),
      ),
      locale: v.locale,
    ),
    home: Scaffold(
      body: Consumer(
        builder: (context, ref, _) => Center(
          child: TextButton(
            key: const ValueKey('open'),
            onPressed: () => showMessageInfo(
              context: context,
              ref: ref,
              conversationId: 'c1',
              seq: 5,
              preview: 'see you at the court at six',
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  ),
);

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('open')));
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUpAll(() async {
    await loadRenderFonts();
  });

  setUp(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = const Size(390 * 3, 844 * 3);
    view.devicePixelRatio = 3;
  });

  for (final v in _variants) {
    final l10n = lookupAppLocalizations(v.locale);
    group('[${v.name}] receipts drawer', () {
      testWidgets('shows the message, the three lists and only its own '
          'recipients, with a time per person', (tester) async {
        await tester.pumpWidget(_app(v));
        await _open(tester);
        expect(find.byType(DabblerReceiptsSheet), findsOneWidget);
        expect(find.text(l10n.messaging_receipts_title), findsOneWidget);
        expect(find.text('see you at the court at six'), findsOneWidget);
        expect(
          find.textContaining(l10n.messaging_receipts_seen_by),
          findsWidgets,
        );
        expect(
          find.textContaining(l10n.messaging_receipts_delivered_to),
          findsWidgets,
        );
        expect(
          find.textContaining(l10n.messaging_receipts_not_yet),
          findsWidgets,
        );
        // Exactly the three recipients of this message: nobody else.
        expect(find.text('Omar'), findsOneWidget);
        expect(find.text('Lina'), findsOneWidget);
        expect(find.textContaining('Abdulrahman'), findsOneWidget);
        // The seen and delivered people carry a time; the one it has not
        // reached does not.
        final sheet = tester.widget<DabblerReceiptsSheet>(
          find.byType(DabblerReceiptsSheet),
        );
        expect(sheet.groups, hasLength(3));
        expect(sheet.groups[0].people.single.time, isNotEmpty);
        expect(sheet.groups[1].people.single.time, isNotEmpty);
        expect(sheet.groups[2].people.single.time, isNull);
        expect(tester.takeException(), isNull);
      });

      testWidgets('a long name stays on one line and the time is never cut', (
        tester,
      ) async {
        await tester.pumpWidget(_app(v));
        await _open(tester);
        final name = find.textContaining('Abdulrahman');
        final oneLine = tester.getSize(find.text('Omar')).height;
        expect(tester.getSize(name).height, oneLine);
        final sheet = tester.widget<DabblerReceiptsSheet>(
          find.byType(DabblerReceiptsSheet),
        );
        final time = sheet.groups[0].people.single.time!;
        final timeText = tester.widget<Text>(find.text(time));
        expect(timeText.overflow, isNot(TextOverflow.ellipsis));
        expect(timeText.maxLines, anyOf(isNull, 1));
        expect(tester.getRect(find.text(time)).right, lessThanOrEqualTo(390));
        expect(tester.takeException(), isNull);
      });

      testWidgets('dragging down closes it', (tester) async {
        await tester.pumpWidget(_app(v));
        await _open(tester);
        // From the handle row, the 45 px strip above the title.
        final title = tester.getTopLeft(
          find.text(l10n.messaging_receipts_title),
        );
        final handle = Offset(195, title.dy - 40);
        await tester.flingFrom(handle, const Offset(0, 700), 3000);
        for (var i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(find.byType(DabblerReceiptsSheet), findsNothing);
      });

      testWidgets('tapping the backdrop closes it', (tester) async {
        await tester.pumpWidget(_app(v));
        await _open(tester);
        await tester.tapAt(const Offset(195, 20));
        for (var i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(find.byType(DabblerReceiptsSheet), findsNothing);
      });
    });
  }

  testWidgets('reduced motion: the drawer opens without a slide', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpWidget(_app(_variants.first));
    await tester.tap(find.byKey(const ValueKey('open')));
    // Let the recipients load, then one frame: the sheet is already in place.
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
    final top = tester.getTopLeft(find.byType(DabblerReceiptsSheet)).dy;
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.getTopLeft(find.byType(DabblerReceiptsSheet)).dy, top);
    expect(tester.takeException(), isNull);
  });
}
