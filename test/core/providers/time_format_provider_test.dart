import 'package:dabbler/core/providers/time_format_provider.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('applyHourFormat: system keeps the device flag, 12/24 force it', () {
    const on = MediaQueryData(alwaysUse24HourFormat: true);
    const off = MediaQueryData();
    expect(applyHourFormat(on, HourFormat.system).alwaysUse24HourFormat, true);
    expect(
      applyHourFormat(off, HourFormat.system).alwaysUse24HourFormat,
      false,
    );
    expect(applyHourFormat(on, HourFormat.h12).alwaysUse24HourFormat, false);
    expect(applyHourFormat(off, HourFormat.h24).alwaysUse24HourFormat, true);
  });

  test('the choice is stored and read back', () async {
    SharedPreferences.setMockInitialValues({});
    final c = ProviderContainer();
    addTearDown(c.dispose);
    expect(c.read(hourFormatProvider), HourFormat.system);
    await c.read(hourFormatProvider.notifier).set(HourFormat.h24);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('hour_format'), 'h24');

    final c2 = ProviderContainer();
    addTearDown(c2.dispose);
    c2.read(hourFormatProvider);
    await Future<void>.delayed(Duration.zero);
    expect(c2.read(hourFormatProvider), HourFormat.h24);
  });
}
