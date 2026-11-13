// KAN-877: ActivitySearchRow is one editable, full-width DS search field with
// no filter button. It holds no search logic — only its controller — and
// reports through onChanged / onClear.

import 'package:dabbler/features/notifications/presentation/widgets/activity_search_row.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const double _screenWidth = 400;

Widget _host({
  required String query,
  ValueChanged<String>? onChanged,
  VoidCallback? onClear,
  Locale locale = const Locale('en'),
}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: DabblerDesignSystemTheme.withTokens(ThemeData()),
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: _screenWidth,
          child: ActivitySearchRow(
            query: query,
            onChanged: onChanged ?? (_) {},
            onClear: onClear ?? () {},
          ),
        ),
      ),
    ),
  );
}

Finder get _clearButton => find.byWidgetPredicate(
  (Widget w) => w is DabblerIcon && w.name == DabblerTextField.clearIconName,
);

String _fieldText(WidgetTester tester) =>
    tester.widget<EditableText>(find.byType(EditableText)).controller.text;

void main() {
  testWidgets('TC1 one full-width enabled search field, no filter button', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_host(query: ''));
    await tester.pumpAndSettle();

    expect(find.byType(DabblerSearchField), findsOneWidget);
    final DabblerSearchField field = tester.widget(
      find.byType(DabblerSearchField),
    );
    expect(field.enabled, isTrue);
    expect(field.clearable, isTrue);

    // Full width: the field spans the row minus the two space6 gutters.
    final double fieldWidth = tester
        .getSize(find.byType(DabblerSearchField))
        .width;
    expect(fieldWidth, _screenWidth - 2 * DabblerSpacing.space6);

    // The filter button is gone.
    expect(find.byType(DabblerButton), findsNothing);
    expect(
      find.byWidgetPredicate(
        (Widget w) => w is DabblerIcon && w.name == 'filter',
      ),
      findsNothing,
    );
  });

  testWidgets('TC2 typing "game" shows the text and fires onChanged', (
    WidgetTester tester,
  ) async {
    final List<String> changes = <String>[];
    await tester.pumpWidget(_host(query: '', onChanged: changes.add));

    await tester.enterText(find.byType(EditableText), 'game');
    await tester.pump();

    expect(find.text('game'), findsOneWidget);
    expect(changes.last, 'game');
  });

  testWidgets('TC3 tapping clear empties the field and fires onClear', (
    WidgetTester tester,
  ) async {
    int clears = 0;
    await tester.pumpWidget(_host(query: '', onClear: () => clears++));

    await tester.enterText(find.byType(EditableText), 'game');
    await tester.pump();
    expect(_clearButton, findsOneWidget);

    await tester.tap(_clearButton);
    await tester.pump();

    expect(_fieldText(tester), isEmpty);
    expect(clears, 1);
  });

  testWidgets('TC4 Arabic locale: Arabic hint and RTL layout', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_host(query: 'abc', locale: const Locale('ar')));
    await tester.pumpAndSettle();

    final AppLocalizations ar = await AppLocalizations.delegate.load(
      const Locale('ar'),
    );
    final BuildContext ctx = tester.element(find.byType(ActivitySearchRow));
    expect(Directionality.of(ctx), TextDirection.rtl);

    final DabblerSearchField field = tester.widget(
      find.byType(DabblerSearchField),
    );
    expect(field.placeholder, ar.activity_search_hint);
    expect(field.placeholder, 'ابحث في النشاط…');

    // RTL: the clear button sits at the inline end — the LEFT — of the field.
    final Rect fieldRect = tester.getRect(find.byType(DabblerSearchField));
    final Offset clear = tester.getCenter(_clearButton);
    expect(clear.dx, lessThan(fieldRect.center.dx));
  });

  testWidgets('TC5 parent clearing query empties the field', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_host(query: 'abc'));
    expect(_fieldText(tester), 'abc');

    await tester.pumpWidget(_host(query: ''));
    await tester.pump();

    expect(_fieldText(tester), isEmpty);
  });

  testWidgets(
    'TC6 const ActivitySearchRow() with no callbacks does not throw',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: DabblerDesignSystemTheme.withTokens(ThemeData()),
          home: const Scaffold(body: ActivitySearchRow()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(DabblerSearchField), findsOneWidget);
      expect(_fieldText(tester), isEmpty);

      await tester.enterText(find.byType(EditableText), 'game');
      await tester.pump();
      expect(tester.takeException(), isNull);

      await tester.tap(_clearButton);
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(_fieldText(tester), isEmpty);
    },
  );
}
