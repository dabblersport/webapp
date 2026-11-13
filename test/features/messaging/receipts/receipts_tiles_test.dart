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

/// KAN-614: the Message info stat tiles read "All" / "Nobody" (EN) and
/// "الجميع" / "لا أحد" (AR) where a bare count reads worse. Counting and
/// states are the Worker's and untouched; only the tile value changes.
class _Transport implements ReceiptsTransport {
  _Transport(this.people);

  final List<RecipientReceipt> people;

  @override
  Future<bool> ack(String c, ReceiptState s, int seq) async => true;

  @override
  Future<Map<int, ReceiptCounts>> summaries(String c, List<int> seqs) async =>
      const {};

  @override
  Future<List<RecipientReceipt>?> recipients(String c, int seq) async => people;
}

List<RecipientReceipt> _people(int seen, int delivered, int notYet) => [
  for (var i = 0; i < seen; i++)
    RecipientReceipt(
      userId: 's$i',
      level: ReceiptLevel.seen,
      updatedAt: DateTime(2026, 3, 3, 9, 5),
    ),
  for (var i = 0; i < delivered; i++)
    RecipientReceipt(
      userId: 'd$i',
      level: ReceiptLevel.delivered,
      updatedAt: DateTime(2026, 3, 3, 9, 2),
    ),
  for (var i = 0; i < notYet; i++)
    RecipientReceipt(userId: 'n$i', level: ReceiptLevel.sent),
];

Future<void> _open(
  WidgetTester tester,
  List<RecipientReceipt> people, {
  Locale locale = const Locale('en'),
  bool dark = false,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        receiptsTransportProvider.overrideWithValue(_Transport(people)),
        receiptPersonNameProvider.overrideWithValue((id) async => 'P $id'),
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: DabblerDesignSystemTheme.withFonts(
          DabblerDesignSystemTheme.withTokens(
            dark ? ThemeData.dark() : ThemeData.light(),
          ),
          locale: locale,
        ),
        home: Consumer(
          builder: (context, ref, _) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => showMessageInfo(
                  context: context,
                  ref: ref,
                  conversationId: 'c1',
                  seq: 1,
                  preview: 'hello',
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

String _tile(WidgetTester tester, int i) {
  final tile = find.byKey(DabblerReceiptsSheet.tileKeyAt(i));
  return tester
      .widgetList<Text>(find.descendant(of: tile, matching: find.byType(Text)))
      .first
      .data!;
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

  group('Message info tiles (KAN-614), English light', () {
    testWidgets('3 recipients, none read: 0 / 0 / 3', (tester) async {
      await _open(tester, _people(0, 0, 3));
      expect([for (var i = 0; i < 3; i++) _tile(tester, i)], ['0', '0', '3']);
    });

    testWidgets('all seen: All / 0 / Nobody', (tester) async {
      await _open(tester, _people(3, 0, 0));
      expect(
        [for (var i = 0; i < 3; i++) _tile(tester, i)],
        ['All', '0', 'Nobody'],
      );
      // Headings are unchanged.
      expect(find.text('Seen by · 3'), findsOneWidget);
    });

    testWidgets('all delivered, none seen: 0 / All / Nobody', (tester) async {
      await _open(tester, _people(0, 3, 0));
      expect(
        [for (var i = 0; i < 3; i++) _tile(tester, i)],
        ['0', 'All', 'Nobody'],
      );
    });

    testWidgets('mixed, 2 seen and 1 not yet: 2 / 0 / 1', (tester) async {
      await _open(tester, _people(2, 0, 1));
      expect([for (var i = 0; i < 3; i++) _tile(tester, i)], ['2', '0', '1']);
    });

    testWidgets('single recipient seen: All / 0 / Nobody', (tester) async {
      await _open(tester, _people(1, 0, 0));
      expect(
        [for (var i = 0; i < 3; i++) _tile(tester, i)],
        ['All', '0', 'Nobody'],
      );
    });

    testWidgets('single recipient delivered only: 0 / All / Nobody', (
      tester,
    ) async {
      await _open(tester, _people(0, 1, 0));
      expect(
        [for (var i = 0; i < 3; i++) _tile(tester, i)],
        ['0', 'All', 'Nobody'],
      );
    });
  });

  testWidgets('Arabic in RTL and dark: الجميع / لا أحد', (tester) async {
    final handle = tester.ensureSemantics();
    await _open(
      tester,
      _people(1, 0, 0),
      locale: const Locale('ar'),
      dark: true,
    );
    expect(
      [for (var i = 0; i < 3; i++) _tile(tester, i)],
      ['الجميع', '0', 'لا أحد'],
    );
    expect(find.bySemanticsLabel('شوهدت: الجميع'), findsOneWidget);
    expect(find.bySemanticsLabel('لم تصل: لا أحد'), findsOneWidget);
    expect(
      Directionality.of(tester.element(find.byType(DabblerReceiptsSheet))),
      TextDirection.rtl,
    );
    expect(tester.takeException(), isNull);
    handle.dispose();
  });
}
