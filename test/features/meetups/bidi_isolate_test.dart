import 'package:dabbler/core/utils/bidi_isolate.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const fsi = '\u2068';
  const pdi = '\u2069';

  test('wraps in a first-strong isolate in RTL', () {
    expect(
      bidiIsolate('Sunrise Run', TextDirection.rtl),
      '${fsi}Sunrise Run$pdi',
    );
  });

  test('is a byte-for-byte no-op in LTR', () {
    expect(bidiIsolate('Sunrise Run', TextDirection.ltr), 'Sunrise Run');
  });

  test('is idempotent', () {
    final once = bidiIsolate('Sunrise Run', TextDirection.rtl);
    expect(bidiIsolate(once, TextDirection.rtl), once);
  });

  test('null and empty become empty', () {
    for (final d in TextDirection.values) {
      expect(bidiIsolate(null, d), '');
      expect(bidiIsolate('', d), '');
    }
  });

  testWidgets('context.isolate follows the ambient Directionality', (t) async {
    late String rtl;
    late String ltr;
    await t.pumpWidget(
      Directionality(
        textDirection: TextDirection.rtl,
        child: Builder(
          builder: (c) {
            rtl = c.isolate('A');
            return Directionality(
              textDirection: TextDirection.ltr,
              child: Builder(
                builder: (c2) {
                  ltr = c2.isolate('A');
                  return const SizedBox();
                },
              ),
            );
          },
        ),
      ),
    );
    expect(rtl, '${fsi}A$pdi');
    expect(ltr, 'A');
  });
}
